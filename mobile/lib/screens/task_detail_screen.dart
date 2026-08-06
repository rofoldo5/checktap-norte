import 'dart:async';

import 'package:flutter/material.dart';

import '../core/task_permissions.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../models/task_item.dart';
import '../services/background_sync.dart';
import '../services/session_store.dart';
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
        submitLabel: 'Guardar',
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
                tooltip: 'Editar',
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(_task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(_task.description ?? 'Sin descripcion'),
            const SizedBox(height: 20),
            _DetailRow(
              label: 'Estado',
              value: _task.status.replaceAll('_', ' '),
            ),
            _DetailRow(label: 'Prioridad', value: _task.priority),
            _DetailRow(label: 'Version', value: '${_task.version}'),
            _DetailRow(label: 'Creador', value: _task.createdBy.name),
            _DetailRow(label: 'Departamento', value: _task.department.name),
            _DetailRow(label: 'Responsables', value: _task.assigneeLabel),
            _DetailRow(
              label: 'Completada por',
              value: _task.completedBy?.name ?? 'No completada',
            ),
            _DetailRow(label: 'Creada', value: _formatDate(_task.createdAt)),
            _DetailRow(
              label: 'Actualizada',
              value: _formatDate(_task.updatedAt),
            ),
            _DetailRow(
              label: 'Completada',
              value: _formatDate(_task.completedAt),
            ),
            _DetailRow(
              label: 'Sincronizacion',
              value: _task.syncState.name.toUpperCase(),
            ),
            if (_task.syncError != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _task.syncError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (_task.status == 'PENDIENTE' && canWork)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _repository.startTask(_task)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  ),
                if (_task.status != 'COMPLETADA' && canWork)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _repository.completeTask(_task, _currentUser),
                          ),
                    icon: const Icon(Icons.check),
                    label: const Text('Completar'),
                  ),
                if (_task.status == 'COMPLETADA' && canReopen)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _repository.reopenTask(_task)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reabrir'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 125,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
