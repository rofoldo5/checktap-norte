import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../widgets/user_form_dialog.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/search_field.dart';
import '../ui/components/section_header.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = TaskRepository(widget.session.apiClient);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<AppUser> get _filteredUsers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _users;
    }
    return _users
        .where((user) {
          final content = <String>[
            user.name,
            user.email,
            _departmentNames(user.departmentIds),
          ].join(' ').toLowerCase();
          return content.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo usuario',
        onPressed: _loading ? null : _showCreateDialog,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? CheckTapEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No pudimos cargar los usuarios',
              message: _error!,
              actionLabel: 'Reintentar',
              onAction: _load,
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CheckTapSpacing.md,
                    CheckTapSpacing.sm,
                    CheckTapSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeader(
                        title: 'Usuarios',
                        subtitle:
                            'Administra accesos y membresías por departamento.',
                      ),
                      const SizedBox(height: CheckTapSpacing.md),
                      CheckTapSearchField(
                        controller: _searchController,
                        hintText: 'Buscar por nombre, correo o departamento…',
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: users.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: <Widget>[
                              const SizedBox(height: 70),
                              CheckTapEmptyState(
                                icon: _query.isEmpty
                                    ? Icons.group_outlined
                                    : Icons.search_off_rounded,
                                title: _query.isEmpty
                                    ? 'Todavía no hay usuarios'
                                    : 'No encontramos usuarios',
                                message: _query.isEmpty
                                    ? 'Crea el primer usuario y asígnalo a uno o varios departamentos.'
                                    : 'Prueba con otro nombre, correo o departamento.',
                                actionLabel: _query.isEmpty
                                    ? 'Crear usuario'
                                    : 'Limpiar búsqueda',
                                onAction: _query.isEmpty
                                    ? _showCreateDialog
                                    : () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              CheckTapSpacing.md,
                              0,
                              CheckTapSpacing.md,
                              110,
                            ),
                            itemCount: users.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: CheckTapSpacing.sm),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _UserCard(
                                user: user,
                                departmentNames: _departmentNames(
                                  user.departmentIds,
                                ),
                                onTap: () => _editUser(user),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.departmentNames,
    required this.onTap,
  });

  final AppUser user;
  final String departmentNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = user.isActive
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UserAvatar.fromUser(user, radius: 24),
              const SizedBox(width: CheckTapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (user.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CheckTapColors.primary.withValues(
                                alpha: 0.09,
                              ),
                              borderRadius: BorderRadius.circular(
                                CheckTapRadius.pill,
                              ),
                            ),
                            child: Text(
                              'Admin',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: CheckTapColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.isActive ? 'Activo' : 'Inactivo',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.apartment_rounded,
                          size: 16,
                          color: CheckTapColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            departmentNames,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CheckTapColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
