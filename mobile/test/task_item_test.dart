import 'package:flutter_test/flutter_test.dart';
import 'package:checktap/models/task_item.dart';

void main() {
  test('TaskItem parses users and status', () {
    final task = TaskItem.fromJson(<String, dynamic>{
      'id': 'task-1',
      'title': 'Revisar inventario',
      'description': 'Validar productos',
      'status': 'PENDIENTE',
      'priority': 'ALTA',
      'created_by': <String, dynamic>{
        'id': 'user-1',
        'name': 'Ana',
        'email': 'ana@example.com',
      },
      'assigned_to': <String, dynamic>{
        'id': 'user-2',
        'name': 'Carlos',
        'email': 'carlos@example.com',
      },
      'completed_by': null,
      'created_at': '2026-07-31T12:00:00Z',
      'completed_at': null,
    });

    expect(task.title, 'Revisar inventario');
    expect(task.status, 'PENDIENTE');
    expect(task.assignedTo?.name, 'Carlos');
    expect(task.completedBy, isNull);
  });
}
