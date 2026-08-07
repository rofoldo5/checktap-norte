import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/department.dart';
import 'package:checktap/models/task_item.dart';
import 'package:checktap/ui/components/metric_card.dart';
import 'package:checktap/ui/components/task_card.dart';
import 'package:checktap/ui/theme/checktap_colors.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';
import 'package:checktap/widgets/task_form_dialog.dart';

void main() {
  const user = AppUser(
    id: 'user-1',
    name: 'Usuario con nombre extenso',
    email: 'usuario@example.com',
    departmentIds: <String>['department-1'],
  );
  const department = DepartmentSummary(
    id: 'department-1',
    name: 'Departamento de operaciones y soporte',
  );

  Future<void> setCompactViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  MediaQuery compactMediaQuery({required Widget child}) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 720),
        textScaler: TextScaler.linear(2),
      ),
      child: child,
    );
  }

  testWidgets('tarjeta y métrica no desbordan a 320 px con texto al 200 %', (
    tester,
  ) async {
    await setCompactViewport(tester);
    final task = TaskItem(
      id: 'task-1',
      title: 'Actualizar el servidor principal del departamento',
      description:
          'Descripción extensa para validar una interfaz legible y adaptable.',
      status: 'PENDIENTE',
      priority: 'ALTA',
      department: department,
      createdBy: user,
      assignees: const <AppUser>[user],
      createdAt: DateTime.utc(2026, 8, 7),
      updatedAt: DateTime.utc(2026, 8, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: compactMediaQuery(
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  const SizedBox(
                    width: 296,
                    height: 232,
                    child: MetricCard(
                      label: 'Prioridad alta',
                      value: 18,
                      color: CheckTapColors.danger,
                      icon: Icons.priority_high_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckTapTaskCard(
                    task: task,
                    canEdit: true,
                    canWork: true,
                    canReopen: false,
                    onOpen: () {},
                    onStart: () {},
                    onComplete: () {},
                    onReopen: () {},
                    onResolveConflict: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prioridad alta'), findsOneWidget);
    expect(
      find.text('Actualizar el servidor principal del departamento'),
      findsOneWidget,
    );
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Sincronizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulario de tarea se reorganiza con texto al 200 %', (
    tester,
  ) async {
    await setCompactViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: compactMediaQuery(
          child: TaskFormDialog(
            dialogTitle: 'Nueva tarea',
            submitLabel: 'Crear',
            departments: const <DepartmentSummary>[department],
            users: const <AppUser>[user],
            initialDepartmentId: department.id,
            errorMessage: (error) => error.toString(),
            onSubmit: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nueva tarea'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Baja'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Baja'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Alta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
