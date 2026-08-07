import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/department.dart';
import 'package:checktap/models/task_item.dart';
import 'package:checktap/ui/components/task_card.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';

void main() {
  const user = AppUser(
    id: 'user',
    name: 'Carlos Pérez',
    email: 'carlos@example.com',
  );
  const department = DepartmentSummary(id: 'department', name: 'Programación');

  testWidgets('tarjeta de tarea presenta contenido y acción principal', (
    tester,
  ) async {
    var completed = false;
    final task = TaskItem(
      id: 'task',
      title: 'Actualizar servidor principal',
      description: 'Aplicar la actualización estable.',
      status: 'PENDIENTE',
      priority: 'ALTA',
      department: department,
      createdBy: user,
      assignees: const <AppUser>[user],
      createdAt: DateTime.utc(2026, 8, 6),
      updatedAt: DateTime.utc(2026, 8, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: Scaffold(
          body: CheckTapTaskCard(
            task: task,
            canEdit: true,
            canWork: true,
            canReopen: false,
            onOpen: () {},
            onStart: () {},
            onComplete: () => completed = true,
            onReopen: () {},
            onResolveConflict: () {},
          ),
        ),
      ),
    );

    expect(find.text('Actualizar servidor principal'), findsOneWidget);
    expect(find.text('Programación'), findsOneWidget);
    await tester.tap(find.text('Completar'));
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
