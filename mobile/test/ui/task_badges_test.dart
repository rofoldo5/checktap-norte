import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/ui/components/task_badges.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';

void main() {
  testWidgets('badges muestran estados y prioridades en español', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              PriorityBadge(priority: 'ALTA'),
              StatusChip(status: 'EN_PROGRESO'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Alta'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
