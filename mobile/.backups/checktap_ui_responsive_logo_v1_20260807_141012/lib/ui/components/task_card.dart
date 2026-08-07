import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';
import 'task_badges.dart';
import 'user_avatar.dart';

class CheckTapTaskCard extends StatelessWidget {
  const CheckTapTaskCard({
    required this.task,
    required this.canEdit,
    required this.canWork,
    required this.canReopen,
    required this.onOpen,
    required this.onStart,
    required this.onComplete,
    required this.onReopen,
    required this.onResolveConflict,
    this.compact = false,
    super.key,
  });

  final TaskItem task;
  final bool canEdit;
  final bool canWork;
  final bool canReopen;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onResolveConflict;
  final bool compact;

  Color get _priorityColor => switch (task.priority.toUpperCase()) {
    'ALTA' => CheckTapColors.danger,
    'MEDIA' => CheckTapColors.warning,
    _ => CheckTapColors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    final completed = task.status == 'COMPLETADA';
    final padding = compact ? CheckTapSpacing.sm : CheckTapSpacing.md;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label:
            '${task.title}. ${task.department.name}. ${task.status.replaceAll('_', ' ')}. Prioridad ${task.priority}.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(CheckTapRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(CheckTapRadius.lg),
                border: Border.all(color: CheckTapColors.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: CheckTapColors.navy.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: _priorityColor,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(CheckTapRadius.lg),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      padding + 5,
                      padding,
                      padding,
                      padding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: CheckTapColors.textMuted,
                                    ),
                              ),
                            ),
                            const SizedBox(width: CheckTapSpacing.xs),
                            PriorityBadge(
                              priority: task.priority,
                              compact: true,
                            ),
                          ],
                        ),
                        if (!compact &&
                            task.description?.trim().isNotEmpty ==
                                true) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.xs),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: CheckTapColors.textMuted),
                          ),
                        ],
                        const SizedBox(height: CheckTapSpacing.sm),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.apartment_rounded,
                              size: 16,
                              color: CheckTapColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                task.department.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: CheckTapColors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: task.status, compact: true),
                          ],
                        ),
                        if (task.checklists.isNotEmpty) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.sm),
                          _ChecklistProgress(task: task),
                        ],
                        const SizedBox(height: CheckTapSpacing.sm),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: UserAvatarStack(
                                users: task.assignees,
                                maxVisible: 3,
                                radius: 13,
                              ),
                            ),
                            const SizedBox(width: CheckTapSpacing.xs),
                            SyncStateBadge(state: task.syncState),
                          ],
                        ),
                        if (task.syncError != null) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.xs),
                          Text(
                            task.syncError!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CheckTapColors.danger),
                          ),
                        ],
                        if (!compact) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.sm),
                          _Actions(
                            task: task,
                            canEdit: canEdit,
                            canWork: canWork,
                            canReopen: canReopen,
                            onOpen: onOpen,
                            onStart: onStart,
                            onComplete: onComplete,
                            onReopen: onReopen,
                            onResolveConflict: onResolveConflict,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistProgress extends StatelessWidget {
  const _ChecklistProgress({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final total = task.checklists.fold<int>(
      0,
      (sum, checklist) => sum + checklist.itemCount,
    );
    final completed = task.checklists.fold<int>(
      0,
      (sum, checklist) => sum + checklist.completedCount,
    );
    final progress = total == 0 ? 0.0 : completed / total;
    return Row(
      children: <Widget>[
        const Icon(
          Icons.checklist_rounded,
          size: 16,
          color: CheckTapColors.primary,
        ),
        const SizedBox(width: 6),
        Text(
          total == 0
              ? '${task.checklists.length} checklist(s)'
              : '$completed de $total actividades',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CheckTapColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: CheckTapColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                CheckTapColors.success,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.task,
    required this.canEdit,
    required this.canWork,
    required this.canReopen,
    required this.onOpen,
    required this.onStart,
    required this.onComplete,
    required this.onReopen,
    required this.onResolveConflict,
  });

  final TaskItem task;
  final bool canEdit;
  final bool canWork;
  final bool canReopen;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onResolveConflict;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == 'COMPLETADA';
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        TextButton.icon(
          onPressed: onOpen,
          icon: Icon(canEdit ? Icons.edit_outlined : Icons.visibility_outlined),
          label: Text(canEdit ? 'Ver y editar' : 'Ver detalle'),
        ),
        if (task.syncState == LocalSyncState.conflict)
          IconButton(
            tooltip: 'Aceptar versión del servidor',
            onPressed: onResolveConflict,
            icon: const Icon(Icons.rule_rounded),
          ),
        if (task.status == 'PENDIENTE' && canWork)
          IconButton(
            tooltip: 'Iniciar tarea',
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        if (!completed && canWork)
          FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Completar'),
          ),
        if (completed && canReopen)
          OutlinedButton.icon(
            onPressed: onReopen,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reabrir'),
          ),
      ],
    );
  }
}
