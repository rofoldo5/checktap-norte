import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionStore.create();
  runApp(CheckTapApp(session: session));
}

class CheckTapApp extends StatelessWidget {
  const CheckTapApp({required this.session, super.key});

  final SessionStore session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheckTap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          alignLabelWithHint: true,
        ),
      ),
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
      },
    );
  }
}
