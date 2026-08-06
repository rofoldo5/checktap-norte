import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  late final TaskRepository _repository;
  List<DepartmentSummary> _departments = <DepartmentSummary>[];
  List<AppUser> _users = <AppUser>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = TaskRepository(widget.session.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.listDepartments(),
        _repository.listManagedUsers(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = results[0] as List<DepartmentSummary>;
        _users = results[1] as List<AppUser>;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createDepartment() async {
    final controller = TextEditingController();
    var saving = false;
    String? errorMessage;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name = controller.text.trim();
              if (name.length < 2) {
                setDialogState(
                  () => errorMessage = 'Ingrese un nombre valido.',
                );
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                await _repository.createDepartment(name: name);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                    errorMessage = _message(error);
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Nuevo departamento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    enabled: !saving,
                    autofocus: true,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del departamento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
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

    controller.dispose();
    if (created == true) {
      await _load();
    }
  }

  Future<void> _editDepartment(DepartmentSummary department) async {
    DepartmentDetail detail;
    try {
      detail = await _repository.getDepartment(department.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message(error))),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final nameController = TextEditingController(text: detail.name);
    var isActive = detail.isActive;
    final selectedUserIds = detail.members.map((user) => user.id).toSet();
    var saving = false;
    String? errorMessage;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name = nameController.text.trim();
              if (name.length < 2) {
                setDialogState(
                  () => errorMessage = 'Ingrese un nombre valido.',
                );
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                final updated = await _repository.updateDepartment(
                  department,
                  name: name,
                  isActive: isActive,
                );
                await _repository.replaceDepartmentMembers(
                  updated.id,
                  selectedUserIds.toList(growable: false),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                    errorMessage = _message(error);
                  });
                }
              }
            }

            return AlertDialog(
              title: Text('Editar ${detail.name}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Departamento activo'),
                        subtitle: const Text(
                          'Los departamentos inactivos no pueden recibir tareas nuevas.',
                        ),
                        value: isActive,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setDialogState(() => isActive = value),
                      ),
                      const Divider(height: 28),
                      Text(
                        'Integrantes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Todos los integrantes activos reciben los avisos de las tareas del departamento.',
                      ),
                      const SizedBox(height: 8),
                      if (_users.isEmpty)
                        const Text('No hay usuarios disponibles.')
                      else
                        ..._users.map(
                          (user) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(user.name),
                            subtitle: Text(
                              '${user.email} · ${user.isActive ? 'Activo' : 'Inactivo'}',
                            ),
                            value: selectedUserIds.contains(user.id),
                            onChanged: saving || !user.isActive
                                ? null
                                : (selected) {
                                    setDialogState(() {
                                      if (selected == true) {
                                        selectedUserIds.add(user.id);
                                      } else {
                                        selectedUserIds.remove(user.id);
                                      }
                                    });
                                  },
                          ),
                        ),
                      if (errorMessage != null) ...<Widget>[
                        const SizedBox(height: 8),
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

    nameController.dispose();
    if (saved == true) {
      await _load();
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response == null) {
        return 'La administracion de departamentos requiere conexion con el servidor.';
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departamentos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createDepartment,
        icon: const Icon(Icons.domain_add),
        label: const Text('Nuevo departamento'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: _departments.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final department = _departments[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          department.isActive
                              ? Icons.groups
                              : Icons.group_off,
                        ),
                      ),
                      title: Text(department.name),
                      subtitle: Text(
                        '${department.memberCount} integrante(s) · '
                        '${department.isActive ? 'Activo' : 'Inactivo'}',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editDepartment(department),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
