import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'secure_session_storage.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._(this.apiClient, this._sessionStorage, this._legacyPreferences)
    : authService = AuthService(apiClient);

  static const String _legacyTokenKey = 'access_token';

  final ApiClient apiClient;
  final SecureSessionStorage _sessionStorage;
  final SharedPreferences _legacyPreferences;
  final AuthService authService;

  String? token;
  AppUser? user;
  bool initialized = false;
  bool offlineSession = false;

  bool get isAuthenticated => token != null && user != null;

  static Future<SessionStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    const sessionStorage = SecureSessionStorage();
    final apiClient = ApiClient();
    final store = SessionStore._(apiClient, sessionStorage, preferences);
    await store._restore();
    return store;
  }

  Future<void> _restore() async {
    token = await _sessionStorage.readToken();

    if (token == null) {
      final legacyToken = _legacyPreferences.getString(_legacyTokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        token = legacyToken;
        await _sessionStorage.writeToken(legacyToken);
        await _legacyPreferences.remove(_legacyTokenKey);
      }
    }

    user = await _sessionStorage.readUser();
    apiClient.setToken(token);

    if (token != null) {
      try {
        user = await authService.me();
        offlineSession = false;
        await _sessionStorage.writeUser(user!);
      } on DioException catch (error) {
        if (_isUnauthorized(error)) {
          await _clearSession();
        } else {
          offlineSession = user != null;
          debugPrint(
            '[SESSION] Backend no disponible. '
            'Se conserva la sesion local: $offlineSession',
          );
        }
      } catch (error) {
        offlineSession = user != null;
        debugPrint('[SESSION] Restauracion local: $error');
      }
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await authService.login(email, password);
    token = result.token;
    user = result.user;
    offlineSession = false;
    apiClient.setToken(token);

    await _sessionStorage.writeToken(result.token);
    await _sessionStorage.writeUser(result.user);
    await _legacyPreferences.remove(_legacyTokenKey);
    notifyListeners();
  }

  Future<void> markServerAvailable() async {
    if (offlineSession) {
      offlineSession = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  bool _isUnauthorized(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  Future<void> _clearSession() async {
    token = null;
    user = null;
    offlineSession = false;
    apiClient.setToken(null);
    await _sessionStorage.clear();
    await _legacyPreferences.remove(_legacyTokenKey);
  }
}
