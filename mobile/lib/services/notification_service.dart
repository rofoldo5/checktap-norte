import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api_client.dart';
import '../firebase_options.dart';

const AndroidNotificationChannel checkTapNotificationChannel =
    AndroidNotificationChannel(
      'checktap_high_importance',
      'Notificaciones CheckTap',
      description: 'Avisos de actividad del equipo y reportes diarios de CheckTap.',
      importance: Importance.max,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    '[FCM][BACKGROUND] id=${message.messageId} data=${message.data}',
  );
}

class NotificationEvent {
  const NotificationEvent({
    required this.source,
    required this.receivedAt,
    this.messageId,
    this.title,
    this.body,
    this.data = const <String, dynamic>{},
  });

  final String source;
  final DateTime receivedAt;
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

class NotificationActivationResult {
  const NotificationActivationResult({
    required this.authorizationStatus,
    required this.token,
  });

  final AuthorizationStatus authorizationStatus;
  final String? token;

  bool get authorized {
    return authorizationStatus == AuthorizationStatus.authorized ||
        authorizationStatus == AuthorizationStatus.provisional;
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<AuthorizationStatus> authorizationStatus =
      ValueNotifier<AuthorizationStatus>(AuthorizationStatus.notDetermined);
  final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  final ValueNotifier<NotificationEvent?> lastEvent =
      ValueNotifier<NotificationEvent?>(null);
  final ValueNotifier<String?> initializationError =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> backendRegistrationStatus =
      ValueNotifier<String?>(null);

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  ApiClient? _apiClient;
  Future<bool>? _registrationFuture;
  DateTime? _lastRegistrationAt;
  bool _initialized = false;

  bool get initialized => _initialized;

  void attachApiClient(ApiClient apiClient) {
    _apiClient = apiClient;
  }

  void detachApiClient() {
    _apiClient = null;
    _lastRegistrationAt = null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      await FirebaseMessaging.instance.setAutoInitEnabled(true);

      const androidSettings = AndroidInitializationSettings(
        'ic_stat_checktap',
      );
      const iosSettings = IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(checkTapNotificationChannel);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      authorizationStatus.value = settings.authorizationStatus;

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _recordRemoteEvent('abierta desde segundo plano', message),
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (newToken) {
              token.value = newToken;
              debugPrint('[FCM] Token renovado: ${maskToken(newToken)}');
              unawaited(
                _uploadRegistration(newToken, force: true).then<void>((_) {}),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('[FCM] Error renovando token: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
          );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _recordRemoteEvent('abierta desde cerrada', initialMessage);
      }

      _initialized = true;
      initializationError.value = null;

      if (_isAuthorized(settings.authorizationStatus)) {
        try {
          await refreshToken();
        } catch (error, stackTrace) {
          debugPrint('[FCM] No fue posible obtener el token inicial: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      debugPrint(
        '[FCM] Inicializado para ${DefaultFirebaseOptions.currentPlatform.projectId}',
      );
    } catch (error, stackTrace) {
      initializationError.value = error.toString();
      debugPrint('[FCM] Inicializacion no disponible: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<NotificationActivationResult> requestPermissionAndToken() async {
    await initialize();

    if (!_initialized) {
      throw StateError(
        initializationError.value ?? 'Firebase no pudo inicializarse.',
      );
    }

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    authorizationStatus.value = settings.authorizationStatus;

    String? currentToken;
    if (_isAuthorized(settings.authorizationStatus)) {
      currentToken = await refreshToken();
    }

    return NotificationActivationResult(
      authorizationStatus: settings.authorizationStatus,
      token: currentToken,
    );
  }

  Future<bool> registerCurrentDevice({
    bool requestPermission = false,
    bool force = false,
  }) async {
    final running = _registrationFuture;
    if (running != null) {
      return running;
    }

    final future = _registerCurrentDeviceInternal(
      requestPermission: requestPermission,
      force: force,
    );
    _registrationFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_registrationFuture, future)) {
        _registrationFuture = null;
      }
    }
  }

  Future<bool> _registerCurrentDeviceInternal({
    required bool requestPermission,
    required bool force,
  }) async {
    final apiClient = _apiClient;
    if (apiClient == null || apiClient.token == null) {
      backendRegistrationStatus.value = 'Sin sesion autenticada';
      return false;
    }

    await initialize();
    if (!_initialized) {
      backendRegistrationStatus.value = 'Firebase no inicializado';
      return false;
    }

    String? currentToken;
    if (requestPermission) {
      final activation = await requestPermissionAndToken();
      if (!activation.authorized) {
        backendRegistrationStatus.value = 'Permiso no autorizado';
        return false;
      }
      currentToken = activation.token;
    } else {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      authorizationStatus.value = settings.authorizationStatus;
      if (!_isAuthorized(settings.authorizationStatus)) {
        backendRegistrationStatus.value = 'Permiso pendiente';
        return false;
      }
      currentToken = await refreshToken();
    }

    if (currentToken == null || currentToken.isEmpty) {
      backendRegistrationStatus.value = 'FCM no devolvio token';
      return false;
    }

    return _uploadRegistration(currentToken, force: force);
  }

  Future<bool> _uploadRegistration(
    String registrationId, {
    required bool force,
  }) async {
    final apiClient = _apiClient;
    if (apiClient == null || apiClient.token == null) {
      return false;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRegistrationAt != null &&
        now.difference(_lastRegistrationAt!) < const Duration(hours: 12)) {
      return true;
    }

    try {
      await apiClient.dio.post<Map<String, dynamic>>(
        '/devices',
        data: <String, dynamic>{
          'registration_id': registrationId,
          'registration_kind': 'TOKEN',
          'platform': _platformName(),
          'device_name': _deviceName(),
        },
      );
      _lastRegistrationAt = now;
      backendRegistrationStatus.value = 'Registrado en CheckTap';
      debugPrint('[FCM] Dispositivo registrado en el backend');
      return true;
    } on DioException catch (error, stackTrace) {
      backendRegistrationStatus.value =
          'No registrado: ${error.response?.statusCode ?? 'sin conexion'}';
      debugPrint('[FCM] No fue posible registrar el dispositivo: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      backendRegistrationStatus.value = 'No registrado: $error';
      debugPrint('[FCM] Error registrando dispositivo: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final currentToken = token.value;
    final apiClient = _apiClient;

    if (currentToken != null &&
        currentToken.isNotEmpty &&
        apiClient != null &&
        apiClient.token != null) {
      try {
        await apiClient.dio.delete<void>(
          '/devices/current',
          data: <String, dynamic>{'registration_id': currentToken},
        );
      } catch (error, stackTrace) {
        debugPrint('[FCM] No fue posible desregistrar en el backend: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error, stackTrace) {
      debugPrint('[FCM] No fue posible eliminar el token local: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    token.value = null;
    _lastRegistrationAt = null;
    backendRegistrationStatus.value = 'Dispositivo desregistrado';
  }

  Future<Map<String, dynamic>> fetchBackendStatus() async {
    final apiClient = _apiClient;
    if (apiClient == null || apiClient.token == null) {
      throw StateError('No hay una sesion autenticada.');
    }
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/notifications/status',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendBackendTest() async {
    final apiClient = _apiClient;
    if (apiClient == null || apiClient.token == null) {
      throw StateError('No hay una sesion autenticada.');
    }
    await registerCurrentDevice(force: true);
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/notifications/test',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendDepartmentTest() async {
    final apiClient = _apiClient;
    if (apiClient == null || apiClient.token == null) {
      throw StateError('No hay una sesion autenticada.');
    }
    await registerCurrentDevice(force: true);
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/notifications/test-department',
      data: const <String, dynamic>{},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> refreshStatus() async {
    await initialize();
    if (!_initialized) {
      return;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    authorizationStatus.value = settings.authorizationStatus;

    if (_isAuthorized(settings.authorizationStatus)) {
      await refreshToken();
    } else {
      token.value = null;
    }
  }

  Future<String?> refreshToken() async {
    final currentToken = await FirebaseMessaging.instance.getToken();
    token.value = currentToken;
    debugPrint('[FCM] Token actual: ${maskToken(currentToken)}');
    return currentToken;
  }

  Future<String?> regenerateToken() async {
    await initialize();
    if (!_initialized) {
      throw StateError(
        initializationError.value ?? 'Firebase no pudo inicializarse.',
      );
    }

    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.deleteToken();
    token.value = null;

    await Future<void>.delayed(const Duration(seconds: 2));
    final currentToken = await refreshToken();
    if (currentToken == null || currentToken.isEmpty) {
      throw StateError('FCM no devolvio un token nuevo.');
    }
    await _uploadRegistration(currentToken, force: true);
    return currentToken;
  }

  Future<void> showLocalTestNotification() async {
    await initialize();
    if (!_initialized) {
      throw StateError(
        initializationError.value ?? 'Firebase no pudo inicializarse.',
      );
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'checktap_high_importance',
        'Notificaciones CheckTap',
        channelDescription:
            'Avisos de actividad del equipo y reportes diarios de CheckTap.',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_stat_checktap',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: 'CheckTap',
      body: 'La notificacion local funciona correctamente.',
      notificationDetails: details,
      payload: jsonEncode(<String, String>{
        'type': 'local_test',
        'source': 'checktap_app',
      }),
    );

    lastEvent.value = NotificationEvent(
      source: 'prueba local',
      receivedAt: DateTime.now(),
      title: 'CheckTap',
      body: 'La notificacion local funciona correctamente.',
      data: const <String, String>{'type': 'local_test'},
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _recordRemoteEvent('primer plano', message);

    final notification = message.notification;
    final title = notification?.title ?? 'CheckTap';
    final body = notification?.body ?? _bodyFromData(message.data);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'checktap_high_importance',
        'Notificaciones CheckTap',
        channelDescription:
            'Avisos de actividad del equipo y reportes diarios de CheckTap.',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_stat_checktap',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: message.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  void _recordRemoteEvent(String source, RemoteMessage message) {
    lastEvent.value = NotificationEvent(
      source: source,
      receivedAt: DateTime.now(),
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
    );

    debugPrint(
      '[FCM][$source] id=${message.messageId} '
      'title=${message.notification?.title} data=${message.data}',
    );
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    lastEvent.value = NotificationEvent(
      source: 'toque en notificacion local',
      receivedAt: DateTime.now(),
      messageId: response.id?.toString(),
      data: <String, dynamic>{
        'payload': response.payload,
        'actionId': response.actionId,
      },
    );
  }

  String _bodyFromData(Map<String, dynamic> data) {
    final body = data['body']?.toString();
    if (body != null && body.trim().isNotEmpty) {
      return body;
    }
    return 'Tiene una nueva actualizacion en CheckTap.';
  }

  bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }

  String _deviceName() {
    return switch (_platformName()) {
      'android' => 'CheckTap Android',
      'ios' => 'CheckTap iOS',
      'web' => 'CheckTap Web',
      _ => 'CheckTap',
    };
  }

  static String maskToken(String? value) {
    if (value == null || value.isEmpty) {
      return 'No disponible';
    }
    if (value.length <= 20) {
      return value;
    }
    return '${value.substring(0, 10)}...${value.substring(value.length - 8)}';
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }
}
