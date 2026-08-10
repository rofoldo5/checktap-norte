import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeveloperCredit esta conectado en Login y Dashboard', () {
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final dashboard = File(
      'lib/screens/task_list_screen.dart',
    ).readAsStringSync();

    expect(login, contains("import '../ui/components/developer_credit.dart';"));
    expect(login, contains("ValueKey<String>('login-developer-credit')"));
    expect(
      dashboard,
      contains("import '../ui/components/developer_credit.dart';"),
    );
    expect(
      dashboard,
      contains("ValueKey<String>('dashboard-developer-credit')"),
    );
  });
}
