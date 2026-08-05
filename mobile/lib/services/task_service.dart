import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/sync_operation.dart';
import '../models/task_item.dart';

class TaskService {
  TaskService(this.apiClient);

  final ApiClient apiClient;

  Future<List<TaskItem>> listTasks({String? status}) async {
    final response = await apiClient.dio.get<List<dynamic>>(
      '/tasks',
      queryParameters: status == null
          ? null
          : <String, String>{'status': status},
    );
    return response.data!
        .map(
          (item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<AppUser>> listUsers() async {
    final response = await apiClient.dio.get<List<dynamic>>('/users');
    return response.data!
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<AppUser>> listManagedUsers() async {
    final response = await apiClient.dio.get<List<dynamic>>('/users/manage');
    return response.data!
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/users',
      data: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'is_admin': isAdmin,
      },
    );
    return AppUser.fromJson(response.data!);
  }

  Future<AppUser> updateUser(
    AppUser user, {
    String? name,
    String? password,
    bool? isAdmin,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name.trim();
    }
    if (password != null && password.isNotEmpty) {
      data['password'] = password;
    }
    if (isAdmin != null) {
      data['is_admin'] = isAdmin;
    }
    if (isActive != null) {
      data['is_active'] = isActive;
    }
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/users/${user.id}',
      data: data,
    );
    return AppUser.fromJson(response.data!);
  }

  Future<Uint8List> downloadDailyReport(DateTime date) async {
    final day = date.toIso8601String().split('T').first;
    final response = await apiClient.dio.get<List<int>>(
      '/reports/daily.pdf',
      queryParameters: <String, String>{'date': day},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<SyncOperationResult> processOperation(SyncOperation operation) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/sync/operations',
      data: <String, dynamic>{
        'operations': <Map<String, dynamic>>[operation.toApiJson()],
      },
    );
    final results = response.data!['results'] as List<dynamic>;
    return SyncOperationResult.fromJson(
      Map<String, dynamic>.from(results.first as Map),
    );
  }
}
