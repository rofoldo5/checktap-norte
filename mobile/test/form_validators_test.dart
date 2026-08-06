import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/core/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('rechaza textos requeridos vacíos o con espacios', () {
      expect(FormValidators.departmentName('   '), isNotNull);
      expect(FormValidators.personName('\n\t  '), isNotNull);
      expect(FormValidators.taskTitle('  '), isNotNull);
    });

    test('normaliza espacios internos y extremos', () {
      expect(
        FormValidators.normalizeSingleLine('  Control   de\nCalidad  '),
        'Control de Calidad',
      );
    });

    test('valida correos y contraseñas', () {
      expect(FormValidators.email('sin-arroba'), isNotNull);
      expect(FormValidators.email('usuario@example.com'), isNull);
      expect(FormValidators.password('      '), isNotNull);
      expect(FormValidators.password('12345'), isNotNull);
      expect(FormValidators.password('123456'), isNull);
      expect(FormValidators.password('', optional: true), isNull);
    });

    test('permite descripción vacía y limita longitud', () {
      expect(FormValidators.optionalDescription('   '), isNull);
      expect(FormValidators.optionalDescription('x' * 3001), isNotNull);
    });
  });
}
