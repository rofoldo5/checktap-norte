import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../models/sync_operation.dart';
import '../../models/task_item.dart';
import '../../services/sync_service.dart';
import '../../services/task_service.dart';
import '../local/offline_cache_service.dart';
import '../local/sync_queue_store.dart';

class DashboardData {
  const DashboardData({
    required this.tasks,
    required this.users,
    required this.lastSyncAt,
    required this.pendingOperations,
  });

  final List<TaskItem> tasks;
  final List<AppUser> users;
  final DateTime? lastSyncAt;
  final int pendingOperations;

  bool get hasContent {
    return tasks.isNotEmpty || users.isNotEmpty || lastSyncAt != null;
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

  Future<DashboardData> loadCached({String? status}) async {
    final cached = await _cache.readDashboard(status: status);
    return _dashboardFromCache(cached);
  }

  Future<DashboardData> refreshFromServer({String? status}) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _remote.listTasks(),
      _remote.listUsers(),
    ]);

    final allTasks = results[0] as List<TaskItem>;
    final users = results[1] as List<AppUser>;
    final syncedAt = DateTime.now().toUtc();

    await _cache.replaceServerTasksPreservingLocal(allTasks);
    await _cache.replaceUsers(users);
    await _cache.writeLastSyncAt(syncedAt);

    return loadCached(status: status);
  }

  Future<SyncSummary> synchronizePending() async {
    return _sync.synchronize();
  }

  Future<TaskItem> createTask({
    required AppUser currentUser,
    required String title,
    required String description,
    required String priority,
    AppUser? assignedTo,
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
      createdBy: currentUser,
      assignedTo: assignedTo,
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
    AppUser? assignedTo,
  }) async {
    final updated = task.copyWith(
      title: _validateTitle(title),
      description: _normalizeDescription(description),
      priority: priority,
      assignedTo: assignedTo,
      updatedAt: DateTime.now().toUtc(),
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    final payload = _taskEditPayload(updated);
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

  Future<List<AppUser>> listManagedUsers() => _remote.listManagedUsers();

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
  }) {
    return _remote.createUser(
      name: name,
      email: email,
      password: password,
      isAdmin: isAdmin,
    );
  }

  Future<AppUser> updateUser(
    AppUser user, {
    String? name,
    String? password,
    bool? isAdmin,
    bool? isActive,
  }) {
    return _remote.updateUser(
      user,
      name: name,
      password: password,
      isAdmin: isAdmin,
      isActive: isActive,
    );
  }

  Future<Uint8List> downloadDailyReport(DateTime date) {
    return _remote.downloadDailyReport(date);
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

  Map<String, dynamic> _taskEditPayload(TaskItem task) {
    return <String, dynamic>{
      'title': task.title,
      'description': task.description,
      'priority': task.priority,
      'assigned_to_id': task.assignedTo?.id,
    };
  }

  DashboardData _dashboardFromCache(CachedDashboardData cached) {
    return DashboardData(
      tasks: cached.tasks,
      users: cached.users,
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
      'pending=${data.pendingOperations}',
    );
  }
}
