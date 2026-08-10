import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/performance_monitor.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/background_sync.dart';
import 'services/notification_service.dart';
import 'services/session_store.dart';
import 'ui/theme/checktap_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceMonitor.start();

  final stopwatch = Stopwatch()..start();
  final session = await SessionStore.create();

  runApp(CheckTapApp(session: session));

  stopwatch.stop();
  if (kDebugMode) {
    debugPrint(
      '[STARTUP] Primer árbol CheckTap en ${stopwatch.elapsedMilliseconds} ms',
    );
  }

  unawaited(_initializeBackgroundServices(session));
}

Future<void> _initializeBackgroundServices(SessionStore session) async {
  try {
    await Future.wait<void>(<Future<void>>[
      NotificationService.instance.initialize(),
      BackgroundSyncScheduler.initialize(),
    ]);

    NotificationService.instance.attachApiClient(session.apiClient);
    if (session.isAuthenticated) {
      await NotificationService.instance.registerCurrentDevice(
        requestPermission: true,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[STARTUP] Servicio secundario no disponible: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class CheckTapApp extends StatelessWidget {
  const CheckTapApp({required this.session, super.key});

  final SessionStore session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheckTap',
      debugShowCheckedModeBanner: false,
      theme: CheckTapTheme.light,
      darkTheme: CheckTapTheme.dark,
      themeMode: ThemeMode.system,
      home: session.isAuthenticated
          ? TaskListScreen(
              key: const ValueKey<String>('task-list-screen-initial'),
              session: session,
            )
          : LoginScreen(
              key: const ValueKey<String>('login-screen-initial'),
              session: session,
            ),
      routes: <String, WidgetBuilder>{
        '/login': (_) => LoginScreen(
          key: const ValueKey<String>('login-screen'),
          session: session,
        ),
        '/tasks': (_) => TaskListScreen(
          key: const ValueKey<String>('task-list-screen'),
          session: session,
        ),
        '/register': (_) => RegistrationScreen(
          key: const ValueKey<String>('registration-screen'),
          session: session,
        ),
      },
    );
  }
}
