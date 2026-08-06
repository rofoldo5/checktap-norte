import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/daily_report.dart';
import '../models/department.dart';
import '../models/sync_operation.dart';
import '../models/task_item.dart';

class TaskService {
  TaskService(this.apiClient);

  final ApiClient apiClient;

  Future<List<TaskItem>> listTasks({
    String? status,
    String? departmentId,
  }) async {
    final query = <String, dynamic>{
      'status': ?status,
      'department_id': ?departmentId,
    };
    final response = await apiClient.dio.get<List<dynamic>>(
      '/tasks',
      queryParameters: query.isEmpty ? null : query,
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

  Future<List<DepartmentSummary>> listDepartments() async {
    final response = await apiClient.dio.get<List<dynamic>>('/departments');
    return response.data!
        .map(
          (item) => DepartmentSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<DepartmentDetail> getDepartment(String departmentId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/departments/$departmentId',
    );
    return DepartmentDetail.fromJson(response.data!);
  }

  Future<DepartmentDetail> createDepartment({required String name}) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/departments',
      data: <String, dynamic>{'name': name.trim()},
    );
    return DepartmentDetail.fromJson(response.data!);
  }

  Future<DepartmentDetail> updateDepartment(
    DepartmentSummary department, {
    String? name,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'name': ?name?.trim(),
      'is_active': ?isActive,
    };
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/departments/${department.id}',
      data: data,
    );
    return DepartmentDetail.fromJson(response.data!);
  }

  Future<DepartmentDetail> replaceDepartmentMembers(
    String departmentId,
    List<String> userIds,
  ) async {
    final response = await apiClient.dio.put<Map<String, dynamic>>(
      '/departments/$departmentId/members',
      data: <String, dynamic>{'user_ids': userIds},
    );
    return DepartmentDetail.fromJson(response.data!);
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
    List<String> departmentIds = const <String>[],
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/users',
      data: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'is_admin': isAdmin,
        'department_ids': departmentIds,
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
    List<String>? departmentIds,
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
    if (departmentIds != null) {
      data['department_ids'] = departmentIds;
    }
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/users/${user.id}',
      data: data,
    );
    return AppUser.fromJson(response.data!);
  }

  Future<Uint8List> downloadDailyReport(
    DateTime date, {
    String? departmentId,
  }) async {
    final day = date.toIso8601String().split('T').first;
    final response = await apiClient.dio.get<List<int>>(
      '/reports/daily.pdf',
      queryParameters: <String, String>{
        'date': day,
        'department_id': ?departmentId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<List<DailyReportItem>> listGeneratedReports({
    String? departmentId,
  }) async {
    final response = await apiClient.dio.get<List<dynamic>>(
      '/reports',
      queryParameters: departmentId == null
          ? null
          : <String, String>{'department_id': departmentId},
    );
    return response.data!
        .map(
          (item) =>
              DailyReportItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<DailyReportItem> generateDailyReport({
    DateTime? date,
    String? departmentId,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/reports/generate',
      data: <String, dynamic>{
        'report_date': ?date?.toIso8601String().split('T').first,
        'department_id': ?departmentId,
      },
    );
    return DailyReportItem.fromJson(response.data!);
  }

  Future<Uint8List> downloadGeneratedReport(String reportId) async {
    final response = await apiClient.dio.get<List<int>>(
      '/reports/$reportId/download',
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
