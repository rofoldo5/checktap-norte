class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get normalizedBaseUrl => apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;

  static String websocketUrl(String token) {
    final httpUri = Uri.parse('$normalizedBaseUrl/api/v1/ws/tasks');

    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';

    return httpUri
        .replace(
          scheme: scheme,
          queryParameters: <String, String>{'token': token},
        )
        .toString();
  }
}
