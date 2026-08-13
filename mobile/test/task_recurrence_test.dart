import 'package:flutter_test/flutter_test.dart';

import 'package:checktap/models/task_recurrence.dart';

void main() {
  test('recurrencia quincenal conserva configuracion y recordatorio', () {
    final recurrence = TaskRecurrence.fromJson(<String, dynamic>{
      'recurrence_type': 'CUSTOM',
      'recurrence_interval': 15,
      'recurrence_unit': 'DAYS',
      'recurrence_start_at': '2026-08-15T12:00:00Z',
      'recurrence_timezone': 'America/Santo_Domingo',
      'notifications_enabled': true,
      'reminder_minutes_before': 60,
      'recurrence_series_id': 'series-1',
      'is_recurrence_master': true,
      'scheduled_for': '2026-08-15T12:00:00Z',
    });

    expect(recurrence.isRecurring, isTrue);
    expect(recurrence.canEditSchedule, isTrue);
    expect(recurrence.label, 'Cada 15 días');
    expect(recurrence.reminderLabel, '1 hora antes');
    expect(recurrence.timezone, 'America/Santo_Domingo');
    expect(recurrence.toApiJson(), containsPair('recurrence_interval', 15));
  });

  test(
    'una ocurrencia generada conserva la programacion como solo lectura',
    () {
      final recurrence = TaskRecurrence.fromJson(<String, dynamic>{
        'recurrence_type': 'MONTHLY',
        'recurrence_interval': 1,
        'recurrence_timezone': 'UTC',
        'recurrence_start_at': '2026-08-31T14:00:00Z',
        'recurrence_series_id': 'master-1',
        'is_recurrence_master': false,
        'scheduled_for': '2026-09-30T14:00:00Z',
      });

      expect(recurrence.isRecurring, isTrue);
      expect(recurrence.isMaster, isFalse);
      expect(recurrence.canEditSchedule, isFalse);
      expect(recurrence.label, 'Cada mes');
    },
  );
}
