import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

class SecureSessionStorage {
  const SecureSessionStorage([this._storage = const FlutterSecureStorage()]);

  static const String tokenKey = 'checktap_access_token';
  static const String userKey = 'checktap_session_user';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: tokenKey);

  Future<void> writeToken(String token) {
    return _storage.write(key: tokenKey, value: token);
  }

  Future<AppUser?> readUser() async {
    final raw = await _storage.read(key: userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AppUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await _storage.delete(key: userKey);
      return null;
    }
  }

  Future<void> writeUser(AppUser user) {
    return _storage.write(key: userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: userKey);
  }
}
