import 'app_user.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.assignedTo,
    this.completedBy,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final AppUser createdBy;
  final AppUser? assignedTo;
  final AppUser? completedBy;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      createdBy: AppUser.fromJson(json['created_by'] as Map<String, dynamic>),
      assignedTo: json['assigned_to'] == null
          ? null
          : AppUser.fromJson(json['assigned_to'] as Map<String, dynamic>),
      completedBy: json['completed_by'] == null
          ? null
          : AppUser.fromJson(json['completed_by'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );
  }
}
