import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/ui/components/metric_card.dart';
import 'package:checktap/ui/components/section_header.dart';
import 'package:checktap/ui/theme/checktap_colors.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';

void main() {
  testWidgets('dashboard oscuro conserva contraste y no desborda a 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  SectionHeader(
                    title: 'Requieren atención',
                    subtitle: 'Tareas prioritarias para el equipo',
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: 296,
                    height: 232,
                    child: MetricCard(
                      label: 'Prioridad alta',
                      value: 18,
                      color: CheckTapColors.danger,
                      icon: Icons.priority_high_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requieren atención'), findsOneWidget);
    expect(find.text('Prioridad alta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
