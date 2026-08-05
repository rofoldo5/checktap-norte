import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/task_item.dart';
import '../services/realtime_service.dart';
import '../services/session_store.dart';
import '../services/task_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final TaskService _taskService;
  final RealtimeService _realtimeService = RealtimeService();

  List<TaskItem> _tasks = <TaskItem>[];
  List<AppUser> _users = <AppUser>[];
  bool _loading = true;
  String? _error;
  String _filter = 'TODAS';
  bool _realtimeConnected = false;
  bool _silentRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    _taskService = TaskService(widget.session.apiClient);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadData();
      _realtimeService.connect(
        token: widget.session.token!,
        onTaskChanged: _loadTasksSilently,
        onConnectionChanged: (connected) {
          if (mounted && _realtimeConnected != connected) {
            setState(() => _realtimeConnected = connected);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _taskService.listTasks(status: _filter == 'TODAS' ? null : _filter),
        _taskService.listUsers(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = results[0] as List<TaskItem>;
        _users = results[1] as List<AppUser>;
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _messageFromError(error));
    } catch (error, stackTrace) {
      debugPrint('Error procesando datos del dashboard: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _error = 'El servidor respondio, pero los datos no pudieron procesarse: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTasksSilently() async {
    if (_silentRefreshRunning) {
      return;
    }

    _silentRefreshRunning = true;
    try {
      final tasks = await _taskService.listTasks(
        status: _filter == 'TODAS' ? null : _filter,
      );
      if (mounted) {
        setState(() => _tasks = tasks);
      }
    } catch (error, stackTrace) {
      debugPrint('Error actualizando tareas en tiempo real: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _silentRefreshRunning = false;
    }
  }

  String _messageFromError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'No fue posible conectar con el servidor.';
  }

  Future<void> _runTaskAction(Future<void> Function() action) async {
    try {
      await action();
      await _loadTasksSilently();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(error))),
      );
    }
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'MEDIA';
    String? assignedToId;
    bool saving = false;
    String? dialogError;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (titleController.text.trim().length < 2) {
                setDialogState(() => dialogError = 'Ingrese un titulo valido.');
                return;
              }

              setDialogState(() {
                saving = true;
                dialogError = null;
              });

              try {
                await _taskService.createTask(
                  title: titleController.text,
                  description: descriptionController.text,
                  priority: priority,
                  assignedToId: assignedToId,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on DioException catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    dialogError = _messageFromError(error);
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Nueva tarea'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Titulo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                      DropdownButtonFormField<String>(
                        initialValue: assignedToId,
                        decoration: const InputDecoration(
                          labelText: 'Asignar a',
                          border: OutlineInputBorder(),
                        ),
                        items: _users
                            .map(
                              (user) => DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(user.name),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                                  () => assignedToId = value,
                                ),
                      ),
                      if (dialogError != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
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
                      : const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (created == true) {
      await _loadTasksSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas compartidas'),
        actions: <Widget>[
          Tooltip(
            message: _realtimeConnected
                ? 'Tiempo real conectado'
                : 'Tiempo real desconectado',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                _realtimeConnected ? Icons.cloud_done : Icons.cloud_off,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await widget.session.logout();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(widget.session.user!.name),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesion'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'TODAS', label: Text('Todas')),
                ButtonSegment<String>(
                  value: 'PENDIENTE',
                  label: Text('Pendientes'),
                ),
                ButtonSegment<String>(
                  value: 'EN_PROGRESO',
                  label: Text('En progreso'),
                ),
                ButtonSegment<String>(
                  value: 'COMPLETADA',
                  label: Text('Completadas'),
                ),
              ],
              selected: <String>{_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
                _loadData();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadData, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 160),
            Icon(Icons.inbox_outlined, size: 58),
            SizedBox(height: 12),
            Center(child: Text('No hay tareas en esta vista.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: _tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _TaskCard(
          key: ValueKey<String>(_tasks[index].id),
          task: _tasks[index],
          onStart: () => _runTaskAction(
            () => _taskService.startTask(_tasks[index].id),
          ),
          onComplete: () => _runTaskAction(
            () => _taskService.completeTask(_tasks[index].id),
          ),
          onReopen: () => _runTaskAction(
            () => _taskService.reopenTask(_tasks[index].id),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.onStart,
    required this.onComplete,
    required this.onReopen,
  });

  final TaskItem task;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == 'COMPLETADA';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration: completed ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ),
                _Tag(label: task.priority),
              ],
            ),
            if (task.description?.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 8),
              Text(task.description!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _Tag(label: task.status.replaceAll('_', ' ')),
                Text('Creador: ${task.createdBy.name}'),
                Text('Asignada a: ${task.assignedTo?.name ?? 'Sin asignar'}'),
                if (task.completedBy != null)
                  Text('Completada por: ${task.completedBy!.name}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (task.status == 'PENDIENTE')
                  TextButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  ),
                if (!completed)
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Completar'),
                  ),
                if (completed)
                  OutlinedButton.icon(
                    onPressed: onReopen,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}
