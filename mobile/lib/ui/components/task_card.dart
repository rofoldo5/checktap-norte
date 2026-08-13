import 'package:flutter/material.dart';

import '../../models/app_user.dart';
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
            '${task.title}. ${task.department.name}. ${task.status.replaceAll('_', ' ')}. '
            'Prioridad ${task.priority}. ${task.recurrence.label}.',
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
                        _TitleAndPriority(
                          title: task.title,
                          priority: task.priority,
                          completed: completed,
                          compact: compact,
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
                        _DepartmentAndStatus(
                          department: task.department.name,
                          status: task.status,
                        ),
                        if (task.recurrence.isRecurring) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.xs),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.repeat_rounded,
                                size: 16,
                                color: CheckTapColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  task.recurrence.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: CheckTapColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              if (task.recurrence.notificationsEnabled)
                                const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                  color: CheckTapColors.textMuted,
                                ),
                            ],
                          ),
                        ],
                        if (task.checklists.isNotEmpty) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.sm),
                          _ChecklistProgress(task: task),
                        ],
                        const SizedBox(height: CheckTapSpacing.sm),
                        _AssigneesAndSync(
                          assignees: task.assignees,
                          syncState: task.syncState,
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

class _TitleAndPriority extends StatelessWidget {
  const _TitleAndPriority({
    required this.title,
    required this.priority,
    required this.completed,
    required this.compact,
  });

  final String title;
  final String priority;
  final bool completed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) >= 20;
        final titleLabel = Text(
          title,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            decoration: completed ? TextDecoration.lineThrough : null,
            decorationColor: CheckTapColors.textMuted,
          ),
        );
        final priorityBadge = PriorityBadge(priority: priority, compact: true);

        if (stackHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleLabel,
              const SizedBox(height: CheckTapSpacing.xs),
              priorityBadge,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: titleLabel),
            const SizedBox(width: CheckTapSpacing.xs),
            priorityBadge,
          ],
        );
      },
    );
  }
}

class _DepartmentAndStatus extends StatelessWidget {
  const _DepartmentAndStatus({required this.department, required this.status});

  final String department;
  final String status;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackDetails =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(12) >= 17;
        final departmentLabel = Row(
          children: <Widget>[
            const Icon(
              Icons.apartment_rounded,
              size: 16,
              color: CheckTapColors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                department,
                maxLines: stackDetails ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CheckTapColors.textMuted,
                ),
              ),
            ),
          ],
        );
        final statusChip = StatusChip(status: status, compact: true);

        if (stackDetails) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              departmentLabel,
              const SizedBox(height: CheckTapSpacing.xs),
              statusChip,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: departmentLabel),
            const SizedBox(width: CheckTapSpacing.sm),
            statusChip,
          ],
        );
      },
    );
  }
}

class _AssigneesAndSync extends StatelessWidget {
  const _AssigneesAndSync({required this.assignees, required this.syncState});

  final List<AppUser> assignees;
  final LocalSyncState syncState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackDetails =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(12) >= 17;
        final avatars = UserAvatarStack(
          users: assignees,
          maxVisible: 3,
          radius: 13,
        );
        final syncBadge = SyncStateBadge(state: syncState);

        if (stackDetails) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              avatars,
              const SizedBox(height: CheckTapSpacing.xs),
              syncBadge,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: avatars),
            const SizedBox(width: CheckTapSpacing.xs),
            syncBadge,
          ],
        );
      },
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
    final label = total == 0
        ? '${task.checklists.length} checklist(s)'
        : '$completed de $total actividades';
    final progressBar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 5,
        value: progress,
        backgroundColor: CheckTapColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(CheckTapColors.success),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackProgress =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) >= 17;
        final progressLabel = Row(
          children: <Widget>[
            const Icon(
              Icons.checklist_rounded,
              size: 16,
              color: CheckTapColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CheckTapColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
        if (stackProgress) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              progressLabel,
              const SizedBox(height: CheckTapSpacing.xs),
              progressBar,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(flex: 3, child: progressLabel),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: progressBar),
          ],
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) >= 20;

        if (stackActions) {
          final actions = <Widget>[
            TextButton(
              onPressed: onOpen,
              child: _ActionButtonLabel(
                icon: canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
                label: canEdit ? 'Ver y editar' : 'Ver detalle',
              ),
            ),
            if (task.syncState == LocalSyncState.conflict)
              OutlinedButton(
                onPressed: onResolveConflict,
                child: const _ActionButtonLabel(
                  icon: Icons.rule_rounded,
                  label: 'Aceptar versión del servidor',
                ),
              ),
            if (task.status == 'PENDIENTE' && canWork)
              OutlinedButton(
                onPressed: onStart,
                child: const _ActionButtonLabel(
                  icon: Icons.play_arrow_rounded,
                  label: 'Iniciar tarea',
                ),
              ),
            if (!completed && canWork)
              FilledButton(
                onPressed: onComplete,
                child: const _ActionButtonLabel(
                  icon: Icons.check_rounded,
                  label: 'Completar',
                ),
              ),
            if (completed && canReopen)
              OutlinedButton(
                onPressed: onReopen,
                child: const _ActionButtonLabel(
                  icon: Icons.refresh_rounded,
                  label: 'Reabrir',
                ),
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < actions.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(height: 6),
                actions[index],
              ],
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            TextButton.icon(
              onPressed: onOpen,
              icon: Icon(
                canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
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
      },
    );
  }
}

class _ActionButtonLabel extends StatelessWidget {
  const _ActionButtonLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: CheckTapSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
