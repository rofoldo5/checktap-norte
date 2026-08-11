import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../services/realtime_service.dart';
import '../services/session_store.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/section_header.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class AccessRequestsScreen extends StatefulWidget {
  const AccessRequestsScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen>
    with WidgetsBindingObserver {
  late final TaskRepository _repository;
  final RealtimeService _realtimeService = RealtimeService();
  List<AppUser> _requests = const <AppUser>[];
  List<DepartmentSummary> _departments = const <DepartmentSummary>[];
  final Set<String> _processingIds = <String>{};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = TaskRepository(widget.session.apiClient);
    _load();
    _startAutomaticRefresh();
  }

  void _startAutomaticRefresh() {
    final token = widget.session.token;
    if (token != null) {
      _realtimeService.connect(
        token: token,
        onTaskChanged: () {},
        onEvent: (payload) {
          final eventName = payload['event']?.toString() ?? '';
          if (eventName.startsWith('access_request.')) {
            unawaited(_load(silent: true));
          }
        },
      );
    }
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.listAccessRequests(),
        _repository.listDepartments(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = results[0] as List<AppUser>;
        _departments = (results[1] as List<DepartmentSummary>)
            .where((department) => department.isActive)
            .toList(growable: false);
        _error = null;
      });
    } catch (error) {
      if (mounted && (!silent || _requests.isEmpty)) {
        setState(() => _error = _message(error));
      }
    } finally {
      _refreshing = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _departmentNames(AppUser user) {
    final ids = user.departmentIds.toSet();
    final names = _departments
        .where((department) => ids.contains(department.id))
        .map((department) => department.name)
        .toList(growable: false);
    return names.isEmpty ? 'Departamento no disponible' : names.join(', ');
  }

  Future<void> _approve(AppUser user) async {
    if (_processingIds.contains(user.id)) {
      return;
    }
    if (_departments.isEmpty) {
      _showSnack('Debe existir al menos un departamento activo.');
      return;
    }

    final decision = await showDialog<_ApprovalDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApprovalDialog(user: user, departments: _departments),
    );
    if (decision == null || !mounted) {
      return;
    }

    setState(() => _processingIds.add(user.id));
    try {
      await _repository.approveAccessRequest(
        user,
        departmentIds: <String>[decision.departmentId],
        isAdmin: decision.isAdmin,
      );
      if (!mounted) {
        return;
      }
      setState(
        () => _requests = _requests
            .where((request) => request.id != user.id)
            .toList(growable: false),
      );
      _showSnack('Acceso aprobado para ${user.name}.');
    } catch (error) {
      if (mounted) {
        _showSnack(_message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(user.id));
      }
    }
  }

  Future<void> _reject(AppUser user) async {
    if (_processingIds.contains(user.id)) {
      return;
    }
    final decision = await showDialog<_RejectionDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RejectionDialog(user: user),
    );
    if (decision == null || !mounted) {
      return;
    }

    setState(() => _processingIds.add(user.id));
    try {
      await _repository.rejectAccessRequest(user, reason: decision.reason);
      if (!mounted) {
        return;
      }
      setState(
        () => _requests = _requests
            .where((request) => request.id != user.id)
            .toList(growable: false),
      );
      _showSnack('Solicitud rechazada.');
    } catch (error) {
      if (mounted) {
        _showSnack(_message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(user.id));
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response == null) {
        return 'Las solicitudes requieren conexión con el servidor.';
      }
    }
    return 'No fue posible completar la operación.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de acceso'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? CheckTapEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No pudimos cargar las solicitudes',
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
                    CheckTapSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeader(
                        title: 'Nuevos integrantes',
                        subtitle:
                            'Revisa el departamento antes de permitir el primer ingreso.',
                      ),
                      const SizedBox(height: CheckTapSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: CheckTapColors.primaryFor(
                              context,
                            ).withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(
                              CheckTapRadius.pill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.how_to_reg_outlined,
                                size: 20,
                                color: CheckTapColors.primaryFor(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_requests.length} pendiente(s)',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: CheckTapColors.primaryFor(context),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _requests.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const <Widget>[
                              SizedBox(height: 72),
                              CheckTapEmptyState(
                                icon: Icons.verified_user_outlined,
                                title: 'Todo al día',
                                message:
                                    'No hay solicitudes pendientes de revisión.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              CheckTapSpacing.md,
                              0,
                              CheckTapSpacing.md,
                              CheckTapSpacing.xxl,
                            ),
                            itemCount: _requests.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: CheckTapSpacing.sm),
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              return _AccessRequestCard(
                                user: request,
                                departmentNames: _departmentNames(request),
                                processing: _processingIds.contains(request.id),
                                onApprove: () => _approve(request),
                                onReject: () => _reject(request),
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

class _AccessRequestCard extends StatelessWidget {
  const _AccessRequestCard({
    required this.user,
    required this.departmentNames,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final AppUser user;
  final String departmentNames;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        border: Border.all(color: CheckTapColors.borderFor(context)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.shadowFor(context),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UserAvatar.fromUser(user, radius: 25),
              const SizedBox(width: CheckTapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: CheckTapColors.warning.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(CheckTapRadius.pill),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(
                    color: CheckTapColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CheckTapSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.apartment_rounded,
                size: 19,
                color: CheckTapColors.textMutedFor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  departmentNames,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: CheckTapSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final approve = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: CheckTapColors.success,
                ),
                onPressed: processing ? null : onApprove,
                icon: processing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Aprobar'),
              );
              final reject = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CheckTapColors.danger,
                  side: const BorderSide(color: CheckTapColors.danger),
                ),
                onPressed: processing ? null : onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    approve,
                    const SizedBox(height: CheckTapSpacing.xs),
                    reject,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: approve),
                  const SizedBox(width: CheckTapSpacing.sm),
                  Expanded(child: reject),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApprovalDecision {
  const _ApprovalDecision({required this.departmentId, required this.isAdmin});

  final String departmentId;
  final bool isAdmin;
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.user, required this.departments});

  final AppUser user;
  final List<DepartmentSummary> departments;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late String _departmentId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _departmentId = widget.user.departmentIds.firstWhere(
      (id) => widget.departments.any((department) => department.id == id),
      orElse: () => widget.departments.first.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar acceso'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Revisa los datos de ${widget.user.name}.'),
              const SizedBox(height: CheckTapSpacing.lg),
              Text(
                'Departamento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Departamento confirmado',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: widget.departments
                    .map(
                      (department) => DropdownMenuItem<String>(
                        value: department.id,
                        child: Text(
                          department.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _departmentId = value);
                  }
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permisos de administrador'),
                subtitle: const Text(
                  'Déjalo desactivado para crear una cuenta de colaborador.',
                ),
                value: _isAdmin,
                onChanged: (value) => setState(() => _isAdmin = value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            _ApprovalDecision(departmentId: _departmentId, isAdmin: _isAdmin),
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aprobar acceso'),
        ),
      ],
    );
  }
}

class _RejectionDecision {
  const _RejectionDecision(this.reason);

  final String? reason;
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog({required this.user});

  final AppUser user;

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${widget.user.name} no podrá ingresar a la aplicación.'),
            const SizedBox(height: CheckTapSpacing.md),
            TextField(
              controller: _reasonController,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'El usuario verá este motivo al intentar ingresar.',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: CheckTapColors.danger),
          onPressed: () {
            final reason = _reasonController.text.trim();
            Navigator.of(
              context,
            ).pop(_RejectionDecision(reason.isEmpty ? null : reason));
          },
          icon: const Icon(Icons.close_rounded),
          label: const Text('Rechazar'),
        ),
      ],
    );
  }
}
