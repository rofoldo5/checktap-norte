import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final TaskRepository _repository;
  List<AppUser> _users = <AppUser>[];
  List<DepartmentSummary> _departments = <DepartmentSummary>[];
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
        _repository.listManagedUsers(),
        _repository.listDepartments(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AppUser>;
        _departments = results[1] as List<DepartmentSummary>;
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

  List<DepartmentSummary> get _activeDepartments => _departments
      .where((department) => department.isActive)
      .toList(growable: false);

  String _departmentNames(Iterable<String> departmentIds) {
    final ids = departmentIds.toSet();
    final names = _departments
        .where((department) => ids.contains(department.id))
        .map((department) => department.name)
        .toList(growable: false);
    return names.isEmpty ? 'Sin departamento' : names.join(', ');
  }

  Future<void> _showCreateDialog() async {
    final activeDepartments = _activeDepartments;
    if (activeDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero debe crear al menos un departamento activo.',
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final selectedDepartmentIds = <String>{activeDepartments.first.id};
    var isAdmin = false;
    var saving = false;
    String? errorMessage;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text;
              if (name.length < 2) {
                setDialogState(
                  () => errorMessage = 'Ingrese un nombre valido.',
                );
                return;
              }
              if (!email.contains('@')) {
                setDialogState(
                  () => errorMessage = 'Ingrese un correo valido.',
                );
                return;
              }
              if (password.length < 6) {
                setDialogState(
                  () => errorMessage = 'La contrasena debe tener 6 caracteres.',
                );
                return;
              }
              if (selectedDepartmentIds.isEmpty) {
                setDialogState(
                  () => errorMessage =
                      'Seleccione al menos un departamento.',
                );
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                await _repository.createUser(
                  name: name,
                  email: email,
                  password: password,
                  isAdmin: isAdmin,
                  departmentIds: selectedDepartmentIds.toList(growable: false),
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
              title: const Text('Nuevo usuario'),
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
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        enabled: !saving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        enabled: !saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contrasena inicial',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Administrador'),
                        subtitle: const Text(
                          'El administrador puede gestionar todos los departamentos.',
                        ),
                        value: isAdmin,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setDialogState(() => isAdmin = value),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Departamentos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'El usuario recibira los avisos de todos los departamentos seleccionados.',
                      ),
                      const SizedBox(height: 6),
                      ...activeDepartments.map(
                        (department) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(department.name),
                          subtitle: Text(
                            '${department.memberCount} integrante(s)',
                          ),
                          value: selectedDepartmentIds.contains(department.id),
                          onChanged: saving
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    if (selected == true) {
                                      selectedDepartmentIds.add(department.id);
                                    } else {
                                      selectedDepartmentIds.remove(
                                        department.id,
                                      );
                                    }
                                  });
                                },
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

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    if (created == true) {
      await _load();
    }
  }

  Future<void> _editUser(AppUser user) async {
    final activeDepartments = _activeDepartments;
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController();
    final selectedDepartmentIds = user.departmentIds
        .where((id) => activeDepartments.any((item) => item.id == id))
        .toSet();
    if (selectedDepartmentIds.isEmpty && activeDepartments.isNotEmpty) {
      selectedDepartmentIds.add(activeDepartments.first.id);
    }
    var isAdmin = user.isAdmin;
    var isActive = user.isActive;
    var saving = false;
    String? errorMessage;
    final isSelf = user.id == widget.session.user!.id;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (nameController.text.trim().length < 2) {
                setDialogState(
                  () => errorMessage = 'Ingrese un nombre valido.',
                );
                return;
              }
              if (selectedDepartmentIds.isEmpty) {
                setDialogState(
                  () => errorMessage =
                      'Seleccione al menos un departamento.',
                );
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                await _repository.updateUser(
                  user,
                  name: nameController.text,
                  password: passwordController.text.isEmpty
                      ? null
                      : passwordController.text,
                  isAdmin: isAdmin,
                  isActive: isActive,
                  departmentIds: selectedDepartmentIds.toList(growable: false),
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
              title: Text('Editar ${user.name}'),
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
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        enabled: !saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contrasena (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Administrador'),
                        subtitle: isSelf
                            ? const Text(
                                'No puede retirarse este permiso a si mismo.',
                              )
                            : null,
                        value: isAdmin,
                        onChanged: saving || isSelf
                            ? null
                            : (value) =>
                                  setDialogState(() => isAdmin = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cuenta activa'),
                        subtitle: isSelf
                            ? const Text(
                                'No puede desactivar su propia cuenta.',
                              )
                            : null,
                        value: isActive,
                        onChanged: saving || isSelf
                            ? null
                            : (value) =>
                                  setDialogState(() => isActive = value),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Departamentos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Los avisos del equipo se envian segun estas membresias.',
                      ),
                      const SizedBox(height: 6),
                      ...activeDepartments.map(
                        (department) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(department.name),
                          subtitle: Text(
                            '${department.memberCount} integrante(s)',
                          ),
                          value: selectedDepartmentIds.contains(department.id),
                          onChanged: saving
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    if (selected == true) {
                                      selectedDepartmentIds.add(department.id);
                                    } else {
                                      selectedDepartmentIds.remove(
                                        department.id,
                                      );
                                    }
                                  });
                                },
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
    passwordController.dispose();
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
        return 'La administracion de usuarios requiere conexion con el servidor.';
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _showCreateDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
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
                itemCount: _users.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        '${user.email}\n'
                        '${user.isAdmin ? 'Administrador' : 'Usuario'} · '
                        '${user.isActive ? 'Activo' : 'Inactivo'}\n'
                        'Departamentos: ${_departmentNames(user.departmentIds)}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editUser(user),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
