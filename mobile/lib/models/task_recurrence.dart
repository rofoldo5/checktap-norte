class TaskRecurrence {
  const TaskRecurrence({
    this.type = 'NONE',
    this.interval = 1,
    this.unit,
    this.startAt,
    this.timezone = 'UTC',
    this.nextOccurrenceAt,
    this.notificationsEnabled = false,
    this.reminderMinutesBefore = 0,
    this.seriesId,
    this.isMaster = false,
    this.scheduledFor,
  });

  static const TaskRecurrence none = TaskRecurrence();

  final String type;
  final int interval;
  final String? unit;
  final DateTime? startAt;
  final String timezone;
  final DateTime? nextOccurrenceAt;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;
  final String? seriesId;
  final bool isMaster;
  final DateTime? scheduledFor;

  bool get isRecurring => type != 'NONE';
  bool get canEditSchedule => !isRecurring || isMaster;

  String get label {
    switch (type) {
      case 'DAILY':
        return 'Todos los días';
      case 'WEEKLY':
        return 'Cada semana';
      case 'MONTHLY':
        return 'Cada mes';
      case 'CUSTOM':
        return 'Cada $interval ${_unitLabel(interval)}';
      default:
        return 'No se repite';
    }
  }

  String get reminderLabel {
    if (!notificationsEnabled) {
      return 'Desactivados';
    }
    switch (reminderMinutesBefore) {
      case 0:
        return 'A la hora programada';
      case 15:
        return '15 min antes';
      case 60:
        return '1 hora antes';
      case 1440:
        return '1 día antes';
      default:
        if (reminderMinutesBefore % 1440 == 0) {
          return '${reminderMinutesBefore ~/ 1440} días antes';
        }
        if (reminderMinutesBefore % 60 == 0) {
          return '${reminderMinutesBefore ~/ 60} horas antes';
        }
        return '$reminderMinutesBefore min antes';
    }
  }

  String _unitLabel(int value) {
    switch (unit) {
      case 'WEEKS':
        return value == 1 ? 'semana' : 'semanas';
      case 'MONTHS':
        return value == 1 ? 'mes' : 'meses';
      default:
        return value == 1 ? 'día' : 'días';
    }
  }

  factory TaskRecurrence.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key]?.toString();
      if (value == null || value.isEmpty) {
        return null;
      }
      return DateTime.tryParse(value);
    }

    return TaskRecurrence(
      type: json['recurrence_type']?.toString() ?? 'NONE',
      interval: (json['recurrence_interval'] as num?)?.toInt() ?? 1,
      unit: json['recurrence_unit']?.toString(),
      startAt: parseDate('recurrence_start_at'),
      timezone: json['recurrence_timezone']?.toString() ?? 'UTC',
      nextOccurrenceAt: parseDate('next_occurrence_at'),
      notificationsEnabled: json['notifications_enabled'] == true,
      reminderMinutesBefore:
          (json['reminder_minutes_before'] as num?)?.toInt() ?? 0,
      seriesId: json['recurrence_series_id']?.toString(),
      isMaster: json['is_recurrence_master'] == true,
      scheduledFor: parseDate('scheduled_for'),
    );
  }

  Map<String, dynamic> toApiJson() {
    return <String, dynamic>{
      'recurrence_type': type,
      'recurrence_interval': interval,
      'recurrence_unit': unit,
      'recurrence_start_at': startAt?.toUtc().toIso8601String(),
      'recurrence_timezone': timezone,
      'notifications_enabled': isRecurring && notificationsEnabled,
      'reminder_minutes_before': isRecurring ? reminderMinutesBefore : 0,
    };
  }

  Map<String, dynamic> toStorageJson() {
    return <String, dynamic>{
      ...toApiJson(),
      'next_occurrence_at': nextOccurrenceAt?.toUtc().toIso8601String(),
      'recurrence_series_id': seriesId,
      'is_recurrence_master': isMaster,
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
    };
  }
}
