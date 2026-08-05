import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: '${AppConfig.normalizedBaseUrl}/api/v1',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: <String, String>{'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final currentToken = token;
          if (currentToken != null && currentToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $currentToken';
          }
          if (kDebugMode) {
            debugPrint('[HTTP] -> ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[HTTP] <- ${response.statusCode} '
              '${response.requestOptions.method} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              '[HTTP] xx ${error.response?.statusCode ?? 'SIN_RESPUESTA'} '
              '${error.requestOptions.method} ${error.requestOptions.uri}: '
              '${error.message}',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  String? token;

  void setToken(String? value) {
    token = value;
  }
}
