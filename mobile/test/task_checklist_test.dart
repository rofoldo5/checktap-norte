import 'package:checktap/models/app_user.dart';
import 'package:checktap/models/task_checklist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(id: 'u1', name: 'María', email: 'maria@example.com');

  test('calcula progreso y estado parcial del checklist', () {
    final now = DateTime.utc(2026, 8, 6, 14);
    final checklist = TaskChecklist(
      id: 'c1',
      title: 'Preparación',
      position: 0,
      version: 1,
      createdBy: user,
      createdAt: now,
      updatedAt: now,
      items: <TaskChecklistItem>[
        TaskChecklistItem(
          id: 'i1',
          title: 'Respaldar',
          position: 0,
          isCompleted: true,
          version: 1,
          createdBy: user,
          completedBy: user,
          createdAt: now,
          updatedAt: now,
          completedAt: now,
        ),
        TaskChecklistItem(
          id: 'i2',
          title: 'Validar',
          position: 1,
          isCompleted: false,
          version: 1,
          createdBy: user,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(checklist.itemCount, 2);
    expect(checklist.completedCount, 1);
    expect(checklist.isPartiallyCompleted, isTrue);
    expect(checklist.isCompleted, isFalse);
    expect(checklist.progress, 0.5);
  });

  test('serializa y restaura autor y responsable', () {
    final now = DateTime.utc(2026, 8, 6, 14);
    final original = TaskChecklist(
      id: 'c1',
      title: 'Preparación',
      position: 0,
      version: 2,
      createdBy: user,
      createdAt: now,
      updatedAt: now,
      items: <TaskChecklistItem>[
        TaskChecklistItem(
          id: 'i1',
          title: 'Respaldar',
          position: 0,
          isCompleted: true,
          version: 2,
          createdBy: user,
          completedBy: user,
          createdAt: now,
          updatedAt: now,
          completedAt: now,
        ),
      ],
    );

    final restored = TaskChecklist.fromJson(original.toJson());
    expect(restored.isCompleted, isTrue);
    expect(restored.items.single.completedBy?.name, 'María');
  });
}
