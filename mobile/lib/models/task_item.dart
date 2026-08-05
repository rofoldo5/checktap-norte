import 'app_user.dart';

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
    this.assignedTo,
    this.completedBy,
    this.completedAt,
    this.syncState = LocalSyncState.synced,
    this.syncError,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final int version;
  final AppUser createdBy;
  final AppUser? assignedTo;
  final AppUser? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final LocalSyncState syncState;
  final String? syncError;

  bool get hasPendingChanges {
    return syncState == LocalSyncState.pending ||
        syncState == LocalSyncState.syncing ||
        syncState == LocalSyncState.error;
  }

  factory TaskItem.fromJson(
    Map<String, dynamic> json, {
    LocalSyncState syncState = LocalSyncState.synced,
    String? syncError,
  }) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return TaskItem(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: AppUser.fromJson(
        Map<String, dynamic>.from(json['created_by'] as Map),
      ),
      assignedTo: json['assigned_to'] == null
          ? null
          : AppUser.fromJson(
              Map<String, dynamic>.from(json['assigned_to'] as Map),
            ),
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
    AppUser? createdBy,
    Object? assignedTo = _unset,
    Object? completedBy = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    LocalSyncState? syncState,
    Object? syncError = _unset,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: identical(assignedTo, _unset)
          ? this.assignedTo
          : assignedTo as AppUser?,
      completedBy: identical(completedBy, _unset)
          ? this.completedBy
          : completedBy as AppUser?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
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
      'created_by': createdBy.toJson(),
      'assigned_to': assignedTo?.toJson(),
      'completed_by': completedBy?.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
    };
  }
}
