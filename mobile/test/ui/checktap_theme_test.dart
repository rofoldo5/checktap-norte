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

  test('tema oscuro usa superficies y contraste premium CheckTap', () {
    final theme = CheckTapTheme.dark;

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, CheckTapColors.darkBackground);
    expect(theme.colorScheme.surface, CheckTapColors.darkSurface);
    expect(theme.colorScheme.primary, CheckTapColors.darkPrimary);
    expect(theme.colorScheme.onSurface, CheckTapColors.darkText);
    expect(
      theme.navigationBarTheme.backgroundColor,
      CheckTapColors.darkSurface,
    );
    expect(
      theme.navigationBarTheme.indicatorColor,
      CheckTapColors.darkSurfaceElevated,
    );
    expect(
      theme.inputDecorationTheme.fillColor,
      CheckTapColors.darkSurfaceSoft,
    );
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
