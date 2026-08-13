import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/repositories/control_repository.dart';
import '../models/app_user.dart';
import '../models/control_item.dart';
import '../models/department.dart';
import '../services/background_sync.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';
import '../ui/components/control_visuals.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/search_field.dart';
import '../ui/components/section_header.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import '../widgets/control_section_form_dialog.dart';
import 'control_section_screen.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({
    required this.session,
    required this.users,
    required this.departments,
    this.initialDepartmentId,
    this.refreshEpoch = 0,
    super.key,
  });

  final SessionStore session;
  final List<AppUser> users;
  final List<DepartmentSummary> departments;
  final String? initialDepartmentId;
  final int refreshEpoch;

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  late final ControlRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  List<ControlSectionItem> _sections = const <ControlSectionItem>[];
  List<ControlCheckItem> _checks = const <ControlCheckItem>[];
  bool _loading = true;
  bool _refreshing = false;
  bool _offline = false;
  String? _error;
  String _query = '';

  List<DepartmentSummary> get _activeDepartments => widget.departments
      .where((item) => item.isActive)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _repository = ControlRepository(widget.session.apiClient);
    unawaited(_loadOfflineFirst());
  }

  @override
  void didUpdateWidget(covariant ControlsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshEpoch != widget.refreshEpoch) {
      unawaited(_reloadFromCache());
    }
  }

  Future<void> _reloadFromCache() async {
    try {
      final cached = await _repository.loadCached();
      _applySnapshot(cached.sections, cached.checks, offline: _offline);
    } catch (_) {
      // Keep the current state if the local cache cannot be read.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineFirst() async {
    try {
      final cached = await _repository.loadCached();
      if (mounted && (cached.sections.isNotEmpty || cached.checks.isNotEmpty)) {
        _applySnapshot(cached.sections, cached.checks, offline: true);
      }
    } catch (_) {
      // A cache read failure is handled by the remote refresh below.
    }
    await _refresh(showLoader: _sections.isEmpty);
  }

  void _applySnapshot(
    List<ControlSectionItem> sections,
    List<ControlCheckItem> checks, {
    required bool offline,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sections = sections;
      _checks = checks;
      _offline = offline;
      _loading = false;
      _error = null;
    });
    final user = widget.session.user;
    if (user != null) {
      unawaited(
        NotificationService.instance.syncControlReminders(checks, user),
      );
    }
  }

  Future<void> _refresh({bool showLoader = false}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    if (mounted) {
      setState(() {
        if (showLoader) {
          _loading = true;
        }
        _error = null;
      });
    }
    try {
      final sync = await _repository.synchronizePending();
      if (sync.unauthorized) {
        throw DioException(
          requestOptions: RequestOptions(path: '/sync'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/sync'),
            statusCode: 401,
          ),
        );
      }
      final snapshot = await _repository.refreshFromServer();
      _applySnapshot(snapshot.sections, snapshot.checks, offline: false);
    } on DioException catch (error) {
      final cached = await _repository.loadCached();
      if (!mounted) {
        return;
      }
      if (cached.sections.isNotEmpty || cached.checks.isNotEmpty) {
        _applySnapshot(cached.sections, cached.checks, offline: true);
      } else {
        setState(() {
          _loading = false;
          _offline = true;
          _error = _messageFromError(error);
        });
      }
    } catch (error) {
      final cached = await _repository.loadCached();
      if (!mounted) {
        return;
      }
      if (cached.sections.isNotEmpty || cached.checks.isNotEmpty) {
        _applySnapshot(cached.sections, cached.checks, offline: true);
      } else {
        setState(() {
          _loading = false;
          _offline = true;
          _error = 'No fue posible cargar los controles: $error';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  String _messageFromError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'No fue posible conectar con el servidor.';
  }

  List<ControlSectionItem> get _visibleSections {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _sections;
    }
    return _sections.where((section) {
      final haystack = <String>[
        section.name,
        section.description ?? '',
        section.department.name,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Future<void> _createSection() async {
    final user = widget.session.user;
    final departments = _activeDepartments;
    if (user == null || !user.isAdmin) {
      return;
    }
    if (departments.isEmpty) {
      _showMessage('No hay departamentos activos disponibles.');
      return;
    }
    final draft = await showDialog<ControlSectionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ControlSectionFormDialog(
        departments: departments,
        initialDepartmentId: widget.initialDepartmentId,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await _repository.createSection(
        currentUser: user,
        name: draft.name,
        description: draft.description,
        iconKey: draft.iconKey,
        department: draft.department,
      );
      final cached = await _repository.loadCached();
      _applySnapshot(cached.sections, cached.checks, offline: _offline);
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_refresh());
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openSection(ControlSectionItem section) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ControlSectionScreen(
          session: widget.session,
          section: section,
          users: widget.users,
          departments: _activeDepartments,
        ),
      ),
    );
    if (changed == true && mounted) {
      final cached = await _repository.loadCached();
      _applySnapshot(cached.sections, cached.checks, offline: _offline);
      unawaited(_refresh());
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateSection = widget.session.user?.isAdmin ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canCreateSection
          ? FloatingActionButton.extended(
              heroTag: 'controls-section-fab',
              tooltip: 'Nueva secci\u00f3n',
              onPressed: _createSection,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Nueva secci\u00f3n'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _sections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sections.isEmpty) {
      return CheckTapEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar los controles',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: () => _refresh(showLoader: true),
      );
    }

    final visible = _visibleSections;
    final totalUpcoming = _sections.fold<int>(
      0,
      (sum, item) => sum + item.upcomingCount,
    );
    final totalOverdue = _sections.fold<int>(
      0,
      (sum, item) => sum + item.overdueCount,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey<String>('controls-overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
          CheckTapSpacing.md,
          120,
        ),
        children: <Widget>[
          const SectionHeader(
            title: 'Controles',
            subtitle:
                'Organiza vencimientos, revisiones y recordatorios por secciones.',
          ),
          if (_offline) ...<Widget>[
            const SizedBox(height: CheckTapSpacing.sm),
            _ControlInfoBanner(
              icon: Icons.cloud_off_rounded,
              text:
                  'Mostrando datos locales. Los cambios se sincronizar\u00e1n al recuperar conexi\u00f3n.',
            ),
          ],
          const SizedBox(height: CheckTapSpacing.md),
          CheckTapSearchField(
            controller: _searchController,
            hintText: 'Buscar secci\u00f3n o departamento...',
            onChanged: (value) => setState(() => _query = value),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: CheckTapSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.folder_open_rounded,
                  label: 'Secciones',
                  value: _sections.length.toString(),
                  color: CheckTapColors.primaryFor(context),
                ),
              ),
              const SizedBox(width: CheckTapSpacing.xs),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.notifications_active_outlined,
                  label: 'Pr\u00f3ximos',
                  value: totalUpcoming.toString(),
                  color: CheckTapColors.cyanFor(context),
                ),
              ),
              const SizedBox(width: CheckTapSpacing.xs),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.warning_amber_rounded,
                  label: 'Vencidos',
                  value: totalOverdue.toString(),
                  color: CheckTapColors.adaptAccent(
                    context,
                    CheckTapColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CheckTapSpacing.lg),
          if (visible.isEmpty)
            CheckTapEmptyState(
              icon: _query.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              title: _query.isEmpty
                  ? 'Todav\u00eda no hay secciones'
                  : 'No encontramos coincidencias',
              message: _query.isEmpty
                  ? (widget.session.user?.isAdmin ?? false)
                        ? 'Crea secciones como Dominios, Servidores o Mantenimientos y agrega sus checks.'
                        : 'Un administrador debe crear las secciones de control.'
                  : 'Prueba con otro nombre o departamento.',
              actionLabel:
                  _query.isEmpty && (widget.session.user?.isAdmin ?? false)
                  ? 'Nueva secci\u00f3n'
                  : null,
              onAction:
                  _query.isEmpty && (widget.session.user?.isAdmin ?? false)
                  ? _createSection
                  : null,
            )
          else
            ...visible.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                child: _ControlSectionCard(
                  section: section,
                  onTap: () => _openSection(section),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlSectionCard extends StatelessWidget {
  const _ControlSectionCard({required this.section, required this.onTap});

  final ControlSectionItem section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdueColor = CheckTapColors.adaptAccent(
      context,
      CheckTapColors.danger,
    );
    final summary = <String>[
      if (section.upcomingCount > 0) '${section.upcomingCount} pr\u00f3ximos',
      if (section.urgentCount > 0) '${section.urgentCount} urgentes',
      if (section.overdueCount > 0) '${section.overdueCount} vencidos',
      if (section.completedCount > 0)
        '${section.completedCount} completados',
    ];
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(CheckTapSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CheckTapColors.cyanFor(
                    context,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CheckTapRadius.md),
                ),
                child: Icon(
                  controlSectionIcon(section.iconKey),
                  color: CheckTapColors.cyanFor(context),
                ),
              ),
              const SizedBox(width: CheckTapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            section.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: CheckTapColors.surfaceSoftFor(context),
                            borderRadius: BorderRadius.circular(
                              CheckTapRadius.pill,
                            ),
                            border: Border.all(
                              color: CheckTapColors.borderFor(context),
                            ),
                          ),
                          child: Text(
                            section.checkCount.toString(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CheckTapSpacing.xxs),
                    Text(
                      section.department.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.textMutedFor(context),
                      ),
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: CheckTapSpacing.xs),
                      Text(
                        summary.join(' \u00b7 '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: section.overdueCount > 0
                              ? overdueColor
                              : CheckTapColors.textMutedFor(context),
                          fontWeight: section.overdueCount > 0
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: CheckTapSpacing.xs),
                      Text(
                        'Sin checks pendientes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CheckTapColors.textMutedFor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CheckTapSpacing.xs),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.sm),
      decoration: BoxDecoration(
        color: CheckTapColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: CheckTapColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(height: CheckTapSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CheckTapColors.textMutedFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlInfoBanner extends StatelessWidget {
  const _ControlInfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.sm),
      decoration: BoxDecoration(
        color: CheckTapColors.cyanFor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(
          color: CheckTapColors.cyanFor(context).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: CheckTapColors.cyanFor(context)),
          const SizedBox(width: CheckTapSpacing.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
