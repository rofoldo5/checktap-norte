import '../core/api_client.dart';
import '../models/app_user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class AuthService {
  AuthService(this.apiClient);

  final ApiClient apiClient;

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
