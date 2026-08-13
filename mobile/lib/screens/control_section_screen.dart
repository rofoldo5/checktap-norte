import 'dart:async';

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
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import '../widgets/control_check_form_dialog.dart';
import '../widgets/control_section_form_dialog.dart';
import 'control_check_detail_screen.dart';

class ControlSectionScreen extends StatefulWidget {
  const ControlSectionScreen({
    required this.session,
    required this.section,
    required this.users,
    required this.departments,
    super.key,
  });

  final SessionStore session;
  final ControlSectionItem section;
  final List<AppUser> users;
  final List<DepartmentSummary> departments;

  @override
  State<ControlSectionScreen> createState() => _ControlSectionScreenState();
}

class _ControlSectionScreenState extends State<ControlSectionScreen> {
  late final ControlRepository _repository;
  late ControlSectionItem _section;
  final TextEditingController _searchController = TextEditingController();
  List<ControlCheckItem> _checks = const <ControlCheckItem>[];
  bool _loading = true;
  bool _refreshing = false;
  bool _offline = false;
  String _filter = 'ALL';
  String _query = '';

  AppUser get _currentUser => widget.session.user!;

  bool get _canCreateCheck =>
      _currentUser.isAdmin ||
      _currentUser.departmentIds.contains(_section.department.id);

  @override
  void initState() {
    super.initState();
    _section = widget.section;
    _repository = ControlRepository(widget.session.apiClient);
    unawaited(_loadOfflineFirst());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineFirst() async {
    try {
      final cached = await _repository.loadCached();
      _applySnapshot(cached.sections, cached.checks, offline: true);
    } catch (_) {
      // Remote refresh will provide the error state if needed.
    }
    await _refresh(showLoader: _checks.isEmpty);
  }

  void _applySnapshot(
    List<ControlSectionItem> sections,
    List<ControlCheckItem> checks, {
    required bool offline,
  }) {
    if (!mounted) {
      return;
    }
    ControlSectionItem? matching;
    for (final item in sections) {
      if (item.id == _section.id) {
        matching = item;
        break;
      }
    }
    final sectionChecks = checks
        .where((item) => item.sectionId == _section.id)
        .toList(growable: false)
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    setState(() {
      if (matching != null) {
        _section = matching!;
      }
      _checks = sectionChecks;
      _offline = offline;
      _loading = false;
    });
    unawaited(
      NotificationService.instance.syncControlReminders(
        checks,
        _currentUser,
      ),
    );
  }

  Future<void> _refresh({bool showLoader = false}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    if (mounted && showLoader) {
      setState(() => _loading = true);
    }
    try {
      await _repository.synchronizePending();
      final snapshot = await _repository.refreshFromServer();
      _applySnapshot(snapshot.sections, snapshot.checks, offline: false);
    } catch (_) {
      final cached = await _repository.loadCached();
      _applySnapshot(cached.sections, cached.checks, offline: true);
    } finally {
      _refreshing = false;
    }
  }

  List<ControlCheckItem> get _visibleChecks {
    final query = _query.trim().toLowerCase();
    return _checks.where((check) {
      final stateMatches = switch (_filter) {
        'UPCOMING' => check.dueState == 'PROXIMA' || check.dueState == 'URGENTE',
        'OVERDUE' => check.dueState == 'VENCIDA',
        'COMPLETED' => check.dueState == 'COMPLETADA',
        _ => true,
      };
      if (!stateMatches) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        check.title,
        check.description ?? '',
        check.reference ?? '',
        check.contact ?? '',
        check.notes ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Future<void> _createCheck() async {
    if (!_canCreateCheck) {
      return;
    }
    final draft = await showDialog<ControlCheckDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ControlCheckFormDialog(
        section: _section,
        users: widget.users,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await _repository.createCheck(
        currentUser: _currentUser,
        section: _section,
        title: draft.title,
        description: draft.description,
        reference: draft.reference,
        contact: draft.contact,
        notes: draft.notes,
        priority: draft.priority,
        dueAt: draft.dueAt,
        timezone: draft.timezone,
        reminderMinutes: draft.reminderMinutes,
        recurrenceType: draft.recurrenceType,
        recurrenceInterval: draft.recurrenceInterval,
        recurrenceUnit: draft.recurrenceUnit,
        assignees: draft.assignees,
      );
      await _reloadCache();
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_refresh());
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _reloadCache() async {
    final cached = await _repository.loadCached();
    _applySnapshot(cached.sections, cached.checks, offline: _offline);
  }

  Future<void> _openCheck(ControlCheckItem check) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ControlCheckDetailScreen(
          session: widget.session,
          section: _section,
          check: check,
          users: widget.users,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reloadCache();
      unawaited(_refresh());
    }
  }

  Future<void> _editSection() async {
    if (!_currentUser.isAdmin) {
      return;
    }
    final draft = await showDialog<ControlSectionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ControlSectionFormDialog(
        section: _section,
        departments: widget.departments,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      _section = await _repository.updateSection(
        section: _section,
        name: draft.name,
        description: draft.description,
        iconKey: draft.iconKey,
        department: draft.department,
      );
      await _reloadCache();
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_refresh());
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _archiveSection() async {
    if (!_currentUser.isAdmin) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar secci\u00f3n'),
        content: Text(
          'La secci\u00f3n "${_section.name}" dejar\u00e1 de mostrarse. '
          'Esta acci\u00f3n no elimina el historial de la base de datos.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _repository.archiveSection(_section);
      await BackgroundSyncScheduler.scheduleOneOff();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_section.name),
        actions: <Widget>[
          if (_currentUser.isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Opciones de secci\u00f3n',
              onSelected: (value) {
                if (value == 'edit') {
                  unawaited(_editSection());
                } else if (value == 'archive') {
                  unawaited(_archiveSection());
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar secci\u00f3n'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'archive',
                  child: ListTile(
                    leading: Icon(Icons.archive_outlined),
                    title: Text('Archivar secci\u00f3n'),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _canCreateCheck
          ? FloatingActionButton.extended(
              heroTag: 'control-check-fab-${_section.id}',
              onPressed: _createCheck,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nuevo check'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _checks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final visible = _visibleChecks;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
          CheckTapSpacing.md,
          120,
        ),
        children: <Widget>[
          _SectionHero(section: _section, offline: _offline),
          const SizedBox(height: CheckTapSpacing.md),
          CheckTapSearchField(
            controller: _searchController,
            hintText: 'Buscar en ${_section.name}...',
            onChanged: (value) => setState(() => _query = value),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: CheckTapSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _ControlFilterChip(
                  label: 'Todos',
                  value: 'ALL',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                _ControlFilterChip(
                  label: 'Pr\u00f3ximos',
                  value: 'UPCOMING',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                _ControlFilterChip(
                  label: 'Vencidos',
                  value: 'OVERDUE',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                _ControlFilterChip(
                  label: 'Completados',
                  value: 'COMPLETED',
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: CheckTapSpacing.md),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: CheckTapEmptyState(
                icon: _query.isEmpty
                    ? Icons.fact_check_outlined
                    : Icons.search_off_rounded,
                title: _checks.isEmpty
                    ? 'A\u00fan no hay checks'
                    : 'No hay resultados en este filtro',
                message: _checks.isEmpty
                    ? 'Agrega el primer elemento que quieras vigilar dentro de ${_section.name}.'
                    : 'Cambia el filtro o la b\u00fasqueda para ver otros controles.',
                actionLabel: _checks.isEmpty && _canCreateCheck
                    ? 'Nuevo check'
                    : null,
                onAction: _checks.isEmpty && _canCreateCheck
                    ? _createCheck
                    : null,
              ),
            )
          else
            ...visible.map(
              (check) => Padding(
                padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                child: _ControlCheckCard(
                  check: check,
                  onTap: () => _openCheck(check),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHero extends StatelessWidget {
  const _SectionHero({required this.section, required this.offline});

  final ControlSectionItem section;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        gradient: CheckTapColors.panelGradientFor(context),
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: CheckTapColors.panelIconTileFor(context),
              borderRadius: BorderRadius.circular(CheckTapRadius.md),
            ),
            child: Icon(
              controlSectionIcon(section.iconKey),
              color: CheckTapColors.panelAccentFor(context),
            ),
          ),
          const SizedBox(width: CheckTapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: CheckTapColors.panelTextFor(context),
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.xxs),
                Text(
                  '${section.department.name} \u00b7 ${section.checkCount} checks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CheckTapColors.panelMutedTextFor(context),
                  ),
                ),
                if (offline) ...<Widget>[
                  const SizedBox(height: CheckTapSpacing.xs),
                  Text(
                    'Modo local: cambios pendientes de sincronizar',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CheckTapColors.panelMutedTextFor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCheckCard extends StatelessWidget {
  const _ControlCheckCard({required this.check, required this.onTap});

  final ControlCheckItem check;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateColor = controlDueColor(context, check.dueState);
    final nextReminder = nextControlReminder(check);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(CheckTapSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CheckTapRadius.sm),
                    ),
                    child: Icon(
                      check.isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: stateColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: CheckTapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          check.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((check.reference ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.xxs),
                          Text(
                            check.reference!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CheckTapColors.textMutedFor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: CheckTapSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CheckTapRadius.pill),
                    ),
                    child: Text(
                      controlDueStateLabel(check.dueState),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: stateColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _InlineInfo(
                    icon: Icons.calendar_today_outlined,
                    text: controlDueLabel(context, check.dueAt),
                  ),
                  const SizedBox(height: CheckTapSpacing.xxs),
                  _InlineInfo(
                    icon: Icons.timelapse_rounded,
                    text: controlRelativeDueLabel(check),
                    color: stateColor,
                  ),
                  if (check.isRecurring) ...<Widget>[
                    const SizedBox(height: CheckTapSpacing.xxs),
                    _InlineInfo(
                      icon: Icons.repeat_rounded,
                      text: check.recurrenceLabel,
                    ),
                  ],
                ],
              ),
              if (nextReminder != null) ...<Widget>[
                const SizedBox(height: CheckTapSpacing.xs),
                _InlineInfo(
                  icon: Icons.notifications_active_outlined,
                  text:
                      'Pr\u00f3ximo aviso: ${controlDueLabel(context, nextReminder)}',
                  color: CheckTapColors.cyanFor(context),
                ),
              ] else if (check.reminderMinutes.isNotEmpty) ...<Widget>[
                const SizedBox(height: CheckTapSpacing.xs),
                _InlineInfo(
                  icon: Icons.notifications_outlined,
                  text: check.reminderMinutes
                      .map(controlReminderLabel)
                      .join(' \u00b7 '),
                ),
              ],
              const SizedBox(height: CheckTapSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: UserAvatarStack(
                      users: check.assignees,
                      radius: 12,
                    ),
                  ),
                  if (check.hasPendingChanges)
                    const Padding(
                      padding: EdgeInsets.only(right: CheckTapSpacing.xs),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 19,
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? CheckTapColors.textMutedFor(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: resolved),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: resolved,
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlFilterChip extends StatelessWidget {
  const _ControlFilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: CheckTapSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}
