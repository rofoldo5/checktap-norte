import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/department.dart';
import 'package:checktap/widgets/department_form_dialog.dart';
import 'package:checktap/widgets/task_form_dialog.dart';
import 'package:checktap/widgets/user_form_dialog.dart';

void main() {
  const department = DepartmentSummary(
    id: 'department-1',
    name: 'Programación',
    memberCount: 1,
  );
  const user = AppUser(
    id: 'user-1',
    name: 'Usuario Uno',
    email: 'usuario@example.com',
    departmentIds: <String>['department-1'],
  );

  testWidgets('departamento vacío muestra validación sin excepción', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DepartmentFormDialog(
          title: 'Nuevo departamento',
          submitLabel: 'Crear',
          errorMessage: (error) => error.toString(),
          onSubmit: (_) async => submitted = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Crear'));
    await tester.pump();

    expect(find.text('Ingrese el nombre del departamento.'), findsOneWidget);
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usuario vacío muestra todas las validaciones sin excepción', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: UserFormDialog(
          departments: const <DepartmentSummary>[department],
          errorMessage: (error) => error.toString(),
          onSubmit: (_) async => submitted = true,
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '   ');
    await tester.enterText(fields.at(1), 'correo-invalido');
    await tester.enterText(fields.at(2), '123');
    await tester.tap(find.text('Crear'));
    await tester.pump();

    expect(find.text('Ingrese el nombre del usuario.'), findsOneWidget);
    expect(find.text('Ingrese un correo electrónico válido.'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres.'),
      findsOneWidget,
    );
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tarea vacía muestra validación sin excepción', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskFormDialog(
          dialogTitle: 'Nueva tarea',
          submitLabel: 'Crear',
          departments: const <DepartmentSummary>[department],
          users: const <AppUser>[user],
          initialDepartmentId: department.id,
          errorMessage: (error) => error.toString(),
          onSubmit: (_) async => submitted = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Crear'));
    await tester.pump();

    expect(find.text('Ingrese el título de la tarea.'), findsOneWidget);
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });
}
