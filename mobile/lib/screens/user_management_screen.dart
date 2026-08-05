import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
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
      final users = await _repository.listManagedUsers();
      if (!mounted) {
        return;
      }
      setState(() => _users = users);
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

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      value: isAdmin,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => isAdmin = value),
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
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController();
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          : (value) => setDialogState(() => isAdmin = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cuenta activa'),
                      subtitle: isSelf
                          ? const Text('No puede desactivar su propia cuenta.')
                          : null,
                      value: isActive,
                      onChanged: saving || isSelf
                          ? null
                          : (value) => setDialogState(() => isActive = value),
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
        onPressed: _showCreateDialog,
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
                separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                        '${user.email}\n${user.isAdmin ? 'Administrador' : 'Usuario'} · '
                        '${user.isActive ? 'Activo' : 'Inactivo'}',
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
