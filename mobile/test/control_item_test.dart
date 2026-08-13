import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/control_item.dart';

void main() {
  Map<String, dynamic> baseCheck() => <String, dynamic>{
    'id': 'check-1',
    'section_id': 'section-1',
    'section_name': 'Dominios',
    'title': 'Renovar example.com',
    'priority': 'ALTA',
    'status': 'PENDIENTE',
    'due_at': DateTime.now().toUtc().add(const Duration(days: 5)).toIso8601String(),
    'timezone': 'UTC',
    'reminder_minutes': <int>[43200, 10080, 1440],
    'recurrence_type': 'YEARLY',
    'recurrence_interval': 1,
    'recurrence_unit': null,
    'version': 1,
    'created_by': <String, dynamic>{
      'id': 'user-1',
      'name': 'Ana',
      'email': 'ana@example.com',
    },
    'assignees': <Map<String, dynamic>>[],
    'completed_by': null,
    'completed_at': null,
    'created_at': '2026-08-13T12:00:00Z',
    'updated_at': '2026-08-13T12:00:00Z',
    'history': <Map<String, dynamic>>[],
  };

  test('control conserva multiples recordatorios y recurrencia anual', () {
    final check = ControlCheckItem.fromJson(baseCheck());

    expect(check.sectionName, 'Dominios');
    expect(check.reminderMinutes, <int>[43200, 10080, 1440]);
    expect(check.isRecurring, isTrue);
    expect(check.recurrenceLabel, 'Anual');
    expect(check.dueState, 'URGENTE');
  });

  test('control completado siempre reporta estado completado', () {
    final payload = baseCheck()
      ..['status'] = 'COMPLETADA'
      ..['due_at'] = '2026-01-01T10:00:00Z';
    final check = ControlCheckItem.fromJson(payload);

    expect(check.isCompleted, isTrue);
    expect(check.dueState, 'COMPLETADA');
  });

  test('seccion parsea contadores de vencimiento', () {
    final section = ControlSectionItem.fromJson(<String, dynamic>{
      'id': 'section-1',
      'name': 'Servidores',
      'icon_key': 'server',
      'department': <String, dynamic>{
        'id': 'department-1',
        'name': 'Sistemas',
      },
      'created_by': <String, dynamic>{
        'id': 'user-1',
        'name': 'Ana',
        'email': 'ana@example.com',
      },
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-13T12:00:00Z',
      'updated_at': '2026-08-13T12:00:00Z',
      'check_count': 8,
      'upcoming_count': 3,
      'urgent_count': 1,
      'overdue_count': 2,
      'completed_count': 4,
    });

    expect(section.name, 'Servidores');
    expect(section.checkCount, 8);
    expect(section.overdueCount, 2);
  });
}
