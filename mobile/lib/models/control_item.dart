import 'app_user.dart';
import 'department.dart';
import 'task_item.dart';

const Object _controlUnset = Object();

class ControlSectionItem {
  const ControlSectionItem({
    required this.id,
    required this.name,
    required this.department,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.iconKey = 'folder',
    this.isActive = true,
    this.version = 1,
    this.checkCount = 0,
    this.upcomingCount = 0,
    this.urgentCount = 0,
    this.overdueCount = 0,
    this.completedCount = 0,
    this.syncState = LocalSyncState.synced,
    this.syncError,
  });

  final String id;
  final String name;
  final String? description;
  final String iconKey;
  final DepartmentSummary department;
  final AppUser createdBy;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int checkCount;
  final int upcomingCount;
  final int urgentCount;
  final int overdueCount;
  final int completedCount;
  final LocalSyncState syncState;
  final String? syncError;

  factory ControlSectionItem.fromJson(
    Map<String, dynamic> json, {
    LocalSyncState syncState = LocalSyncState.synced,
    String? syncError,
  }) {
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc();
    return ControlSectionItem(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Controles',
      description: json['description']?.toString(),
      iconKey: json['icon_key']?.toString() ?? 'folder',
      department: json['department'] == null
          ? DepartmentSummary.unknown
          : DepartmentSummary.fromJson(
              Map<String, dynamic>.from(json['department'] as Map),
            ),
      createdBy: json['created_by'] == null
          ? const AppUser(id: 'local', name: 'Usuario', email: '')
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['created_by'] as Map),
            ),
      isActive: json['is_active'] as bool? ?? true,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          createdAt,
      checkCount: (json['check_count'] as num?)?.toInt() ?? 0,
      upcomingCount: (json['upcoming_count'] as num?)?.toInt() ?? 0,
      urgentCount: (json['urgent_count'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdue_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      syncState: syncState,
      syncError: syncError,
    );
  }

  ControlSectionItem copyWith({
    String? name,
    Object? description = _controlUnset,
    String? iconKey,
    DepartmentSummary? department,
    bool? isActive,
    int? version,
    DateTime? updatedAt,
    int? checkCount,
    int? upcomingCount,
    int? urgentCount,
    int? overdueCount,
    int? completedCount,
    LocalSyncState? syncState,
    Object? syncError = _controlUnset,
  }) {
    return ControlSectionItem(
      id: id,
      name: name ?? this.name,
      description: identical(description, _controlUnset)
          ? this.description
          : description as String?,
      iconKey: iconKey ?? this.iconKey,
      department: department ?? this.department,
      createdBy: createdBy,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkCount: checkCount ?? this.checkCount,
      upcomingCount: upcomingCount ?? this.upcomingCount,
      urgentCount: urgentCount ?? this.urgentCount,
      overdueCount: overdueCount ?? this.overdueCount,
      completedCount: completedCount ?? this.completedCount,
      syncState: syncState ?? this.syncState,
      syncError: identical(syncError, _controlUnset)
          ? this.syncError
          : syncError as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'icon_key': iconKey,
        'department': department.toJson(),
        'created_by': createdBy.toJson(),
        'is_active': isActive,
        'version': version,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'check_count': checkCount,
        'upcoming_count': upcomingCount,
        'urgent_count': urgentCount,
        'overdue_count': overdueCount,
        'completed_count': completedCount,
      };
}

class ControlCheckHistoryItem {
  const ControlCheckHistoryItem({
    required this.id,
    required this.dueAt,
    required this.completedAt,
    this.nextDueAt,
    this.completionNotes,
    this.completedBy,
  });

  final String id;
  final DateTime dueAt;
  final DateTime completedAt;
  final DateTime? nextDueAt;
  final String? completionNotes;
  final AppUser? completedBy;

  factory ControlCheckHistoryItem.fromJson(Map<String, dynamic> json) {
    return ControlCheckHistoryItem(
      id: json['id'].toString(),
      dueAt: DateTime.parse(json['due_at'].toString()),
      completedAt: DateTime.parse(json['completed_at'].toString()),
      nextDueAt: json['next_due_at'] == null
          ? null
          : DateTime.tryParse(json['next_due_at'].toString()),
      completionNotes: json['completion_notes']?.toString(),
      completedBy: json['completed_by'] == null
          ? null
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['completed_by'] as Map),
            ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'due_at': dueAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'next_due_at': nextDueAt?.toUtc().toIso8601String(),
        'completion_notes': completionNotes,
        'completed_by': completedBy?.toJson(),
      };
}

class ControlCheckItem {
  const ControlCheckItem({
    required this.id,
    required this.sectionId,
    required this.sectionName,
    required this.title,
    required this.dueAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.reference,
    this.contact,
    this.notes,
    this.priority = 'MEDIA',
    this.status = 'PENDIENTE',
    this.timezone = 'UTC',
    this.reminderMinutes = const <int>[],
    this.nextReminderAt,
    this.recurrenceType = 'NONE',
    this.recurrenceInterval = 1,
    this.recurrenceUnit,
    this.version = 1,
    this.assignees = const <AppUser>[],
    this.completedBy,
    this.completedAt,
    this.history = const <ControlCheckHistoryItem>[],
    this.syncState = LocalSyncState.synced,
    this.syncError,
  });

  final String id;
  final String sectionId;
  final String sectionName;
  final String title;
  final String? description;
  final String? reference;
  final String? contact;
  final String? notes;
  final String priority;
  final String status;
  final DateTime dueAt;
  final String timezone;
  final List<int> reminderMinutes;
  final DateTime? nextReminderAt;
  final String recurrenceType;
  final int recurrenceInterval;
  final String? recurrenceUnit;
  final int version;
  final AppUser createdBy;
  final List<AppUser> assignees;
  final AppUser? completedBy;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ControlCheckHistoryItem> history;
  final LocalSyncState syncState;
  final String? syncError;

  bool get isRecurring => recurrenceType != 'NONE';
  bool get isCompleted => status == 'COMPLETADA';
  bool get hasPendingChanges => syncState != LocalSyncState.synced;

  String get dueState {
    if (isCompleted) {
      return 'COMPLETADA';
    }
    final now = DateTime.now().toUtc();
    final due = dueAt.toUtc();
    if (due.isBefore(now)) {
      return 'VENCIDA';
    }
    final remaining = due.difference(now);
    if (remaining <= const Duration(days: 7)) {
      return 'URGENTE';
    }
    if (remaining <= const Duration(days: 30)) {
      return 'PROXIMA';
    }
    return 'VIGENTE';
  }

  String get recurrenceLabel {
    switch (recurrenceType) {
      case 'DAILY':
        return 'Diario';
      case 'WEEKLY':
        return 'Semanal';
      case 'MONTHLY':
        return 'Mensual';
      case 'YEARLY':
        return 'Anual';
      case 'CUSTOM':
        return 'Cada $recurrenceInterval ${_unitLabel(recurrenceInterval)}';
      default:
        return 'No se repite';
    }
  }

  String _unitLabel(int value) {
    switch (recurrenceUnit) {
      case 'WEEKS':
        return value == 1 ? 'semana' : 'semanas';
      case 'MONTHS':
        return value == 1 ? 'mes' : 'meses';
      case 'YEARS':
        return value == 1 ? 'año' : 'años';
      default:
        return value == 1 ? 'día' : 'días';
    }
  }

  factory ControlCheckItem.fromJson(
    Map<String, dynamic> json, {
    LocalSyncState syncState = LocalSyncState.synced,
    String? syncError,
  }) {
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc();
    final rawAssignees = json['assignees'] as List<dynamic>? ?? const <dynamic>[];
    final rawHistory = json['history'] as List<dynamic>? ?? const <dynamic>[];
    return ControlCheckItem(
      id: json['id'].toString(),
      sectionId: json['section_id'].toString(),
      sectionName: json['section_name']?.toString() ?? 'Controles',
      title: json['title']?.toString() ?? 'Control',
      description: json['description']?.toString(),
      reference: json['reference']?.toString(),
      contact: json['contact']?.toString(),
      notes: json['notes']?.toString(),
      priority: json['priority']?.toString() ?? 'MEDIA',
      status: json['status']?.toString() ?? 'PENDIENTE',
      dueAt: DateTime.parse(json['due_at'].toString()),
      timezone: json['timezone']?.toString() ?? 'UTC',
      reminderMinutes: (json['reminder_minutes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => (item as num).toInt())
          .toList(growable: false),
      nextReminderAt: json['next_reminder_at'] == null
          ? null
          : DateTime.tryParse(json['next_reminder_at'].toString()),
      recurrenceType: json['recurrence_type']?.toString() ?? 'NONE',
      recurrenceInterval: (json['recurrence_interval'] as num?)?.toInt() ?? 1,
      recurrenceUnit: json['recurrence_unit']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['created_by'] == null
          ? const AppUser(id: 'local', name: 'Usuario', email: '')
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['created_by'] as Map),
            ),
      assignees: rawAssignees
          .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      completedBy: json['completed_by'] == null
          ? null
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['completed_by'] as Map),
            ),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse(json['completed_at'].toString()),
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? createdAt,
      history: rawHistory
          .map(
            (item) => ControlCheckHistoryItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      syncState: syncState,
      syncError: syncError,
    );
  }

  ControlCheckItem copyWith({
    String? title,
    Object? description = _controlUnset,
    Object? reference = _controlUnset,
    Object? contact = _controlUnset,
    Object? notes = _controlUnset,
    String? priority,
    String? status,
    DateTime? dueAt,
    String? timezone,
    List<int>? reminderMinutes,
    Object? nextReminderAt = _controlUnset,
    String? recurrenceType,
    int? recurrenceInterval,
    Object? recurrenceUnit = _controlUnset,
    int? version,
    List<AppUser>? assignees,
    Object? completedBy = _controlUnset,
    Object? completedAt = _controlUnset,
    DateTime? updatedAt,
    List<ControlCheckHistoryItem>? history,
    LocalSyncState? syncState,
    Object? syncError = _controlUnset,
  }) {
    return ControlCheckItem(
      id: id,
      sectionId: sectionId,
      sectionName: sectionName,
      title: title ?? this.title,
      description: identical(description, _controlUnset)
          ? this.description
          : description as String?,
      reference: identical(reference, _controlUnset)
          ? this.reference
          : reference as String?,
      contact: identical(contact, _controlUnset) ? this.contact : contact as String?,
      notes: identical(notes, _controlUnset) ? this.notes : notes as String?,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      timezone: timezone ?? this.timezone,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      nextReminderAt: identical(nextReminderAt, _controlUnset)
          ? this.nextReminderAt
          : nextReminderAt as DateTime?,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceUnit: identical(recurrenceUnit, _controlUnset)
          ? this.recurrenceUnit
          : recurrenceUnit as String?,
      version: version ?? this.version,
      createdBy: createdBy,
      assignees: assignees ?? this.assignees,
      completedBy: identical(completedBy, _controlUnset)
          ? this.completedBy
          : completedBy as AppUser?,
      completedAt: identical(completedAt, _controlUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      syncState: syncState ?? this.syncState,
      syncError: identical(syncError, _controlUnset)
          ? this.syncError
          : syncError as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'section_id': sectionId,
        'section_name': sectionName,
        'title': title,
        'description': description,
        'reference': reference,
        'contact': contact,
        'notes': notes,
        'priority': priority,
        'status': status,
        'due_state': dueState,
        'due_at': dueAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'reminder_minutes': reminderMinutes,
        'next_reminder_at': nextReminderAt?.toUtc().toIso8601String(),
        'recurrence_type': recurrenceType,
        'recurrence_interval': recurrenceInterval,
        'recurrence_unit': recurrenceUnit,
        'version': version,
        'created_by': createdBy.toJson(),
        'assignees': assignees.map((item) => item.toJson()).toList(growable: false),
        'completed_by': completedBy?.toJson(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'history': history.map((item) => item.toJson()).toList(growable: false),
      };
}
