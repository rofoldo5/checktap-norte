import 'app_user.dart';

const Object _unset = Object();

class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.title,
    required this.position,
    required this.isCompleted,
    required this.version,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.completedBy,
    this.completedAt,
  });

  final String id;
  final String title;
  final int position;
  final bool isCompleted;
  final int version;
  final AppUser createdBy;
  final AppUser? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return TaskChecklistItem(
      id: json['id'].toString(),
      title: json['title'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: AppUser.fromJson(
        Map<String, dynamic>.from(json['created_by'] as Map),
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
    );
  }

  TaskChecklistItem copyWith({
    String? title,
    int? position,
    bool? isCompleted,
    int? version,
    AppUser? createdBy,
    Object? completedBy = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
  }) {
    return TaskChecklistItem(
      id: id,
      title: title ?? this.title,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      completedBy: identical(completedBy, _unset)
          ? this.completedBy
          : completedBy as AppUser?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'position': position,
      'is_completed': isCompleted,
      'version': version,
      'created_by': createdBy.toJson(),
      'completed_by': completedBy?.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
    };
  }
}

class TaskChecklist {
  const TaskChecklist({
    required this.id,
    required this.title,
    required this.position,
    required this.version,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.items = const <TaskChecklistItem>[],
  });

  final String id;
  final String title;
  final int position;
  final int version;
  final AppUser createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TaskChecklistItem> items;

  int get itemCount => items.length;
  int get completedCount => items.where((item) => item.isCompleted).length;
  bool get isCompleted => items.isNotEmpty && completedCount == itemCount;
  bool get isPartiallyCompleted => completedCount > 0 && !isCompleted;
  double get progress => itemCount == 0 ? 0 : completedCount / itemCount;

  factory TaskChecklist.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    final items =
        rawItems
            .map(
              (item) => TaskChecklistItem.fromJson(
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
    return TaskChecklist(
      id: json['id'].toString(),
      title: json['title'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: AppUser.fromJson(
        Map<String, dynamic>.from(json['created_by'] as Map),
      ),
      createdAt: createdAt,
      updatedAt: json['updated_at'] == null
          ? createdAt
          : DateTime.parse(json['updated_at'] as String),
      items: items,
    );
  }

  TaskChecklist copyWith({
    String? title,
    int? position,
    int? version,
    AppUser? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TaskChecklistItem>? items,
  }) {
    return TaskChecklist(
      id: id,
      title: title ?? this.title,
      position: position ?? this.position,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'position': position,
      'version': version,
      'created_by': createdBy.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'item_count': itemCount,
      'completed_count': completedCount,
      'is_completed': isCompleted,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}
