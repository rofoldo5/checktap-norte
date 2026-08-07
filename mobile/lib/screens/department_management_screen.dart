import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../widgets/department_form_dialog.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/section_header.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo departamento',
        onPressed: _loading ? null : _createDepartment,
        child: const Icon(Icons.add_business_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? CheckTapEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No pudimos cargar los departamentos',
              message: _error!,
              actionLabel: 'Reintentar',
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  CheckTapSpacing.md,
                  CheckTapSpacing.sm,
                  CheckTapSpacing.md,
                  110,
                ),
                children: <Widget>[
                  const SectionHeader(
                    title: 'Departamentos',
                    subtitle:
                        'Organiza equipos, miembros y notificaciones por área.',
                  ),
                  const SizedBox(height: CheckTapSpacing.md),
                  _DepartmentSummaryBanner(
                    active: _departments.where((d) => d.isActive).length,
                    members: _departments.fold<int>(
                      0,
                      (total, department) => total + department.memberCount,
                    ),
                  ),
                  const SizedBox(height: CheckTapSpacing.lg),
                  if (_departments.isEmpty)
                    CheckTapEmptyState(
                      icon: Icons.apartment_rounded,
                      title: 'Todavía no hay departamentos',
                      message:
                          'Crea el primer departamento para organizar usuarios y tareas.',
                      actionLabel: 'Crear departamento',
                      onAction: _createDepartment,
                    )
                  else
                    ..._departments.map(
                      (department) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: CheckTapSpacing.sm,
                        ),
                        child: _DepartmentCard(
                          department: department,
                          onTap: () => _editDepartment(department),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DepartmentSummaryBanner extends StatelessWidget {
  const _DepartmentSummaryBanner({required this.active, required this.members});

  final int active;
  final int members;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.lg),
      decoration: BoxDecoration(
        gradient: CheckTapColors.brandGradient,
        borderRadius: BorderRadius.circular(CheckTapRadius.xl),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.apartment_rounded, color: Colors.white, size: 40),
          const SizedBox(width: CheckTapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$active departamento(s) activo(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  '$members membresía(s) registradas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.onTap});

  final DepartmentSummary department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = department.isActive
        ? CheckTapColors.success
        : CheckTapColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(CheckTapSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(CheckTapRadius.lg),
            border: Border.all(color: CheckTapColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CheckTapColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CheckTapRadius.md),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: CheckTapColors.primary,
                ),
              ),
              const SizedBox(width: CheckTapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      department.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${department.memberCount} integrante(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          department.isActive ? 'Activo' : 'Inactivo',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CheckTapColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
