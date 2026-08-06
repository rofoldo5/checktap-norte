import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../widgets/user_form_dialog.dart';

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
          content: Text('Primero debe crear al menos un departamento activo.'),
        ),
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserFormDialog(
        departments: activeDepartments,
        currentUserId: widget.session.user?.id,
        errorMessage: _message,
        onSubmit: (value) async {
          await _repository.createUser(
            name: value.name,
            email: value.email!,
            password: value.password!,
            isAdmin: value.isAdmin,
            departmentIds: value.departmentIds,
          );
        },
      ),
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _editUser(AppUser user) async {
    final activeDepartments = _activeDepartments;
    if (activeDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe existir al menos un departamento activo para editar membresías.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserFormDialog(
        departments: activeDepartments,
        user: user,
        currentUserId: widget.session.user?.id,
        errorMessage: _message,
        onSubmit: (value) async {
          await _repository.updateUser(
            user,
            name: value.name,
            password: value.password,
            isAdmin: value.isAdmin,
            isActive: value.isActive,
            departmentIds: value.departmentIds,
          );
        },
      ),
    );

    if (saved == true && mounted) {
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
