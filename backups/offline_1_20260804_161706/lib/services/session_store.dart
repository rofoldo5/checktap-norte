import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._(this.apiClient, this._preferences)
      : authService = AuthService(apiClient);

  static const _tokenKey = 'access_token';

  final ApiClient apiClient;
  final SharedPreferences _preferences;
  final AuthService authService;

  String? token;
  AppUser? user;
  bool initialized = false;

  bool get isAuthenticated => token != null && user != null;

  static Future<SessionStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    final apiClient = ApiClient();
    final store = SessionStore._(apiClient, preferences);
    await store._restore();
    return store;
  }

  Future<void> _restore() async {
    token = _preferences.getString(_tokenKey);
    apiClient.setToken(token);

    if (token != null) {
      try {
        user = await authService.me();
      } catch (_) {
        await _clearSession();
      }
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await authService.login(email, password);
    token = result.token;
    user = result.user;
    apiClient.setToken(token);
    await _preferences.setString(_tokenKey, token!);
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    token = null;
    user = null;
    apiClient.setToken(null);
    await _preferences.remove(_tokenKey);
  }
}
