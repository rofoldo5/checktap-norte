import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../models/department.dart';
import '../../models/sync_operation.dart';
import '../../models/task_checklist.dart';
import '../../models/task_item.dart';
import '../../models/task_recurrence.dart';
import '../../services/sync_service.dart';
import '../../services/task_service.dart';
import '../local/offline_cache_service.dart';
import '../local/sync_queue_store.dart';

class DashboardData {
  const DashboardData({
    required this.tasks,
    required this.users,
    required this.departments,
    required this.lastSyncAt,
    required this.pendingOperations,
  });

  final List<TaskItem> tasks;
  final List<AppUser> users;
  final List<DepartmentSummary> departments;
  final DateTime? lastSyncAt;
  final int pendingOperations;

  bool get hasContent {
    return tasks.isNotEmpty ||
        users.isNotEmpty ||
        departments.isNotEmpty ||
        lastSyncAt != null;
  }
}

class TaskRepository {
  TaskRepository(
    ApiClient apiClient, {
    OfflineCacheService? cacheService,
    SyncQueueStore? queueStore,
  }) : _remote = TaskService(apiClient),
       _cache = cacheService ?? OfflineCacheService(),
       _queue = queueStore ?? SyncQueueStore() {
    _sync = SyncService(_remote, cache: _cache, queue: _queue);
  }

  static final Uuid _uuid = Uuid();

  final TaskService _remote;
  final OfflineCacheService _cache;
  final SyncQueueStore _queue;
  late final SyncService _sync;

  Future<DashboardData> loadCached({
    String? status,
    String? departmentId,
  }) async {
    final cached = await _cache.readDashboard(
      status: status,
      departmentId: departmentId,
    );
    return _dashboardFromCache(cached);
  }

  Future<DashboardData> refreshFromServer({
    String? status,
    String? departmentId,
  }) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _remote.listTasks(),
      _remote.listUsers(),
      _remote.listDepartments(),
    ]);

    final allTasks = results[0] as List<TaskItem>;
    final users = results[1] as List<AppUser>;
    final departments = results[2] as List<DepartmentSummary>;
    final syncedAt = DateTime.now().toUtc();

    await _cache.replaceServerTasksPreservingLocal(allTasks);
    await _cache.replaceUsers(users);
    await _cache.replaceDepartments(departments);
    await _cache.writeLastSyncAt(syncedAt);

    return loadCached(status: status, departmentId: departmentId);
  }

  Future<SyncSummary> synchronizePending() async {
    return _sync.synchronize();
  }

  Future<TaskItem> createTask({
    required AppUser currentUser,
    required String title,
    required String description,
    required String priority,
    required DepartmentSummary department,
    List<AppUser> assignees = const <AppUser>[],
    TaskRecurrence recurrence = TaskRecurrence.none,
  }) async {
    final normalizedTitle = _validateTitle(title);
    final normalizedDescription = _normalizeDescription(description);
    final now = DateTime.now().toUtc();
    final task = TaskItem(
      id: _uuid.v4(),
      title: normalizedTitle,
      description: normalizedDescription,
      status: 'PENDIENTE',
      priority: priority,
      version: 0,
      department: department,
      createdBy: currentUser,
      assignees: assignees,
      assignedTo: assignees.isEmpty ? null : assignees.first,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
      syncState: LocalSyncState.pending,
    );

    await _cache.upsertTask(task);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: task.id,
        operationType: 'CREATE_TASK',
        baseVersion: 0,
        payload: _taskEditPayload(task),
        createdAt: now,
      ),
    );
    return task;
  }

  Future<TaskItem> updateTask({
    required TaskItem task,
    required String title,
    required String description,
    required String priority,
    DepartmentSummary? department,
    List<AppUser>? assignees,
    TaskRecurrence? recurrence,
  }) async {
    final selectedAssignees = assignees ?? task.assignees;
    final recurrenceEditable = task.recurrence.canEditSchedule;
    final selectedRecurrence = recurrenceEditable
        ? (recurrence ?? task.recurrence)
        : task.recurrence;
    final selectedDepartment = department ?? task.department;
    final updated = task.copyWith(
      title: _validateTitle(title),
      description: _normalizeDescription(description),
      priority: priority,
      department: selectedDepartment,
      assignees: selectedAssignees,
      assignedTo: selectedAssignees.isEmpty ? null : selectedAssignees.first,
      recurrence: selectedRecurrence,
      updatedAt: DateTime.now().toUtc(),
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    final payload = _taskEditPayload(
      updated,
      includeRecurrence: recurrenceEditable,
    );
    await _cache.upsertTask(updated);

    if (task.version == 0) {
      final merged = await _queue.updatePendingCreatePayload(task.id, payload);
      if (!merged) {
        await _queue.enqueue(
          SyncOperation(
            operationId: _uuid.v4(),
            entityId: task.id,
            operationType: 'UPDATE_TASK',
            baseVersion: task.version,
            payload: payload,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
      return updated;
    }

    final merged = await _queue.updatePendingTaskEdit(task.id, payload);
    if (!merged) {
      await _queue.enqueue(
        SyncOperation(
          operationId: _uuid.v4(),
          entityId: task.id,
          operationType: 'UPDATE_TASK',
          baseVersion: task.version,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return updated;
  }

  Future<TaskItem> startTask(TaskItem task) async {
    final updated = task.copyWith(
      status: 'EN_PROGRESO',
      completedBy: null,
      completedAt: null,
      updatedAt: DateTime.now().toUtc(),
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistMutation(updated, 'START_TASK', task.version);
    return updated;
  }

  Future<TaskItem> completeTask(TaskItem task, AppUser currentUser) async {
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: 'COMPLETADA',
      completedBy: currentUser,
      completedAt: now,
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistMutation(updated, 'COMPLETE_TASK', task.version);
    return updated;
  }

  Future<TaskItem> reopenTask(TaskItem task) async {
    final updated = task.copyWith(
      status: 'PENDIENTE',
      completedBy: null,
      completedAt: null,
      updatedAt: DateTime.now().toUtc(),
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistMutation(updated, 'REOPEN_TASK', task.version);
    return updated;
  }

  Future<TaskItem> createChecklist({
    required TaskItem task,
    required AppUser currentUser,
    required String title,
    List<String> initialItemTitles = const <String>[],
  }) async {
    _ensureChecklistEditable(task);
    final normalizedTitle = _validateChecklistText(
      title,
      maxLength: 180,
      label: 'nombre del checklist',
    );
    final now = DateTime.now().toUtc();
    final checklistId = _uuid.v4();
    final normalizedItems = initialItemTitles
        .map(
          (value) =>
              _validateChecklistText(value, maxLength: 300, label: 'actividad'),
        )
        .toList(growable: false);
    final items = <TaskChecklistItem>[
      for (var index = 0; index < normalizedItems.length; index += 1)
        TaskChecklistItem(
          id: _uuid.v4(),
          title: normalizedItems[index],
          position: index,
          isCompleted: false,
          version: 0,
          createdBy: currentUser,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    final nextPosition = task.checklists.isEmpty
        ? 0
        : task.checklists
                  .map((checklist) => checklist.position)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final checklist = TaskChecklist(
      id: checklistId,
      title: normalizedTitle,
      position: nextPosition,
      version: 0,
      createdBy: currentUser,
      createdAt: now,
      updatedAt: now,
      items: items,
    );
    final updated = task.copyWith(
      checklists: <TaskChecklist>[...task.checklists, checklist],
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistChecklistMutation(
      updated,
      'CREATE_CHECKLIST',
      <String, dynamic>{
        'id': checklist.id,
        'title': checklist.title,
        'position': checklist.position,
        'items': checklist.items
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'title': item.title,
                'position': item.position,
              },
            )
            .toList(growable: false),
      },
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> updateChecklistTitle({
    required TaskItem task,
    required String checklistId,
    required String title,
  }) async {
    _ensureChecklistEditable(task);
    final normalized = _validateChecklistText(
      title,
      maxLength: 180,
      label: 'nombre del checklist',
    );
    final now = DateTime.now().toUtc();
    final checklists = task.checklists
        .map(
          (checklist) => checklist.id == checklistId
              ? checklist.copyWith(title: normalized, updatedAt: now)
              : checklist,
        )
        .toList(growable: false);
    final updated = task.copyWith(
      checklists: checklists,
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistChecklistMutation(
      updated,
      'UPDATE_CHECKLIST',
      <String, dynamic>{'checklist_id': checklistId, 'title': normalized},
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> deleteChecklist({
    required TaskItem task,
    required String checklistId,
  }) async {
    _ensureChecklistEditable(task);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      checklists: task.checklists
          .where((checklist) => checklist.id != checklistId)
          .toList(growable: false),
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _persistChecklistMutation(
      updated,
      'DELETE_CHECKLIST',
      <String, dynamic>{'checklist_id': checklistId},
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> addChecklistItem({
    required TaskItem task,
    required String checklistId,
    required AppUser currentUser,
    required String title,
  }) async {
    _ensureChecklistEditable(task);
    final normalized = _validateChecklistText(
      title,
      maxLength: 300,
      label: 'actividad',
    );
    final now = DateTime.now().toUtc();
    final itemId = _uuid.v4();
    TaskChecklist? target;
    for (final checklist in task.checklists) {
      if (checklist.id == checklistId) {
        target = checklist;
        break;
      }
    }
    if (target == null) {
      throw const FormatException('El checklist no existe.');
    }
    final position = target.items.isEmpty
        ? 0
        : target.items
                  .map((item) => item.position)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final item = TaskChecklistItem(
      id: itemId,
      title: normalized,
      position: position,
      isCompleted: false,
      version: 0,
      createdBy: currentUser,
      createdAt: now,
      updatedAt: now,
    );
    final updated = _replaceChecklist(
      task,
      target.copyWith(
        items: <TaskChecklistItem>[...target.items, item],
        updatedAt: now,
      ),
      now,
    );
    await _persistChecklistMutation(
      updated,
      'CREATE_CHECKLIST_ITEM',
      <String, dynamic>{
        'checklist_id': checklistId,
        'id': itemId,
        'title': normalized,
        'position': position,
      },
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> updateChecklistItemTitle({
    required TaskItem task,
    required String checklistId,
    required String itemId,
    required String title,
  }) async {
    _ensureChecklistEditable(task);
    final normalized = _validateChecklistText(
      title,
      maxLength: 300,
      label: 'actividad',
    );
    final now = DateTime.now().toUtc();
    final target = _checklistById(task, checklistId);
    final items = target.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(title: normalized, updatedAt: now)
              : item,
        )
        .toList(growable: false);
    final updated = _replaceChecklist(
      task,
      target.copyWith(items: items, updatedAt: now),
      now,
    );
    await _persistChecklistMutation(
      updated,
      'UPDATE_CHECKLIST_ITEM',
      <String, dynamic>{
        'checklist_id': checklistId,
        'item_id': itemId,
        'title': normalized,
      },
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> deleteChecklistItem({
    required TaskItem task,
    required String checklistId,
    required String itemId,
  }) async {
    _ensureChecklistEditable(task);
    final now = DateTime.now().toUtc();
    final target = _checklistById(task, checklistId);
    final updated = _replaceChecklist(
      task,
      target.copyWith(
        items: target.items
            .where((item) => item.id != itemId)
            .toList(growable: false),
        updatedAt: now,
      ),
      now,
    );
    await _persistChecklistMutation(
      updated,
      'DELETE_CHECKLIST_ITEM',
      <String, dynamic>{'checklist_id': checklistId, 'item_id': itemId},
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> setChecklistItemCompleted({
    required TaskItem task,
    required String checklistId,
    required String itemId,
    required AppUser currentUser,
    required bool isCompleted,
  }) async {
    _ensureChecklistEditable(task);
    final now = DateTime.now().toUtc();
    final target = _checklistById(task, checklistId);
    final items = target.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(
                  isCompleted: isCompleted,
                  completedBy: isCompleted ? currentUser : null,
                  completedAt: isCompleted ? now : null,
                  updatedAt: now,
                )
              : item,
        )
        .toList(growable: false);
    final updated = _replaceChecklist(
      task,
      target.copyWith(items: items, updatedAt: now),
      now,
    );
    await _persistChecklistMutation(
      updated,
      'SET_CHECKLIST_ITEM_STATE',
      <String, dynamic>{
        'checklist_id': checklistId,
        'item_id': itemId,
        'is_completed': isCompleted,
      },
      baseVersion: task.version,
    );
    return updated;
  }

  Future<TaskItem> setChecklistCompleted({
    required TaskItem task,
    required String checklistId,
    required AppUser currentUser,
    required bool isCompleted,
  }) async {
    _ensureChecklistEditable(task);
    final now = DateTime.now().toUtc();
    final target = _checklistById(task, checklistId);
    if (target.items.isEmpty) {
      throw const FormatException(
        'Agregue actividades antes de completar el checklist.',
      );
    }
    final items = target.items
        .map(
          (item) => item.copyWith(
            isCompleted: isCompleted,
            completedBy: isCompleted ? currentUser : null,
            completedAt: isCompleted ? now : null,
            updatedAt: now,
          ),
        )
        .toList(growable: false);
    final updated = _replaceChecklist(
      task,
      target.copyWith(items: items, updatedAt: now),
      now,
    );
    await _persistChecklistMutation(
      updated,
      'SET_CHECKLIST_STATE',
      <String, dynamic>{
        'checklist_id': checklistId,
        'is_completed': isCompleted,
      },
      baseVersion: task.version,
    );
    return updated;
  }

  Future<List<DepartmentSummary>> listDepartments() {
    return _remote.listDepartments();
  }

  Future<DepartmentDetail> getDepartment(String departmentId) {
    return _remote.getDepartment(departmentId);
  }

  Future<DepartmentDetail> createDepartment({required String name}) {
    return _remote.createDepartment(name: name);
  }

  Future<DepartmentDetail> updateDepartment(
    DepartmentSummary department, {
    String? name,
    bool? isActive,
  }) {
    return _remote.updateDepartment(department, name: name, isActive: isActive);
  }

  Future<DepartmentDetail> replaceDepartmentMembers(
    String departmentId,
    List<String> userIds,
  ) {
    return _remote.replaceDepartmentMembers(departmentId, userIds);
  }

  Future<List<AppUser>> listManagedUsers() => _remote.listManagedUsers();

  Future<List<AppUser>> listAccessRequests() => _remote.listAccessRequests();

  Future<int> accessRequestCount() => _remote.accessRequestCount();

  Future<AppUser> approveAccessRequest(
    AppUser user, {
    required List<String> departmentIds,
    bool isAdmin = false,
  }) {
    return _remote.approveAccessRequest(
      user,
      departmentIds: departmentIds,
      isAdmin: isAdmin,
    );
  }

  Future<AppUser> rejectAccessRequest(AppUser user, {String? reason}) {
    return _remote.rejectAccessRequest(user, reason: reason);
  }

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
    required List<String> departmentIds,
  }) {
    return _remote.createUser(
      name: name,
      email: email,
      password: password,
      isAdmin: isAdmin,
      departmentIds: departmentIds,
    );
  }

  Future<AppUser> updateUser(
    AppUser user, {
    String? name,
    String? password,
    bool? isAdmin,
    bool? isActive,
    List<String>? departmentIds,
  }) {
    return _remote.updateUser(
      user,
      name: name,
      password: password,
      isAdmin: isAdmin,
      isActive: isActive,
      departmentIds: departmentIds,
    );
  }

  Future<Uint8List> downloadDailyReport(DateTime date, {String? departmentId}) {
    return _remote.downloadDailyReport(date, departmentId: departmentId);
  }

  Future<List<DailyReportItem>> listGeneratedReports({String? departmentId}) {
    return _remote.listGeneratedReports(departmentId: departmentId);
  }

  Future<DailyReportItem> generateDailyReport({
    DateTime? date,
    String? departmentId,
  }) {
    return _remote.generateDailyReport(date: date, departmentId: departmentId);
  }

  Future<Uint8List> downloadGeneratedReport(String reportId) {
    return _remote.downloadGeneratedReport(reportId);
  }

  Future<void> resolveConflict(String taskId) async {
    await _cache.resolveConflict(taskId);
  }

  Future<int> pendingCount() => _queue.countPending();

  Future<void> _persistMutation(
    TaskItem task,
    String operationType,
    int baseVersion,
  ) async {
    await _cache.upsertTask(task);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: task.id,
        operationType: operationType,
        baseVersion: baseVersion,
        payload: const <String, dynamic>{},
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _persistChecklistMutation(
    TaskItem task,
    String operationType,
    Map<String, dynamic> payload, {
    required int baseVersion,
  }) async {
    await _cache.upsertTask(task);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: task.id,
        operationType: operationType,
        baseVersion: baseVersion,
        payload: payload,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _ensureChecklistEditable(TaskItem task) {
    if (task.status == 'COMPLETADA') {
      throw const FormatException(
        'Reabra la tarea antes de modificar sus checklists.',
      );
    }
  }

  TaskChecklist _checklistById(TaskItem task, String checklistId) {
    for (final checklist in task.checklists) {
      if (checklist.id == checklistId) {
        return checklist;
      }
    }
    throw const FormatException('El checklist no existe.');
  }

  TaskItem _replaceChecklist(
    TaskItem task,
    TaskChecklist replacement,
    DateTime updatedAt,
  ) {
    return task.copyWith(
      checklists: task.checklists
          .map(
            (checklist) =>
                checklist.id == replacement.id ? replacement : checklist,
          )
          .toList(growable: false),
      updatedAt: updatedAt,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
  }

  String _validateChecklistText(
    String value, {
    required int maxLength,
    required String label,
  }) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      throw FormatException('Ingrese un $label válido.');
    }
    if (normalized.length > maxLength) {
      throw FormatException(
        'El $label no puede superar $maxLength caracteres.',
      );
    }
    return normalized;
  }

  String _validateTitle(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      throw const FormatException('Ingrese un titulo valido.');
    }
    if (normalized.length > 150) {
      throw const FormatException('El titulo no puede superar 150 caracteres.');
    }
    return normalized;
  }

  String? _normalizeDescription(String value) {
    final normalized = value.trim();
    if (normalized.length > 3000) {
      throw const FormatException(
        'La descripcion no puede superar 3000 caracteres.',
      );
    }
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, dynamic> _taskEditPayload(
    TaskItem task, {
    bool includeRecurrence = true,
  }) {
    final departmentId = task.department.id == DepartmentSummary.unknown.id
        ? null
        : task.department.id;
    return <String, dynamic>{
      'title': task.title,
      'description': task.description,
      'priority': task.priority,
      'department_id': departmentId,
      'assignee_ids': task.assignees.map((user) => user.id).toList(),
      'assigned_to_id': task.assignedTo?.id,
      if (includeRecurrence) ...task.recurrence.toApiJson(),
    };
  }

  DashboardData _dashboardFromCache(CachedDashboardData cached) {
    return DashboardData(
      tasks: cached.tasks,
      users: cached.users,
      departments: cached.departments,
      lastSyncAt: cached.lastSyncAt,
      pendingOperations: cached.pendingOperations,
    );
  }

  Future<void> debugDumpState() async {
    if (!kDebugMode) {
      return;
    }
    final data = await loadCached();
    debugPrint(
      '[OFFLINE] tasks=${data.tasks.length} users=${data.users.length} '
      'departments=${data.departments.length} '
      'pending=${data.pendingOperations}',
    );
  }
}
