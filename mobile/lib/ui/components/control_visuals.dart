import 'package:flutter/material.dart';

import '../../models/control_item.dart';
import '../theme/checktap_colors.dart';

IconData controlSectionIcon(String key) {
  switch (key) {
    case 'globe':
      return Icons.public_rounded;
    case 'server':
      return Icons.dns_rounded;
    case 'daily':
      return Icons.today_rounded;
    case 'maintenance':
      return Icons.handyman_rounded;
    case 'security':
      return Icons.security_rounded;
    case 'license':
      return Icons.badge_rounded;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'storage':
      return Icons.storage_rounded;
    case 'devices':
      return Icons.devices_other_rounded;
    default:
      return Icons.folder_open_rounded;
  }
}

Color controlDueColor(BuildContext context, String state) {
  switch (state) {
    case 'VENCIDA':
      return CheckTapColors.adaptAccent(context, CheckTapColors.danger);
    case 'URGENTE':
      return CheckTapColors.adaptAccent(context, CheckTapColors.warning);
    case 'PROXIMA':
      return CheckTapColors.cyanFor(context);
    case 'COMPLETADA':
      return CheckTapColors.tealFor(context);
    default:
      return CheckTapColors.primaryFor(context);
  }
}

String controlDueStateLabel(String state) {
  switch (state) {
    case 'VENCIDA':
      return 'Vencido';
    case 'URGENTE':
      return 'Urgente';
    case 'PROXIMA':
      return 'Pr\u00f3ximo';
    case 'COMPLETADA':
      return 'Completado';
    default:
      return 'Vigente';
  }
}

String controlPriorityLabel(String priority) {
  switch (priority) {
    case 'ALTA':
      return 'Alta';
    case 'BAJA':
      return 'Baja';
    default:
      return 'Media';
  }
}

String controlDueLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final locale = MaterialLocalizations.of(context);
  return '${locale.formatMediumDate(local)} \u00b7 '
      '${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String controlRelativeDueLabel(ControlCheckItem check) {
  if (check.isCompleted) {
    return 'Completado';
  }
  final now = DateTime.now();
  final due = check.dueAt.toLocal();
  final difference = due.difference(now);
  if (difference.isNegative) {
    final days = now.difference(due).inDays;
    if (days <= 0) {
      return 'Vencido hoy';
    }
    return days == 1 ? 'Vencido hace 1 d\u00eda' : 'Vencido hace $days d\u00edas';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours.clamp(0, 23);
    return hours <= 1 ? 'Vence en menos de 2 h' : 'Vence en $hours h';
  }
  final days = difference.inDays;
  return days == 1 ? 'Falta 1 d\u00eda' : 'Faltan $days d\u00edas';
}

String controlReminderLabel(int minutes) {
  if (minutes == 0) {
    return 'A la hora';
  }
  if (minutes % 10080 == 0) {
    final weeks = minutes ~/ 10080;
    return weeks == 1 ? '1 semana antes' : '$weeks semanas antes';
  }
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return days == 1 ? '1 d\u00eda antes' : '$days d\u00edas antes';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hora antes' : '$hours horas antes';
  }
  return '$minutes min antes';
}

DateTime? nextControlReminder(ControlCheckItem check) {
  if (check.isCompleted || check.reminderMinutes.isEmpty) {
    return null;
  }
  final now = DateTime.now().toUtc();
  DateTime? next;
  for (final minutes in check.reminderMinutes) {
    final candidate = check.dueAt.toUtc().subtract(Duration(minutes: minutes));
    if (!candidate.isAfter(now)) {
      continue;
    }
    if (next == null || candidate.isBefore(next)) {
      next = candidate;
    }
  }
  return next;
}
