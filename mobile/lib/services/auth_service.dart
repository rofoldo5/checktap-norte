import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/department.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class RegistrationResult {
  const RegistrationResult({
    required this.message,
    required this.notificationRegistered,
  });

  final String message;
  final bool notificationRegistered;
}

class AuthService {
  AuthService(this.apiClient);

  final ApiClient apiClient;

  Future<List<DepartmentSummary>> registrationDepartments() async {
    final response = await apiClient.dio.get<List<dynamic>>(
      '/auth/registration/departments',
    );
    return response.data!
        .map(
          (item) => DepartmentSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
    required String departmentId,
    Map<String, dynamic>? deviceRegistration,
  }) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'department_id': departmentId,
        'device_registration': ?deviceRegistration,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return RegistrationResult(
      message:
          data['message']?.toString() ??
          'Solicitud enviada. Un administrador debe aprobar tu acceso.',
      notificationRegistered: data['notification_registered'] as bool? ?? false,
    );
  }

  Future<AuthResult> login(String email, String password) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: <String, dynamic>{'email': email.trim(), 'password': password},
    );
    final data = response.data!;
    return AuthResult(
      token: data['access_token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<AppUser> me() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>('/auth/me');
    return AppUser.fromJson(response.data!);
  }
}
