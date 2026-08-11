import 'package:checktap/models/app_user.dart';
import 'package:checktap/ui/components/checktap_shell.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const admin = AppUser(
    id: 'admin-1',
    name: 'Administradora',
    email: 'admin@example.com',
    isAdmin: true,
  );

  testWidgets('el menu muestra el total de solicitudes pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: CheckTapDrawer(
          user: admin,
          isAdmin: true,
          pendingOperations: 0,
          pendingAccessRequests: 7,
          onAccessRequests: () {},
          onUsers: () {},
          onDepartments: () {},
          onReports: () {},
          onNotifications: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('Solicitudes de acceso'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('la barra superior limita contadores grandes a 99+', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: Scaffold(
          appBar: CheckTapTopBar(
            title: const Text('CheckTap'),
            onMenu: () {},
            connectionIcon: Icons.cloud_done,
            connectionTooltip: 'Conectado',
            onSync: () {},
            pendingAccessRequests: 125,
          ),
        ),
      ),
    );

    expect(find.text('99+'), findsOneWidget);
    expect(
      find.byTooltip('Abrir menú, 125 solicitud(es) pendiente(s)'),
      findsOneWidget,
    );
  });
}
