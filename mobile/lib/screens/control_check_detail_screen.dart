import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/control_repository.dart';
import '../models/app_user.dart';
import '../models/control_item.dart';
import '../services/background_sync.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';
import '../ui/components/control_visuals.dart';
import '../ui/components/section_header.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import '../widgets/control_check_form_dialog.dart';

class ControlCheckDetailScreen extends StatefulWidget {
  const ControlCheckDetailScreen({
    required this.session,
    required this.section,
    required this.check,
    required this.users,
    super.key,
  });

  final SessionStore session;
  final ControlSectionItem section;
  final ControlCheckItem check;
  final List<AppUser> users;

  @override
  State<ControlCheckDetailScreen> createState() =>
      _ControlCheckDetailScreenState();
}

class _ControlCheckDetailScreenState
    extends State<ControlCheckDetailScreen> {
  late final ControlRepository _repository;
  late ControlCheckItem _check;
  bool _loading = false;
  bool _changed = false;

  AppUser get _currentUser => widget.session.user!;

  bool get _canEdit =>
      _currentUser.isAdmin || _check.createdBy.id == _currentUser.id;

  bool get _canWork =>
      _currentUser.isAdmin ||
      _currentUser.departmentIds.contains(widget.section.department.id);

  @override
  void initState() {
    super.initState();
    _repository = ControlRepository(widget.session.apiClient);
    _check = widget.check;
    unawaited(_refreshCheck());
  }

  Future<void> _refreshCheck() async {
    try {
      final cached = await _repository.readCachedCheck(_check.id);
      if (cached != null && mounted) {
        setState(() => _check = cached);
      }
      if (cached?.hasPendingChanges ?? false) {
        return;
      }
      final remote = await _repository.refreshCheck(_check.id);
      if (mounted) {
        setState(() => _check = remote);
      }
    } catch (_) {
      // The cached detail remains usable offline.
    }
  }

  Future<void> _syncAllReminders() async {
    try {
      final snapshot = await _repository.loadCached();
      await NotificationService.instance.syncControlReminders(
        snapshot.checks,
        _currentUser,
      );
    } catch (_) {
      // Reminder refresh must not block control actions.
    }
  }

  Future<void> _edit() async {
    if (!_canEdit || _loading) {
      return;
    }
    final draft = await showDialog<ControlCheckDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ControlCheckFormDialog(
        section: widget.section,
        users: widget.users,
        check: _check,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      _check = await _repository.updateCheck(
        check: _check,
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
      _changed = true;
      await BackgroundSyncScheduler.scheduleOneOff();
      await _syncAllReminders();
      if (mounted) {
        setState(() {});
        _showMessage('Cambios guardados.');
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _askCompletionNotes() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Completar check'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Nota de cierre (opcional)',
              hintText: 'Ej. Renovado por un a\u00f1o.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Completar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _complete() async {
    if (!_canWork || _check.isCompleted || _loading) {
      return;
    }
    final notes = await _askCompletionNotes();
    if (notes == null || !mounted) {
      return;
    }
    final previousDue = _check.dueAt;
    setState(() => _loading = true);
    try {
      _check = await _repository.completeCheck(
        _check,
        _currentUser,
        completionNotes: notes,
      );
      _changed = true;
      await BackgroundSyncScheduler.scheduleOneOff();
      await _syncAllReminders();
      if (mounted) {
        setState(() {});
        if (_check.isRecurring && _check.dueAt != previousDue) {
          _showMessage(
            'Ejecuci\u00f3n guardada. Pr\u00f3xima fecha: '
            '${controlDueLabel(context, _check.dueAt)}.',
          );
        } else {
          _showMessage('Check completado.');
        }
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reopen() async {
    if (!_canWork || !_check.isCompleted || _check.isRecurring || _loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      _check = await _repository.reopenCheck(_check);
      _changed = true;
      await BackgroundSyncScheduler.scheduleOneOff();
      await _syncAllReminders();
      if (mounted) {
        setState(() {});
        _showMessage('Check reabierto.');
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _delete() async {
    if (!_canEdit || _loading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar check'),
        content: Text(
          'Se eliminar\u00e1 "${_check.title}" y su historial asociado. '
          'Esta operaci\u00f3n se sincronizar\u00e1 con el servidor.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _repository.deleteCheck(_check);
      await BackgroundSyncScheduler.scheduleOneOff();
      await _syncAllReminders();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showMessage(error.toString());
      if (mounted) {
        setState(() => _loading = false);
      }
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
    final stateColor = controlDueColor(context, _check.dueState);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de control'),
          actions: <Widget>[
            if (_canEdit)
              IconButton(
                tooltip: 'Editar',
                onPressed: _loading ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_canEdit)
              PopupMenuButton<String>(
                tooltip: 'M\u00e1s opciones',
                onSelected: (value) {
                  if (value == 'delete') {
                    unawaited(_delete());
                  }
                },
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Eliminar check'),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(
                CheckTapSpacing.md,
                CheckTapSpacing.sm,
                CheckTapSpacing.md,
                120,
              ),
              children: <Widget>[
                _ControlDetailHero(check: _check, stateColor: stateColor),
                const SizedBox(height: CheckTapSpacing.md),
                _InfoCard(
                  title: 'Programaci\u00f3n',
                  children: <Widget>[
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha l\u00edmite',
                      value: controlDueLabel(context, _check.dueAt),
                    ),
                    _DetailRow(
                      icon: Icons.timelapse_rounded,
                      label: 'Estado',
                      value: controlRelativeDueLabel(_check),
                      valueColor: stateColor,
                    ),
                    _DetailRow(
                      icon: Icons.repeat_rounded,
                      label: 'Recurrencia',
                      value: _check.recurrenceLabel,
                    ),
                    _DetailRow(
                      icon: Icons.language_rounded,
                      label: 'Zona horaria',
                      value: _check.timezone,
                    ),
                  ],
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                _InfoCard(
                  title: 'Recordatorios',
                  children: _check.reminderMinutes.isEmpty
                      ? const <Widget>[
                          _DetailRow(
                            icon: Icons.notifications_off_outlined,
                            label: 'Avisos',
                            value: 'Desactivados',
                          ),
                        ]
                      : <Widget>[
                          for (final minutes in _check.reminderMinutes)
                            _DetailRow(
                              icon: Icons.notifications_active_outlined,
                              label: 'Aviso',
                              value: controlReminderLabel(minutes),
                            ),
                          if (nextControlReminder(_check) != null)
                            _DetailRow(
                              icon: Icons.alarm_rounded,
                              label: 'Pr\u00f3ximo aviso',
                              value: controlDueLabel(
                                context,
                                nextControlReminder(_check)!,
                              ),
                              valueColor: CheckTapColors.cyanFor(context),
                            ),
                        ],
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                _InfoCard(
                  title: 'Informaci\u00f3n',
                  children: <Widget>[
                    _DetailRow(
                      icon: Icons.folder_open_rounded,
                      label: 'Secci\u00f3n',
                      value: widget.section.name,
                    ),
                    _DetailRow(
                      icon: Icons.apartment_rounded,
                      label: 'Departamento',
                      value: widget.section.department.name,
                    ),
                    _DetailRow(
                      icon: Icons.flag_outlined,
                      label: 'Prioridad',
                      value: controlPriorityLabel(_check.priority),
                    ),
                    if ((_check.reference ?? '').isNotEmpty)
                      _DetailRow(
                        icon: Icons.link_rounded,
                        label: 'Referencia',
                        value: _check.reference!,
                      ),
                    if ((_check.contact ?? '').isNotEmpty)
                      _DetailRow(
                        icon: Icons.contact_mail_outlined,
                        label: 'Proveedor / contacto',
                        value: _check.contact!,
                      ),
                    if ((_check.description ?? '').isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Descripci\u00f3n',
                        value: _check.description!,
                      ),
                    if ((_check.notes ?? '').isNotEmpty)
                      _DetailRow(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Notas',
                        value: _check.notes!,
                      ),
                  ],
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                _InfoCard(
                  title: 'Responsables',
                  children: <Widget>[
                    if (_check.assignees.isEmpty)
                      const _DetailRow(
                        icon: Icons.groups_2_outlined,
                        label: 'Asignaci\u00f3n',
                        value: 'Todo el departamento',
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: CheckTapSpacing.xs),
                        child: Wrap(
                          spacing: CheckTapSpacing.xs,
                          runSpacing: CheckTapSpacing.xs,
                          children: _check.assignees
                              .map(
                                (user) => Chip(
                                  avatar: UserAvatar.fromUser(user, radius: 12),
                                  label: Text(user.name),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: CheckTapSpacing.lg),
                SectionHeader(
                  title: 'Historial',
                  subtitle: _check.history.isEmpty
                      ? 'Todav\u00eda no hay ejecuciones completadas.'
                      : '${_check.history.length} ejecuci\u00f3n(es) registrada(s).',
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                if (_check.history.isEmpty)
                  const _HistoryEmpty()
                else
                  ..._check.history.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                      child: _HistoryCard(entry: entry),
                    ),
                  ),
              ],
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildActionBar(),
      ),
    );
  }

  Widget? _buildActionBar() {
    if (!_canWork) {
      return null;
    }
    final action = _check.isCompleted
        ? (_check.isRecurring
              ? null
              : FilledButton.icon(
                  onPressed: _loading ? null : _reopen,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reabrir check'),
                ))
        : FilledButton.icon(
            onPressed: _loading ? null : _complete,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _check.isRecurring
                  ? 'Completar y programar siguiente'
                  : 'Marcar como completado',
            ),
          );
    if (action == null) {
      return null;
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: CheckTapColors.surfaceFor(context),
          border: Border(
            top: BorderSide(color: CheckTapColors.borderFor(context)),
          ),
        ),
        child: action,
      ),
    );
  }
}

class _ControlDetailHero extends StatelessWidget {
  const _ControlDetailHero({required this.check, required this.stateColor});

  final ControlCheckItem check;
  final Color stateColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CheckTapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(CheckTapRadius.md),
                  ),
                  child: Icon(
                    check.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.fact_check_outlined,
                    color: stateColor,
                  ),
                ),
                const SizedBox(width: CheckTapSpacing.sm),
                Expanded(
                  child: Text(
                    check.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CheckTapSpacing.md),
            Wrap(
              spacing: CheckTapSpacing.xs,
              runSpacing: CheckTapSpacing.xs,
              children: <Widget>[
                _StatusPill(
                  label: controlDueStateLabel(check.dueState),
                  color: stateColor,
                ),
                _StatusPill(
                  label: controlPriorityLabel(check.priority),
                  color: CheckTapColors.primaryFor(context),
                ),
                if (check.hasPendingChanges)
                  _StatusPill(
                    label: 'Pendiente de sincronizar',
                    color: CheckTapColors.cyanFor(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CheckTapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CheckTapSpacing.xs),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CheckTapSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 19,
            color: CheckTapColors.textMutedFor(context),
          ),
          const SizedBox(width: CheckTapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CheckTapColors.textMutedFor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor == null ? null : FontWeight.w700,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CheckTapRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final ControlCheckHistoryItem entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CheckTapSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, color: CheckTapColors.success),
            const SizedBox(width: CheckTapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Completado ${controlDueLabel(context, entry.completedAt)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: CheckTapSpacing.xxs),
                  Text(
                    'Vencimiento registrado: ${controlDueLabel(context, entry.dueAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (entry.completedBy != null)
                    Text(
                      'Por: ${entry.completedBy!.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if ((entry.completionNotes ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: CheckTapSpacing.xs),
                    Text(entry.completionNotes!),
                  ],
                  if (entry.nextDueAt != null) ...<Widget>[
                    const SizedBox(height: CheckTapSpacing.xs),
                    Text(
                      'Siguiente: ${controlDueLabel(context, entry.nextDueAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.cyanFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: CheckTapColors.surfaceSoftFor(context),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: CheckTapColors.borderFor(context)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.history_rounded,
            color: CheckTapColors.textMutedFor(context),
          ),
          const SizedBox(width: CheckTapSpacing.sm),
          const Expanded(
            child: Text('Las ejecuciones completadas aparecer\u00e1n aqu\u00ed.'),
          ),
        ],
      ),
    );
  }
}
