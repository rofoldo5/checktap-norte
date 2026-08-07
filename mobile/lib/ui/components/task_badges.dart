import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    required this.priority,
    this.compact = false,
    super.key,
  });

  final String priority;
  final bool compact;

  Color get _color => switch (priority.toUpperCase()) {
    'ALTA' => CheckTapColors.danger,
    'MEDIA' => CheckTapColors.warning,
    _ => CheckTapColors.info,
  };

  String get _label => switch (priority.toUpperCase()) {
    'ALTA' => 'Alta',
    'MEDIA' => 'Media',
    _ => 'Baja',
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      label: 'Prioridad $_label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(CheckTapRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, this.compact = false, super.key});

  final String status;
  final bool compact;

  Color get _color => switch (status.toUpperCase()) {
    'COMPLETADA' => CheckTapColors.success,
    'EN_PROGRESO' => CheckTapColors.info,
    _ => CheckTapColors.warning,
  };

  String get _label => switch (status.toUpperCase()) {
    'COMPLETADA' => 'Completada',
    'EN_PROGRESO' => 'En curso',
    _ => 'Pendiente',
  };

  IconData get _icon => switch (status.toUpperCase()) {
    'COMPLETADA' => Icons.check_circle_outline_rounded,
    'EN_PROGRESO' => Icons.play_circle_outline_rounded,
    _ => Icons.schedule_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      label: 'Estado $_label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(CheckTapRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_icon, size: compact ? 13 : 15, color: color),
            const SizedBox(width: 5),
            Text(
              _label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncStateBadge extends StatelessWidget {
  const SyncStateBadge({required this.state, super.key});

  final LocalSyncState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      LocalSyncState.synced => (
        Icons.cloud_done_outlined,
        'Sincronizada',
        CheckTapColors.success,
      ),
      LocalSyncState.pending => (
        Icons.schedule_rounded,
        'Pendiente',
        CheckTapColors.warning,
      ),
      LocalSyncState.syncing => (
        Icons.sync_rounded,
        'Sincronizando',
        CheckTapColors.info,
      ),
      LocalSyncState.error => (
        Icons.error_outline_rounded,
        'Error',
        CheckTapColors.danger,
      ),
      LocalSyncState.conflict => (
        Icons.warning_amber_rounded,
        'Conflicto',
        CheckTapColors.danger,
      ),
    };

    return Semantics(
      label: 'Sincronización $label',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          );

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              if (constraints.hasBoundedWidth)
                Flexible(child: labelText)
              else
                labelText,
            ],
          );
        },
      ),
    );
  }
}
