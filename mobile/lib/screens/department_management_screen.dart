import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../widgets/department_form_dialog.dart';

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
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DepartmentFormDialog(
        title: 'Nuevo departamento',
        submitLabel: 'Crear',
        errorMessage: _message,
        onSubmit: (value) async {
          await _repository.createDepartment(name: value.name);
        },
      ),
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _editDepartment(DepartmentSummary department) async {
    DepartmentDetail detail;
    try {
      detail = await _repository.getDepartment(department.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DepartmentFormDialog(
        title: 'Editar ${detail.name}',
        submitLabel: 'Guardar',
        initialName: detail.name,
        initialIsActive: detail.isActive,
        users: _users,
        initialMemberIds: detail.members.map((user) => user.id).toSet(),
        showMembers: true,
        errorMessage: _message,
        onSubmit: (value) async {
          final updated = await _repository.updateDepartment(
            department,
            name: value.name,
            isActive: value.isActive,
          );
          await _repository.replaceDepartmentMembers(
            updated.id,
            value.memberIds,
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
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final department = _departments[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          department.isActive ? Icons.groups : Icons.group_off,
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
