import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/task_item.dart';

class TaskService {
  TaskService(this.apiClient);

  final ApiClient apiClient;

  Future<List<TaskItem>> listTasks({String? status}) async {
    final response = await apiClient.dio.get<List<dynamic>>(
      '/tasks',
      queryParameters: status == null ? null : <String, String>{'status': status},
    );
    return response.data!
        .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppUser>> listUsers() async {
    final response = await apiClient.dio.get<List<dynamic>>('/users');
    return response.data!
        .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskItem> createTask({
    required String title,
    required String description,
    required String priority,
    String? assignedToId,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/tasks',
      data: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'priority': priority,
        'assigned_to_id': assignedToId,
      },
    );
    return TaskItem.fromJson(response.data!);
  }

  Future<void> startTask(String id) async {
    await apiClient.dio.post<void>('/tasks/$id/start');
  }

  Future<void> completeTask(String id) async {
    await apiClient.dio.post<void>('/tasks/$id/complete');
  }

  Future<void> reopenTask(String id) async {
    await apiClient.dio.post<void>('/tasks/$id/reopen');
  }
}
