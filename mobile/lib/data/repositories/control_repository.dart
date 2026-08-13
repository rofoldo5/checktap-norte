import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../models/control_item.dart';
import '../../models/department.dart';
import '../../models/sync_operation.dart';
import '../../models/task_item.dart';
import '../../services/control_service.dart';
import '../../services/sync_service.dart';
import '../../services/task_service.dart';
import '../local/control_cache_service.dart';
import '../local/offline_cache_service.dart';
import '../local/sync_queue_store.dart';

class ControlRepository {
  ControlRepository(
    ApiClient apiClient, {
    ControlCacheService? cache,
    SyncQueueStore? queue,
  })  : _remote = ControlService(apiClient),
        _cache = cache ?? ControlCacheService(),
        _queue = queue ?? SyncQueueStore() {
    _sync = SyncService(
      TaskService(apiClient),
      cache: OfflineCacheService(),
      controlCache: _cache,
      queue: _queue,
    );
  }

  static const Uuid _uuid = Uuid();

  final ControlService _remote;
  final ControlCacheService _cache;
  final SyncQueueStore _queue;
  late final SyncService _sync;

  Future<ControlCacheSnapshot> loadCached({String? departmentId}) {
    return _cache.readSnapshot(departmentId: departmentId);
  }

  Future<ControlCacheSnapshot> refreshFromServer({String? departmentId}) async {
    final remote = await _remote.snapshot();
    await _cache.replaceServerSnapshotPreservingLocal(
      remote.sections,
      remote.checks,
    );
    return _cache.readSnapshot(departmentId: departmentId);
  }

  Future<SyncSummary> synchronizePending() => _sync.synchronize();

  Future<ControlCheckItem?> readCachedCheck(String id) => _cache.readCheck(id);

  Future<ControlCheckItem> refreshCheck(String id) async {
    final check = await _remote.getCheck(id);
    await _cache.upsertCheck(check);
    return check;
  }

  Future<ControlSectionItem> createSection({
    required AppUser currentUser,
    required String name,
    required String description,
    required String iconKey,
    required DepartmentSummary department,
  }) async {
    final normalizedName = _required(name, 'nombre de la sección', 120);
    final now = DateTime.now().toUtc();
    final section = ControlSectionItem(
      id: _uuid.v4(),
      name: normalizedName,
      description: _optional(description),
      iconKey: iconKey.trim().isEmpty ? 'folder' : iconKey.trim(),
      department: department,
      createdBy: currentUser,
      version: 0,
      createdAt: now,
      updatedAt: now,
      syncState: LocalSyncState.pending,
    );
    await _cache.upsertSection(section);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: section.id,
        operationType: 'CREATE_CONTROL_SECTION',
        baseVersion: 0,
        payload: <String, dynamic>{
          'name': section.name,
          'description': section.description,
          'icon_key': section.iconKey,
          'department_id': department.id,
        },
        createdAt: now,
      ),
    );
    return section;
  }

  Future<ControlSectionItem> updateSection({
    required ControlSectionItem section,
    required String name,
    required String description,
    required String iconKey,
    required DepartmentSummary department,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = section.copyWith(
      name: _required(name, 'nombre de la sección', 120),
      description: _optional(description),
      iconKey: iconKey.trim().isEmpty ? 'folder' : iconKey.trim(),
      department: department,
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _cache.upsertSection(updated);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: section.id,
        operationType: 'UPDATE_CONTROL_SECTION',
        baseVersion: section.version,
        payload: <String, dynamic>{
          'name': updated.name,
          'description': updated.description,
          'icon_key': updated.iconKey,
          'department_id': department.id,
        },
        createdAt: now,
      ),
    );
    return updated;
  }

  Future<void> archiveSection(ControlSectionItem section) async {
    await _cache.upsertSection(
      section.copyWith(
        isActive: false,
        updatedAt: DateTime.now().toUtc(),
        syncState: LocalSyncState.pending,
      ),
    );
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: section.id,
        operationType: 'ARCHIVE_CONTROL_SECTION',
        baseVersion: section.version,
        payload: const <String, dynamic>{},
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<ControlCheckItem> createCheck({
    required AppUser currentUser,
    required ControlSectionItem section,
    required String title,
    required String description,
    required String reference,
    required String contact,
    required String notes,
    required String priority,
    required DateTime dueAt,
    required String timezone,
    required List<int> reminderMinutes,
    required String recurrenceType,
    required int recurrenceInterval,
    required String? recurrenceUnit,
    required List<AppUser> assignees,
  }) async {
    final now = DateTime.now().toUtc();
    final check = ControlCheckItem(
      id: _uuid.v4(),
      sectionId: section.id,
      sectionName: section.name,
      title: _required(title, 'nombre del control', 180),
      description: _optional(description),
      reference: _optional(reference),
      contact: _optional(contact),
      notes: _optional(notes),
      priority: priority,
      dueAt: dueAt.toUtc(),
      timezone: timezone,
      reminderMinutes: _normalizedReminders(reminderMinutes),
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceType == 'CUSTOM' ? recurrenceInterval : 1,
      recurrenceUnit: recurrenceType == 'CUSTOM' ? recurrenceUnit : null,
      version: 0,
      createdBy: currentUser,
      assignees: assignees,
      createdAt: now,
      updatedAt: now,
      syncState: LocalSyncState.pending,
    );
    await _cache.upsertCheck(check);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: check.id,
        operationType: 'CREATE_CONTROL_CHECK',
        baseVersion: 0,
        payload: _checkPayload(check),
        createdAt: now,
      ),
    );
    return check;
  }

  Future<ControlCheckItem> updateCheck({
    required ControlCheckItem check,
    required String title,
    required String description,
    required String reference,
    required String contact,
    required String notes,
    required String priority,
    required DateTime dueAt,
    required String timezone,
    required List<int> reminderMinutes,
    required String recurrenceType,
    required int recurrenceInterval,
    required String? recurrenceUnit,
    required List<AppUser> assignees,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = check.copyWith(
      title: _required(title, 'nombre del control', 180),
      description: _optional(description),
      reference: _optional(reference),
      contact: _optional(contact),
      notes: _optional(notes),
      priority: priority,
      dueAt: dueAt.toUtc(),
      timezone: timezone,
      reminderMinutes: _normalizedReminders(reminderMinutes),
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceType == 'CUSTOM' ? recurrenceInterval : 1,
      recurrenceUnit: recurrenceType == 'CUSTOM' ? recurrenceUnit : null,
      assignees: assignees,
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _cache.upsertCheck(updated);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: check.id,
        operationType: 'UPDATE_CONTROL_CHECK',
        baseVersion: check.version,
        payload: _checkPayload(updated, includeSection: false),
        createdAt: now,
      ),
    );
    return updated;
  }

  Future<ControlCheckItem> completeCheck(
    ControlCheckItem check,
    AppUser currentUser, {
    String? completionNotes,
  }) async {
    if (check.isCompleted) {
      throw const FormatException('El control ya está completado.');
    }
    final now = DateTime.now().toUtc();
    final nextDue = _nextDue(check);
    final history = <ControlCheckHistoryItem>[
      ControlCheckHistoryItem(
        id: _uuid.v4(),
        dueAt: check.dueAt,
        completedAt: now,
        nextDueAt: nextDue,
        completionNotes: _optional(completionNotes ?? ''),
        completedBy: currentUser,
      ),
      ...check.history,
    ];
    final updated = check.copyWith(
      status: nextDue == null ? 'COMPLETADA' : 'PENDIENTE',
      dueAt: nextDue ?? check.dueAt,
      completedBy: currentUser,
      completedAt: now,
      history: history,
      updatedAt: now,
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _cache.upsertCheck(updated);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: check.id,
        operationType: 'COMPLETE_CONTROL_CHECK',
        baseVersion: check.version,
        payload: <String, dynamic>{'notes': _optional(completionNotes ?? '')},
        createdAt: now,
      ),
    );
    return updated;
  }

  Future<ControlCheckItem> reopenCheck(ControlCheckItem check) async {
    if (check.isRecurring) {
      throw const FormatException(
        'Los controles recurrentes se reprograman al completarse.',
      );
    }
    final updated = check.copyWith(
      status: 'PENDIENTE',
      completedBy: null,
      completedAt: null,
      updatedAt: DateTime.now().toUtc(),
      syncState: LocalSyncState.pending,
      syncError: null,
    );
    await _cache.upsertCheck(updated);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: check.id,
        operationType: 'REOPEN_CONTROL_CHECK',
        baseVersion: check.version,
        payload: const <String, dynamic>{},
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return updated;
  }

  Future<void> deleteCheck(ControlCheckItem check) async {
    await _cache.deleteCheck(check.id);
    await _queue.enqueue(
      SyncOperation(
        operationId: _uuid.v4(),
        entityId: check.id,
        operationType: 'DELETE_CONTROL_CHECK',
        baseVersion: check.version,
        payload: const <String, dynamic>{},
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Map<String, dynamic> _checkPayload(
    ControlCheckItem check, {
    bool includeSection = true,
  }) {
    return <String, dynamic>{
      if (includeSection) 'section_id': check.sectionId,
      'title': check.title,
      'description': check.description,
      'reference': check.reference,
      'contact': check.contact,
      'notes': check.notes,
      'priority': check.priority,
      'due_at': check.dueAt.toUtc().toIso8601String(),
      'timezone': check.timezone,
      'reminder_minutes': check.reminderMinutes,
      'recurrence_type': check.recurrenceType,
      'recurrence_interval': check.recurrenceInterval,
      'recurrence_unit': check.recurrenceUnit,
      'assignee_ids': check.assignees.map((item) => item.id).toList(growable: false),
    };
  }

  List<int> _normalizedReminders(List<int> values) {
    final result = values.where((value) => value >= 0).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return result;
  }

  String _required(String value, String label, int maxLength) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      throw FormatException('Ingrese un $label válido.');
    }
    if (normalized.length > maxLength) {
      throw FormatException('El $label es demasiado largo.');
    }
    return normalized;
  }

  String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  DateTime? _nextDue(ControlCheckItem check) {
    if (!check.isRecurring) {
      return null;
    }
    final due = check.dueAt.toUtc();
    var anchorDay = due.day;
    var anchorMonth = due.month;
    for (final entry in check.history) {
      if (entry.dueAt.day > anchorDay) {
        anchorDay = entry.dueAt.day;
      }
      anchorMonth = entry.dueAt.month;
    }

    DateTime addDays(int days) => due.add(Duration(days: days));

    DateTime addMonths(int months) {
      final total = due.year * 12 + due.month - 1 + months;
      final year = total ~/ 12;
      final month = total % 12 + 1;
      final day = anchorDay.clamp(1, _daysInMonth(year, month));
      return DateTime.utc(
        year,
        month,
        day,
        due.hour,
        due.minute,
        due.second,
      );
    }

    DateTime addYears(int years) {
      final year = due.year + years;
      final day = anchorDay.clamp(1, _daysInMonth(year, anchorMonth));
      return DateTime.utc(
        year,
        anchorMonth,
        day,
        due.hour,
        due.minute,
        due.second,
      );
    }

    switch (check.recurrenceType) {
      case 'DAILY':
        return addDays(1);
      case 'WEEKLY':
        return addDays(7);
      case 'MONTHLY':
        return addMonths(1);
      case 'YEARLY':
        return addYears(1);
      case 'CUSTOM':
        switch (check.recurrenceUnit) {
          case 'WEEKS':
            return addDays(7 * check.recurrenceInterval);
          case 'MONTHS':
            return addMonths(check.recurrenceInterval);
          case 'YEARS':
            return addYears(check.recurrenceInterval);
          default:
            return addDays(check.recurrenceInterval);
        }
      default:
        return null;
    }
  }

  int _daysInMonth(int year, int month) {
    final nextMonth = month == 12
        ? DateTime.utc(year + 1, 1, 1)
        : DateTime.utc(year, month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }
}
