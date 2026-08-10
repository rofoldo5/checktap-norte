import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/ui/components/developer_credit.dart';

void main() {
  testWidgets('muestra la autoría exacta en tema claro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DeveloperCredit())),
    );

    expect(find.text('Creado: Rodolfo Betancourt'), findsOneWidget);
  });

  testWidgets('muestra la autoría exacta sobre superficie de marca', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.dark,
        home: Scaffold(body: DeveloperCredit(onBrandSurface: true)),
      ),
    );

    expect(find.text('Creado: Rodolfo Betancourt'), findsOneWidget);
  });
}
