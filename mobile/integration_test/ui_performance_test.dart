import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/department.dart';
import 'package:checktap/models/task_item.dart';
import 'package:checktap/ui/components/task_card.dart';
import 'package:checktap/ui/theme/checktap_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desplazamiento de 120 tareas mantiene renderizado estable', (
    tester,
  ) async {
    const user = AppUser(
      id: 'user',
      name: 'Usuario de prueba',
      email: 'user@example.com',
    );
    const department = DepartmentSummary(
      id: 'department',
      name: 'Programación',
    );
    final tasks = List<TaskItem>.generate(
      120,
      (index) => TaskItem(
        id: 'task-$index',
        title: 'Tarea de rendimiento $index',
        description:
            'Elemento de prueba para medir desplazamiento y rasterizado.',
        status: index.isEven ? 'PENDIENTE' : 'EN_PROGRESO',
        priority: index % 3 == 0 ? 'ALTA' : 'MEDIA',
        department: department,
        createdBy: user,
        assignees: const <AppUser>[user],
        createdAt: DateTime.utc(2026, 8, 6),
        updatedAt: DateTime.utc(2026, 8, 6),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CheckTapTheme.light,
        home: Scaffold(
          body: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.all(8),
              child: CheckTapTaskCard(
                task: tasks[index],
                canEdit: true,
                canWork: true,
                canReopen: false,
                onOpen: () {},
                onStart: () {},
                onComplete: () {},
                onReopen: () {},
                onResolveConflict: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await binding.traceAction(() async {
      await tester.fling(find.byType(ListView), const Offset(0, -2400), 5200);
      await tester.pumpAndSettle();
    }, reportKey: 'task_list_scroll');
  });
}
