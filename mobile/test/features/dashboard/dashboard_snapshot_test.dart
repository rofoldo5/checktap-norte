import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/department.dart';
import 'package:checktap/models/task_item.dart';

void main() {
  const creator = AppUser(
    id: 'creator',
    name: 'Rafael',
    email: 'rafael@example.com',
  );
  const assignee = AppUser(
    id: 'assignee',
    name: 'María',
    email: 'maria@example.com',
  );
  const department = DepartmentSummary(id: 'department', name: 'Programación');
  final now = DateTime.utc(2026, 8, 6, 12);

  TaskItem task({
    required String id,
    required String status,
    required String priority,
    DateTime? completedAt,
  }) {
    return TaskItem(
      id: id,
      title: 'Tarea $id',
      status: status,
      priority: priority,
      createdBy: creator,
      assignees: const <AppUser>[assignee],
      department: department,
      completedBy: completedAt == null ? null : assignee,
      completedAt: completedAt,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now,
    );
  }

  test('calcula métricas y atención sin duplicar tareas', () {
    final snapshot = DashboardSnapshot.fromTasks(<TaskItem>[
      task(id: '1', status: 'PENDIENTE', priority: 'ALTA'),
      task(id: '2', status: 'EN_PROGRESO', priority: 'MEDIA'),
      task(id: '3', status: 'COMPLETADA', priority: 'ALTA', completedAt: now),
    ]);

    expect(snapshot.pending, 1);
    expect(snapshot.inProgress, 1);
    expect(snapshot.completed, 1);
    expect(snapshot.highPriority, 1);
    expect(snapshot.attentionTasks.map((item) => item.id), <String>['1', '2']);
    expect(snapshot.activity, hasLength(3));
    expect(snapshot.activity.first.action, 'completó');
  });
}
