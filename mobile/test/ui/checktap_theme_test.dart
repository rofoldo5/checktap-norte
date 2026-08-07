import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/ui/theme/checktap_colors.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';

void main() {
  test('tema claro usa la identidad CheckTap', () {
    final theme = CheckTapTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, CheckTapColors.background);
    expect(theme.colorScheme.primary, CheckTapColors.primary);
    expect(theme.filledButtonTheme.style, isNotNull);
    expect(theme.navigationBarTheme.height, 72);
  });

  testWidgets('acciones principales conservan área táctil suficiente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Crear tarea'),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
