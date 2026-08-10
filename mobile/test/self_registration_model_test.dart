import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/app_user.dart';

void main() {
  test('AppUser interpreta los estados de aprobación', () {
    final pending = AppUser.fromJson(<String, dynamic>{
      'id': 'pending-user',
      'name': 'Usuario Pendiente',
      'email': 'pendiente@example.com',
      'is_admin': false,
      'is_active': false,
      'account_status': 'PENDING',
      'department_ids': <String>['department-1'],
    });

    expect(pending.isPending, isTrue);
    expect(pending.isApproved, isFalse);
    expect(pending.accountStatusLabel, 'Pendiente');
    expect(pending.toJson()['account_status'], 'PENDING');

    final legacyInactive = AppUser.fromJson(<String, dynamic>{
      'id': 'legacy-user',
      'name': 'Usuario anterior',
      'email': 'anterior@example.com',
      'is_active': false,
    });
    expect(legacyInactive.isSuspended, isTrue);
    expect(legacyInactive.accountStatusLabel, 'Suspendida');
  });

  test(
    'registro y revisión administrativa están conectados a navegación y API',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final login = File('lib/screens/login_screen.dart').readAsStringSync();
      final registration = File(
        'lib/screens/registration_screen.dart',
      ).readAsStringSync();
      final requests = File(
        'lib/screens/access_requests_screen.dart',
      ).readAsStringSync();
      final auth = File('lib/services/auth_service.dart').readAsStringSync();
      final taskService = File(
        'lib/services/task_service.dart',
      ).readAsStringSync();

      expect(main, contains("'/register'"));
      expect(login, contains("ValueKey<String>('create-account-button')"));
      expect(registration, contains("ValueKey<String>('submit-registration')"));
      expect(auth, contains("'/auth/register'"));
      expect(requests, contains('Solicitudes de acceso'));
      expect(taskService, contains("'/users/access-requests'"));
      expect(taskService, contains("'/users/\${user.id}/approve'"));
      expect(taskService, contains("'/users/\${user.id}/reject'"));
    },
  );
}
