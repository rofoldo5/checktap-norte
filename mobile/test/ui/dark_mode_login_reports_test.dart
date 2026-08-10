import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Login usa superficies adaptativas de modo oscuro', () {
    final source = File('lib/screens/login_screen.dart').readAsStringSync();

    expect(source, contains('CheckTapColors.quietGradientFor(context)'));
    expect(source, contains('CheckTapColors.panelGradientFor(context)'));
    expect(source, contains('CheckTapColors.borderFor(context)'));
    expect(source, contains('CheckTapColors.textMutedFor(context)'));
  });

  test('Informes usa superficies y controles adaptativos', () {
    final source = File('lib/screens/report_screen.dart').readAsStringSync();

    expect(source, contains('CheckTapColors.panelGradientFor(context)'));
    expect(source, contains('CheckTapColors.panelControlFillFor(context)'));
    expect(
      source,
      contains(
        RegExp(r'CheckTapColors\.panelControlBorderFor\(\s*context,?\s*\)'),
      ),
    );
    expect(source, contains('CheckTapColors.adaptAccent(context, color)'));
  });
}
