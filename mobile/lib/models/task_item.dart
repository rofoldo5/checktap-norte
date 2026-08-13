import 'app_user.dart';
import 'department.dart';
import 'task_checklist.dart';
import 'task_recurrence.dart';

const Object _unset = Object();

enum LocalSyncState {
  synced,
  pending,
  syncing,
  error,
  conflict;

  String get databaseValue => name.toUpperCase();

  static LocalSyncState fromDatabase(String? value) {
    return LocalSyncState.values.firstWhere(
      (state) => state.databaseValue == value,
      orElse: () => LocalSyncState.synced,
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.description,
    this.department = DepartmentSummary.unknown,
    this.assignees = const <AppUser>[],
    this.assignedTo,
    this.completedBy,
    this.completedAt,
    this.checklists = const <TaskChecklist>[],
    this.recurrence = TaskRecurrence.none,
    this.syncState = LocalSyncState.synced,
    this.syncError,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final int version;
  final DepartmentSummary department;
  final AppUser createdBy;
  final List<AppUser> assignees;
  final AppUser? assignedTo;
  final AppUser? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<TaskChecklist> checklists;
  final TaskRecurrence recurrence;
  final LocalSyncState syncState;
  final String? syncError;

  bool get hasPendingChanges {
    return syncState == LocalSyncState.pending ||
        syncState == LocalSyncState.syncing ||
        syncState == LocalSyncState.error;
  }

  String get assigneeLabel {
    if (assignees.isEmpty) {
      return assignedTo?.name ?? 'Todo el equipo';
    }
    return assignees.map((user) => user.name).join(', ');
  }

  factory TaskItem.fromJson(
    Map<String, dynamic> json, {
    LocalSyncState syncState = LocalSyncState.synced,
    String? syncError,
  }) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final assignedTo = json['assigned_to'] == null
        ? null
        : AppUser.fromJson(
            Map<String, dynamic>.from(json['assigned_to'] as Map),
          );
    final rawAssignees = json['assignees'] as List<dynamic>?;
    final assignees =
        rawAssignees
            ?.map(
              (item) =>
                  AppUser.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false) ??
        <AppUser>[?assignedTo];
    final rawChecklists =
        json['checklists'] as List<dynamic>? ?? const <dynamic>[];
    final checklists =
        rawChecklists
            .map(
              (item) => TaskChecklist.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final position = a.position.compareTo(b.position);
            return position != 0
                ? position
                : a.createdAt.compareTo(b.createdAt);
          });
    return TaskItem(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      department: json['department'] == null
          ? DepartmentSummary.unknown
          : DepartmentSummary.fromJson(
              Map<String, dynamic>.from(json['department'] as Map),
            ),
      createdBy: AppUser.fromJson(
        Map<String, dynamic>.from(json['created_by'] as Map),
      ),
      assignees: assignees,
      assignedTo: assignedTo ?? (assignees.isEmpty ? null : assignees.first),
      completedBy: json['completed_by'] == null
          ? null
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['completed_by'] as Map),
            ),
      createdAt: createdAt,
      updatedAt: json['updated_at'] == null
          ? createdAt
          : DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      checklists: checklists,
      recurrence: TaskRecurrence.fromJson(json),
      syncState: syncState,
      syncError: syncError,
    );
  }

  TaskItem copyWith({
    String? title,
    Object? description = _unset,
    String? status,
    String? priority,
    int? version,
    DepartmentSummary? department,
    AppUser? createdBy,
    List<AppUser>? assignees,
    Object? assignedTo = _unset,
    Object? completedBy = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    List<TaskChecklist>? checklists,
    TaskRecurrence? recurrence,
    LocalSyncState? syncState,
    Object? syncError = _unset,
  }) {
    final nextAssignees = assignees ?? this.assignees;
    return TaskItem(
      id: id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      version: version ?? this.version,
      department: department ?? this.department,
      createdBy: createdBy ?? this.createdBy,
      assignees: nextAssignees,
      assignedTo: identical(assignedTo, _unset)
          ? (nextAssignees.isNotEmpty ? nextAssignees.first : this.assignedTo)
          : assignedTo as AppUser?,
      completedBy: identical(completedBy, _unset)
          ? this.completedBy
          : completedBy as AppUser?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      checklists: checklists ?? this.checklists,
      recurrence: recurrence ?? this.recurrence,
      syncState: syncState ?? this.syncState,
      syncError: identical(syncError, _unset)
          ? this.syncError
          : syncError as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'version': version,
      'department': department.toJson(),
      'created_by': createdBy.toJson(),
      'assignees': assignees.map((user) => user.toJson()).toList(),
      'assigned_to': assignedTo?.toJson(),
      'completed_by': completedBy?.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'checklists': checklists
          .map((checklist) => checklist.toJson())
          .toList(growable: false),
      ...recurrence.toStorageJson(),
    };
  }
}
