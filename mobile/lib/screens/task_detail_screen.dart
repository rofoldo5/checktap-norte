import 'dart:async';

import 'package:flutter/material.dart';

import '../core/task_permissions.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../models/task_checklist.dart';
import '../models/task_item.dart';
import '../services/background_sync.dart';
import '../services/session_store.dart';
import '../ui/components/section_header.dart';
import '../ui/components/task_badges.dart';
import '../ui/components/task_checklist_card.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import '../widgets/checklist_form_dialog.dart';
import '../widgets/task_form_dialog.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    required this.session,
    required this.task,
    required this.users,
    required this.departments,
    super.key,
  });

  final SessionStore session;
  final TaskItem task;
  final List<AppUser> users;
  final List<DepartmentSummary> departments;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TaskRepository _repository;
  late TaskItem _task;
  bool _busy = false;
  bool _changed = false;
  final Set<String> _hideCompletedChecklistIds = <String>{};

  AppUser get _currentUser => widget.session.user!;

  @override
  void initState() {
    super.initState();
    _repository = TaskRepository(widget.session.apiClient);
    _task = widget.task;
  }

  Future<void> _run(Future<TaskItem> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _task = updated;
        _changed = true;
      });
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_repository.synchronizePending());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit() async {
    final availableDepartments = <DepartmentSummary>[
      ...widget.departments.where((department) => department.isActive),
    ];
    if (!availableDepartments.any(
      (department) => department.id == _task.department.id,
    )) {
      availableDepartments.add(_task.department);
    }

    TaskItem? updatedTask;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskFormDialog(
        dialogTitle: 'Editar tarea',
        submitLabel: 'Guardar cambios',
        departments: availableDepartments,
        users: widget.users,
        initialDepartmentId: _task.department.id,
        initialTitle: _task.title,
        initialDescription: _task.description ?? '',
        initialPriority: _task.priority,
        initialAssigneeIds: _task.assignees.map((user) => user.id).toSet(),
        errorMessage: _friendlyError,
        onSubmit: (value) async {
          updatedTask = await _repository.updateTask(
            task: _task,
            title: value.title,
            description: value.description,
            priority: value.priority,
            department: value.department,
            assignees: value.assignees,
          );
        },
      ),
    );

    if (saved == true && updatedTask != null && mounted) {
      setState(() {
        _task = updatedTask!;
        _changed = true;
      });
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_repository.synchronizePending());
    }
  }

  Future<void> _createChecklist() async {
    if (_busy || _task.status == 'COMPLETADA') {
      return;
    }
    final draft = await showDialog<ChecklistDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChecklistFormDialog(),
    );
    if (draft == null || !mounted) {
      return;
    }
    await _run(
      () => _repository.createChecklist(
        task: _task,
        currentUser: _currentUser,
        title: draft.title,
        initialItemTitles: draft.itemTitles,
      ),
    );
  }

  Future<String?> _requestText({
    required String title,
    required String label,
    required String submitLabel,
    String initialValue = '',
    int maxLength = 300,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChecklistTextDialog(
        title: title,
        label: label,
        submitLabel: submitLabel,
        initialValue: initialValue,
        maxLength: maxLength,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _editChecklist(TaskChecklist checklist) async {
    final value = await _requestText(
      title: 'Editar checklist',
      label: 'Nombre del checklist',
      submitLabel: 'Guardar',
      initialValue: checklist.title,
      maxLength: 180,
    );
    if (value == null) {
      return;
    }
    await _run(
      () => _repository.updateChecklistTitle(
        task: _task,
        checklistId: checklist.id,
        title: value,
      ),
    );
  }

  Future<void> _deleteChecklist(TaskChecklist checklist) async {
    final confirmed = await _confirm(
      title: 'Eliminar checklist',
      message:
          'Se eliminarán "${checklist.title}" y todas sus actividades. '
          'Esta acción se sincronizará con el equipo.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => _repository.deleteChecklist(task: _task, checklistId: checklist.id),
    );
  }

  Future<void> _addChecklistItem(TaskChecklist checklist) async {
    final value = await _requestText(
      title: 'Nueva actividad',
      label: 'Actividad verificable',
      submitLabel: 'Agregar',
    );
    if (value == null) {
      return;
    }
    await _run(
      () => _repository.addChecklistItem(
        task: _task,
        checklistId: checklist.id,
        currentUser: _currentUser,
        title: value,
      ),
    );
  }

  Future<void> _editChecklistItem(
    TaskChecklist checklist,
    TaskChecklistItem item,
  ) async {
    final value = await _requestText(
      title: 'Editar actividad',
      label: 'Actividad',
      submitLabel: 'Guardar',
      initialValue: item.title,
    );
    if (value == null) {
      return;
    }
    await _run(
      () => _repository.updateChecklistItemTitle(
        task: _task,
        checklistId: checklist.id,
        itemId: item.id,
        title: value,
      ),
    );
  }

  Future<void> _deleteChecklistItem(
    TaskChecklist checklist,
    TaskChecklistItem item,
  ) async {
    final confirmed = await _confirm(
      title: 'Eliminar actividad',
      message: '¿Deseas eliminar "${item.title}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => _repository.deleteChecklistItem(
        task: _task,
        checklistId: checklist.id,
        itemId: item.id,
      ),
    );
  }

  Future<void> _toggleChecklistItem(
    TaskChecklist checklist,
    TaskChecklistItem item,
    bool value,
  ) async {
    await _run(
      () => _repository.setChecklistItemCompleted(
        task: _task,
        checklistId: checklist.id,
        itemId: item.id,
        currentUser: _currentUser,
        isCompleted: value,
      ),
    );
  }

  Future<void> _toggleChecklist(TaskChecklist checklist, bool value) async {
    if (value) {
      final confirmed = await _confirm(
        title: 'Completar checklist',
        message:
            'Se marcarán como completadas todas las actividades pendientes '
            'de "${checklist.title}".',
        confirmLabel: 'Completar todas',
      );
      if (!confirmed) {
        return;
      }
    } else {
      final confirmed = await _confirm(
        title: 'Reabrir checklist',
        message:
            'Todas las actividades de "${checklist.title}" volverán a '
            'estado pendiente.',
        confirmLabel: 'Reabrir todas',
      );
      if (!confirmed) {
        return;
      }
    }
    await _run(
      () => _repository.setChecklistCompleted(
        task: _task,
        checklistId: checklist.id,
        currentUser: _currentUser,
        isCompleted: value,
      ),
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('FormatException: ', '');
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'No registrado';
    }
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditTask(_currentUser, _task);
    final canWork = canWorkTask(_currentUser, _task);
    final canReopen = canReopenTask(_currentUser, _task);
    final contentBottomPadding =
        MediaQuery.textScalerOf(context).scale(14) >= 19 ? 190.0 : 130.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de tarea'),
          actions: <Widget>[
            if (canEdit)
              IconButton(
                tooltip: 'Editar tarea',
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        bottomNavigationBar: _TaskActionBar(
          busy: _busy,
          task: _task,
          canWork: canWork,
          canReopen: canReopen,
          onStart: () => _run(() => _repository.startTask(_task)),
          onComplete: () =>
              _run(() => _repository.completeTask(_task, _currentUser)),
          onReopen: () => _run(() => _repository.reopenTask(_task)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                CheckTapSpacing.md,
                CheckTapSpacing.sm,
                CheckTapSpacing.md,
                contentBottomPadding,
              ),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(CheckTapSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(CheckTapRadius.xl),
                    border: Border.all(color: CheckTapColors.border),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: CheckTapColors.navy.withValues(alpha: 0.045),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: CheckTapSpacing.xs,
                        runSpacing: CheckTapSpacing.xs,
                        children: <Widget>[
                          PriorityBadge(priority: _task.priority),
                          StatusChip(status: _task.status),
                        ],
                      ),
                      const SizedBox(height: CheckTapSpacing.md),
                      Text(
                        _task.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: CheckTapSpacing.sm),
                      Text(
                        _task.description?.trim().isNotEmpty == true
                            ? _task.description!
                            : 'Sin descripción',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: CheckTapColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.xl),
                const SectionHeader(title: 'Información'),
                const SizedBox(height: CheckTapSpacing.sm),
                _InfoCard(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.apartment_rounded,
                      label: 'Departamento',
                      value: _task.department.name,
                    ),
                    _InfoRow(
                      icon: Icons.groups_2_outlined,
                      label: 'Responsables',
                      customValue: _task.assignees.isEmpty
                          ? const Text('Todo el equipo')
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _task.assignees
                                  .map(
                                    (user) => Chip(
                                      avatar: UserAvatar.fromUser(
                                        user,
                                        radius: 12,
                                      ),
                                      label: Text(user.name),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Creada por',
                      value: _task.createdBy.name,
                    ),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Completada por',
                      value: _task.completedBy?.name ?? 'No completada',
                    ),
                    _InfoRow(
                      icon: Icons.cloud_done_outlined,
                      label: 'Sincronización',
                      value: _task.syncState.name.toUpperCase(),
                    ),
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'Versión',
                      value: '${_task.version}',
                      showDivider: false,
                    ),
                  ],
                ),
                if (_task.syncError != null) ...<Widget>[
                  const SizedBox(height: CheckTapSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(CheckTapSpacing.md),
                    decoration: BoxDecoration(
                      color: CheckTapColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(CheckTapRadius.md),
                      border: Border.all(
                        color: CheckTapColors.danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline_rounded,
                          color: CheckTapColors.danger,
                        ),
                        const SizedBox(width: CheckTapSpacing.sm),
                        Expanded(
                          child: Text(
                            _task.syncError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CheckTapColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: CheckTapSpacing.xl),
                SectionHeader(
                  title: 'Checklists',
                  actionLabel: canWork && _task.status != 'COMPLETADA'
                      ? 'Agregar'
                      : null,
                  onAction: canWork && _task.status != 'COMPLETADA'
                      ? _createChecklist
                      : null,
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                if (_task.checklists.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(CheckTapSpacing.lg),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(CheckTapRadius.lg),
                      border: Border.all(color: CheckTapColors.border),
                    ),
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.playlist_add_check_circle_outlined,
                          size: 42,
                          color: CheckTapColors.primary,
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        Text(
                          'Divide la tarea en actividades verificables.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cada integrante podrá marcar lo que completó y el equipo '
                          'verá el avance.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: CheckTapColors.textMuted),
                        ),
                        if (canWork &&
                            _task.status != 'COMPLETADA') ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.md),
                          FilledButton.icon(
                            onPressed: _busy ? null : _createChecklist,
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Crear checklist'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ..._task.checklists.map(
                    (checklist) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: CheckTapSpacing.md,
                      ),
                      child: TaskChecklistCard(
                        checklist: checklist,
                        enabled:
                            canWork && _task.status != 'COMPLETADA' && !_busy,
                        hideCompleted: _hideCompletedChecklistIds.contains(
                          checklist.id,
                        ),
                        onToggleHideCompleted: () {
                          setState(() {
                            if (!_hideCompletedChecklistIds.add(checklist.id)) {
                              _hideCompletedChecklistIds.remove(checklist.id);
                            }
                          });
                        },
                        onToggleChecklist: (value) =>
                            _toggleChecklist(checklist, value),
                        onToggleItem: (item, value) =>
                            _toggleChecklistItem(checklist, item, value),
                        onAddItem: () => _addChecklistItem(checklist),
                        onEditChecklist: () => _editChecklist(checklist),
                        onDeleteChecklist: () => _deleteChecklist(checklist),
                        onEditItem: (item) =>
                            _editChecklistItem(checklist, item),
                        onDeleteItem: (item) =>
                            _deleteChecklistItem(checklist, item),
                        formatDate: _formatDate,
                      ),
                    ),
                  ),
                if (_task.checklists.isNotEmpty &&
                    _task.checklists.every(
                      (checklist) => checklist.isCompleted,
                    ) &&
                    _task.status != 'COMPLETADA') ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(CheckTapSpacing.md),
                    decoration: BoxDecoration(
                      color: CheckTapColors.success.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(CheckTapRadius.md),
                      border: Border.all(
                        color: CheckTapColors.success.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.verified_rounded,
                          color: CheckTapColors.success,
                        ),
                        SizedBox(width: CheckTapSpacing.sm),
                        Expanded(
                          child: Text(
                            'Todos los checklists están completos. La tarea '
                            'principal seguirá abierta hasta que la completes.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CheckTapSpacing.md),
                ],
                const SizedBox(height: CheckTapSpacing.xl),
                const SectionHeader(title: 'Historial'),
                const SizedBox(height: CheckTapSpacing.sm),
                _Timeline(
                  task: _task,
                  createdAt: _formatDate(_task.createdAt),
                  updatedAt: _formatDate(_task.updatedAt),
                  completedAt: _formatDate(_task.completedAt),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        border: Border.all(color: CheckTapColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.customValue,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? customValue;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final valueWidget =
        customValue ??
        Text(
          value ?? '',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        );
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CheckTapSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 390 ||
                  MediaQuery.textScalerOf(context).scale(14) >= 19;
              final iconBox = Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(CheckTapRadius.sm),
                ),
                child: Icon(icon, color: CheckTapColors.primary, size: 19),
              );
              final labelWidget = Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CheckTapColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              );
              if (stacked) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    iconBox,
                    const SizedBox(width: CheckTapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          labelWidget,
                          const SizedBox(height: 4),
                          valueWidget,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  iconBox,
                  const SizedBox(width: CheckTapSpacing.sm),
                  SizedBox(width: 112, child: labelWidget),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: valueWidget,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.task,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  });

  final TaskItem task;
  final String createdAt;
  final String updatedAt;
  final String completedAt;

  @override
  Widget build(BuildContext context) {
    final entries = <_TimelineEntry>[
      _TimelineEntry(
        title: '${task.createdBy.name} creó la tarea',
        date: createdAt,
        color: CheckTapColors.primary,
      ),
      if (task.updatedAt.isAfter(task.createdAt))
        _TimelineEntry(
          title: task.status == 'EN_PROGRESO'
              ? '${task.assigneeLabel} inició la tarea'
              : 'La tarea fue actualizada',
          date: updatedAt,
          color: CheckTapColors.info,
        ),
      if (task.completedBy != null)
        _TimelineEntry(
          title: '${task.completedBy!.name} completó la tarea',
          date: completedAt,
          color: CheckTapColors.success,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        border: Border.all(color: CheckTapColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < entries.length; index++)
            _TimelineTile(
              entry: entries[index],
              first: index == 0,
              last: index == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.title,
    required this.date,
    required this.color,
  });

  final String title;
  final String date;
  final Color color;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.first,
    required this.last,
  });

  final _TimelineEntry entry;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    width: 2,
                    color: first
                        ? Colors.transparent
                        : CheckTapColors.borderStrong,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last
                        ? Colors.transparent
                        : CheckTapColors.borderStrong,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: CheckTapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CheckTapColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskActionBar extends StatelessWidget {
  const _TaskActionBar({
    required this.busy,
    required this.task,
    required this.canWork,
    required this.canReopen,
    required this.onStart,
    required this.onComplete,
    required this.onReopen,
  });

  final bool busy;
  final TaskItem task;
  final bool canWork;
  final bool canReopen;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final visible =
        (task.status == 'PENDIENTE' && canWork) ||
        (task.status != 'COMPLETADA' && canWork) ||
        (task.status == 'COMPLETADA' && canReopen);
    if (!visible) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(top: BorderSide(color: CheckTapColors.border)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: CheckTapColors.navy.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    constraints.maxWidth < 430 ||
                    MediaQuery.textScalerOf(context).scale(14) >= 19;
                final actions = <Widget>[
                  if (task.status == 'PENDIENTE' && canWork)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Iniciar'),
                    ),
                  if (task.status != 'COMPLETADA' && canWork)
                    FilledButton.icon(
                      onPressed: busy ? null : onComplete,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Marcar como completada'),
                    ),
                  if (task.status == 'COMPLETADA' && canReopen)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onReopen,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reabrir tarea'),
                    ),
                ];
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (var index = 0; index < actions.length; index++) ...[
                        actions[index],
                        if (index < actions.length - 1)
                          const SizedBox(height: CheckTapSpacing.xs),
                      ],
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    for (var index = 0; index < actions.length; index++) ...[
                      Expanded(
                        flex: index == actions.length - 1 ? 2 : 1,
                        child: actions[index],
                      ),
                      if (index < actions.length - 1)
                        const SizedBox(width: CheckTapSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
