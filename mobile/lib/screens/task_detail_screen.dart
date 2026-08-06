import 'dart:async';

import 'package:flutter/material.dart';

import '../core/task_permissions.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../models/task_item.dart';
import '../services/background_sync.dart';
import '../services/session_store.dart';

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

  DepartmentSummary? _departmentById(String id) {
    for (final department in widget.departments) {
      if (department.id == id) {
        return department;
      }
    }
    if (_task.department.id == id) {
      return _task.department;
    }
    return null;
  }

  List<AppUser> _usersForDepartment(String departmentId) {
    return widget.users
        .where(
          (user) => user.isActive && user.departmentIds.contains(departmentId),
        )
        .toList(growable: false);
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

    final titleController = TextEditingController(text: _task.title);
    final descriptionController = TextEditingController(
      text: _task.description ?? '',
    );
    var priority = _task.priority;
    var departmentId = _task.department.id;
    final selectedAssigneeIds = _task.assignees.map((user) => user.id).toSet();
    String? errorMessage;
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final departmentUsers = _usersForDepartment(departmentId);

            Future<void> save() async {
              final title = titleController.text.trim();
              if (title.length < 2) {
                setDialogState(
                  () => errorMessage = 'Ingrese un titulo valido.',
                );
                return;
              }
              final department = _departmentById(departmentId);
              if (department == null) {
                setDialogState(
                  () => errorMessage = 'Seleccione un departamento valido.',
                );
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                final assignees = departmentUsers
                    .where((user) => selectedAssigneeIds.contains(user.id))
                    .toList(growable: false);
                final updated = await _repository.updateTask(
                  task: _task,
                  title: titleController.text,
                  description: descriptionController.text,
                  priority: priority,
                  department: department,
                  assignees: assignees,
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                setState(() {
                  _task = updated;
                  _changed = true;
                });
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                    errorMessage = _friendlyError(error);
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Editar tarea'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: departmentId,
                        decoration: const InputDecoration(
                          labelText: 'Departamento',
                          helperText:
                              'El aviso llegara a todos los integrantes.',
                          border: OutlineInputBorder(),
                        ),
                        items: availableDepartments
                            .map(
                              (department) => DropdownMenuItem<String>(
                                value: department.id,
                                child: Text(department.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  departmentId = value;
                                  selectedAssigneeIds.removeWhere(
                                    (id) => !_usersForDepartment(value)
                                        .any((user) => user.id == id),
                                  );
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        enabled: !saving,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Titulo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                          DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                          DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => priority = value);
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Responsables opcionales',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Todos los miembros del departamento reciben la notificacion aunque no sean responsables.',
                      ),
                      if (departmentUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('No hay integrantes activos.'),
                        )
                      else
                        ...departmentUsers.map(
                          (user) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(user.name),
                            subtitle: Text(user.email),
                            value: selectedAssigneeIds.contains(user.id),
                            onChanged: saving
                                ? null
                                : (selected) {
                                    setDialogState(() {
                                      if (selected == true) {
                                        selectedAssigneeIds.add(user.id);
                                      } else {
                                        selectedAssigneeIds.remove(user.id);
                                      }
                                    });
                                  },
                          ),
                        ),
                      if (errorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    if (saved == true) {
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
            _DetailRow(
              label: 'Departamento',
              value: _task.department.name,
            ),
            _DetailRow(
              label: 'Responsables',
              value: _task.assigneeLabel,
            ),
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
