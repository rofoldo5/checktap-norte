import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/app_user.dart';
import '../models/control_item.dart';
import '../ui/components/section_header.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class ControlCheckDraft {
  const ControlCheckDraft({
    required this.title,
    required this.description,
    required this.reference,
    required this.contact,
    required this.notes,
    required this.priority,
    required this.dueAt,
    required this.timezone,
    required this.reminderMinutes,
    required this.recurrenceType,
    required this.recurrenceInterval,
    required this.recurrenceUnit,
    required this.assignees,
  });

  final String title;
  final String description;
  final String reference;
  final String contact;
  final String notes;
  final String priority;
  final DateTime dueAt;
  final String timezone;
  final List<int> reminderMinutes;
  final String recurrenceType;
  final int recurrenceInterval;
  final String? recurrenceUnit;
  final List<AppUser> assignees;
}

class ControlCheckFormDialog extends StatefulWidget {
  const ControlCheckFormDialog({
    required this.section,
    required this.users,
    this.check,
    super.key,
  });

  final ControlSectionItem section;
  final List<AppUser> users;
  final ControlCheckItem? check;

  @override
  State<ControlCheckFormDialog> createState() =>
      _ControlCheckFormDialogState();
}

class _ControlCheckFormDialogState extends State<ControlCheckFormDialog> {
  static const List<int> _presetReminderMinutes = <int>[
    43200,
    21600,
    10080,
    1440,
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _referenceController;
  late final TextEditingController _contactController;
  late final TextEditingController _notesController;
  late final TextEditingController _customReminderDaysController;
  late final TextEditingController _customIntervalController;
  late String _priority;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late bool _remindersEnabled;
  late Set<int> _selectedReminderMinutes;
  late String _recurrenceType;
  late String _customUnit;
  late Set<String> _selectedAssigneeIds;
  String _timezoneName = 'UTC';
  bool _timezoneLoading = false;

  List<AppUser> get _departmentUsers => widget.users
      .where(
        (user) =>
            user.isActive &&
            user.departmentIds.contains(widget.section.department.id),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final check = widget.check;
    _titleController = TextEditingController(text: check?.title ?? '');
    _descriptionController = TextEditingController(
      text: check?.description ?? '',
    );
    _referenceController = TextEditingController(text: check?.reference ?? '');
    _contactController = TextEditingController(text: check?.contact ?? '');
    _notesController = TextEditingController(text: check?.notes ?? '');
    _priority = check?.priority ?? 'MEDIA';
    final initialDue = check?.dueAt.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    _dueDate = DateTime(initialDue.year, initialDue.month, initialDue.day);
    _dueTime = TimeOfDay.fromDateTime(initialDue);
    _selectedReminderMinutes = Set<int>.of(
      check?.reminderMinutes ?? const <int>[10080, 1440],
    );
    _remindersEnabled = check != null
        ? check.reminderMinutes.isNotEmpty
        : true;
    final customReminder = _selectedReminderMinutes.where(
      (value) => !_presetReminderMinutes.contains(value) && value % 1440 == 0,
    );
    _customReminderDaysController = TextEditingController(
      text: customReminder.isEmpty
          ? ''
          : (customReminder.first ~/ 1440).toString(),
    );
    _recurrenceType = check?.recurrenceType ?? 'NONE';
    _customIntervalController = TextEditingController(
      text: (check?.recurrenceInterval ?? 1).toString(),
    );
    _customUnit = check?.recurrenceUnit ?? 'DAYS';
    _selectedAssigneeIds = check?.assignees.map((user) => user.id).toSet() ??
        <String>{};
    _timezoneName = check?.timezone ?? 'UTC';
    if (check == null) {
      _loadDeviceTimezone();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    _customReminderDaysController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceTimezone() async {
    if (_timezoneLoading) {
      return;
    }
    _timezoneLoading = true;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (!mounted) {
        return;
      }
      setState(() {
        if (info.identifier.trim().isNotEmpty) {
          _timezoneName = info.identifier;
        }
        _timezoneLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _timezoneLoading = false);
      }
    }
  }

  String? _validateTitle(String? value) {
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return 'Ingrese al menos 2 caracteres.';
    }
    if (normalized.length > 180) {
      return 'No puede superar 180 caracteres.';
    }
    return null;
  }

  String? _validateCustomInterval(String? value) {
    if (_recurrenceType != 'CUSTOM') {
      return null;
    }
    final number = int.tryParse((value ?? '').trim());
    if (number == null || number < 1 || number > 365) {
      return 'Use un valor entre 1 y 365.';
    }
    return null;
  }

  String? _validateCustomReminder(String? value) {
    if (!_remindersEnabled || (value ?? '').trim().isEmpty) {
      return null;
    }
    final number = int.tryParse(value!.trim());
    if (number == null || number < 1 || number > 365) {
      return 'Use entre 1 y 365 d\u00edas.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _dueDate = selected);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (selected != null && mounted) {
      setState(() => _dueTime = selected);
    }
  }

  List<int> _buildReminderMinutes() {
    if (!_remindersEnabled) {
      return const <int>[];
    }
    final result = Set<int>.of(_selectedReminderMinutes);
    final customDays = int.tryParse(_customReminderDaysController.text.trim());
    if (customDays != null && customDays > 0) {
      result.add(customDays * 1440);
    }
    final values = result.toList()..sort((a, b) => b.compareTo(a));
    return values;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final dueAt = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
    final interval = _recurrenceType == 'CUSTOM'
        ? int.parse(_customIntervalController.text.trim())
        : 1;
    final usersById = <String, AppUser>{
      for (final user in _departmentUsers) user.id: user,
    };
    final assignees = _selectedAssigneeIds
        .map((id) => usersById[id])
        .whereType<AppUser>()
        .toList(growable: false);

    Navigator.of(context).pop(
      ControlCheckDraft(
        title: _titleController.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        description: _descriptionController.text.trim(),
        reference: _referenceController.text.trim(),
        contact: _contactController.text.trim(),
        notes: _notesController.text.trim(),
        priority: _priority,
        dueAt: dueAt,
        timezone: _timezoneName,
        reminderMinutes: _buildReminderMinutes(),
        recurrenceType: _recurrenceType,
        recurrenceInterval: interval,
        recurrenceUnit: _recurrenceType == 'CUSTOM' ? _customUnit : null,
        assignees: assignees,
      ),
    );
  }

  String _presetReminderLabel(int minutes) {
    switch (minutes) {
      case 43200:
        return '30 d\u00edas antes';
      case 21600:
        return '15 d\u00edas antes';
      case 10080:
        return '7 d\u00edas antes';
      case 1440:
        return '1 d\u00eda antes';
      default:
        return '$minutes min antes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.check != null;
    final locale = MaterialLocalizations.of(context);
    final dateLabel = locale.formatMediumDate(_dueDate);
    final timeLabel = locale.formatTimeOfDay(_dueTime);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 820),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset * 0.06),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CheckTapColors.tealFor(
                          context,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(CheckTapRadius.md),
                      ),
                      child: Icon(
                        Icons.fact_check_outlined,
                        color: CheckTapColors.tealFor(context),
                      ),
                    ),
                    const SizedBox(width: CheckTapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            editing ? 'Editar check' : 'Nuevo check',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            widget.section.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CheckTapColors.textMutedFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: CheckTapSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SectionHeader(
                          title: 'Datos del check',
                          subtitle:
                              'Registra el elemento que quieres vigilar o revisar.',
                        ),
                        const SizedBox(height: CheckTapSpacing.md),
                        TextFormField(
                          controller: _titleController,
                          autofocus: !editing,
                          maxLength: 180,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre / descripci\u00f3n *',
                            hintText: 'Ej. Renovar www.ejemplo.com',
                            prefixIcon: Icon(Icons.task_alt_rounded),
                          ),
                          validator: _validateTitle,
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        TextFormField(
                          controller: _descriptionController,
                          maxLength: 3000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descripci\u00f3n',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stack = constraints.maxWidth < 500;
                            final reference = TextFormField(
                              controller: _referenceController,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Referencia / URL / ubicaci\u00f3n',
                                hintText: 'Ej. www.ejemplo.com o Servidor 01',
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                            );
                            final contact = TextFormField(
                              controller: _contactController,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor / contacto',
                                hintText: 'Ej. GoDaddy / soporte@...',
                                prefixIcon: Icon(Icons.contact_mail_outlined),
                              ),
                            );
                            if (stack) {
                              return Column(
                                children: <Widget>[
                                  reference,
                                  const SizedBox(height: CheckTapSpacing.sm),
                                  contact,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: reference),
                                const SizedBox(width: CheckTapSpacing.sm),
                                Expanded(child: contact),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Prioridad',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                            DropdownMenuItem(
                              value: 'MEDIA',
                              child: Text('Media'),
                            ),
                            DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _priority = value);
                            }
                          },
                        ),
                        const SizedBox(height: CheckTapSpacing.lg),
                        const SectionHeader(
                          title: 'Fecha l\u00edmite',
                          subtitle:
                              'La hora se usa tambi\u00e9n como referencia para los avisos.',
                        ),
                        const SizedBox(height: CheckTapSpacing.md),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stack = constraints.maxWidth < 430;
                            final date = _PickerTile(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fecha',
                              value: dateLabel,
                              onTap: _pickDate,
                            );
                            final time = _PickerTile(
                              icon: Icons.schedule_rounded,
                              label: 'Hora',
                              value: timeLabel,
                              onTap: _pickTime,
                            );
                            if (stack) {
                              return Column(
                                children: <Widget>[
                                  date,
                                  const SizedBox(height: CheckTapSpacing.sm),
                                  time,
                                ],
                              );
                            }
                            return Row(
                              children: <Widget>[
                                Expanded(child: date),
                                const SizedBox(width: CheckTapSpacing.sm),
                                Expanded(child: time),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: CheckTapSpacing.xs),
                        Text(
                          _timezoneLoading
                              ? 'Detectando zona horaria...'
                              : 'Zona horaria: $_timezoneName',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: CheckTapColors.textMutedFor(context),
                          ),
                        ),
                        const SizedBox(height: CheckTapSpacing.lg),
                        const SectionHeader(
                          title: 'Recordatorios',
                          subtitle:
                              'Puedes programar varios avisos antes del vencimiento.',
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _remindersEnabled,
                          onChanged: (value) =>
                              setState(() => _remindersEnabled = value),
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: const Text('Activar recordatorios'),
                          subtitle: const Text(
                            'Los avisos sincronizados se conservan localmente en el tel\u00e9fono.',
                          ),
                        ),
                        if (_remindersEnabled) ...<Widget>[
                          Wrap(
                            spacing: CheckTapSpacing.xs,
                            runSpacing: CheckTapSpacing.xs,
                            children: _presetReminderMinutes.map((minutes) {
                              return FilterChip(
                                selected: _selectedReminderMinutes.contains(
                                  minutes,
                                ),
                                label: Text(_presetReminderLabel(minutes)),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedReminderMinutes.add(minutes);
                                    } else {
                                      _selectedReminderMinutes.remove(minutes);
                                    }
                                  });
                                },
                              );
                            }).toList(growable: false),
                          ),
                          const SizedBox(height: CheckTapSpacing.sm),
                          TextFormField(
                            controller: _customReminderDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Otro recordatorio (d\u00edas antes)',
                              hintText: 'Ej. 45',
                              prefixIcon: Icon(Icons.add_alarm_rounded),
                            ),
                            validator: _validateCustomReminder,
                          ),
                        ],
                        const SizedBox(height: CheckTapSpacing.lg),
                        const SectionHeader(
                          title: 'Recurrencia',
                          subtitle:
                              'Al completar un control recurrente se guarda el historial y se calcula la pr\u00f3xima fecha.',
                        ),
                        const SizedBox(height: CheckTapSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _recurrenceType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Se repite',
                            prefixIcon: Icon(Icons.repeat_rounded),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'NONE',
                              child: Text('No repetir'),
                            ),
                            DropdownMenuItem(
                              value: 'DAILY',
                              child: Text('Todos los d\u00edas'),
                            ),
                            DropdownMenuItem(
                              value: 'WEEKLY',
                              child: Text('Una vez a la semana'),
                            ),
                            DropdownMenuItem(
                              value: 'MONTHLY',
                              child: Text('Una vez al mes'),
                            ),
                            DropdownMenuItem(
                              value: 'YEARLY',
                              child: Text('Una vez al a\u00f1o'),
                            ),
                            DropdownMenuItem(
                              value: 'CUSTOM',
                              child: Text('Personalizado'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _recurrenceType = value);
                            }
                          },
                        ),
                        if (_recurrenceType == 'CUSTOM') ...<Widget>[
                          const SizedBox(height: CheckTapSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: TextFormField(
                                  controller: _customIntervalController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Repetir cada',
                                    prefixIcon: Icon(Icons.numbers_rounded),
                                  ),
                                  validator: _validateCustomInterval,
                                ),
                              ),
                              const SizedBox(width: CheckTapSpacing.sm),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _customUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unidad',
                                  ),
                                  items: const <DropdownMenuItem<String>>[
                                    DropdownMenuItem(
                                      value: 'DAYS',
                                      child: Text('D\u00edas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'WEEKS',
                                      child: Text('Semanas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'MONTHS',
                                      child: Text('Meses'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'YEARS',
                                      child: Text('A\u00f1os'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _customUnit = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: CheckTapSpacing.lg),
                        SectionHeader(
                          title: 'Responsables',
                          subtitle: _departmentUsers.isEmpty
                              ? 'No hay usuarios disponibles en este departamento.'
                              : 'Sin selecci\u00f3n, el control queda visible para todo el departamento.',
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        if (_departmentUsers.isNotEmpty)
                          Wrap(
                            spacing: CheckTapSpacing.xs,
                            runSpacing: CheckTapSpacing.xs,
                            children: _departmentUsers.map((user) {
                              final selected = _selectedAssigneeIds.contains(
                                user.id,
                              );
                              return FilterChip(
                                selected: selected,
                                avatar: UserAvatar.fromUser(user, radius: 14),
                                label: Text(user.name),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedAssigneeIds.add(user.id);
                                    } else {
                                      _selectedAssigneeIds.remove(user.id);
                                    }
                                  });
                                },
                              );
                            }).toList(growable: false),
                          ),
                        const SizedBox(height: CheckTapSpacing.lg),
                        TextFormField(
                          controller: _notesController,
                          maxLength: 5000,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Notas',
                            hintText:
                                'Datos operativos, observaciones o instrucciones adicionales.',
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 380;
                    final cancel = OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    );
                    final save = FilledButton.icon(
                      onPressed: _submit,
                      icon: Icon(editing ? Icons.save_rounded : Icons.add_task),
                      label: Text(editing ? 'Guardar cambios' : 'Guardar check'),
                    );
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          save,
                          const SizedBox(height: CheckTapSpacing.xs),
                          cancel,
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: cancel),
                        const SizedBox(width: CheckTapSpacing.sm),
                        Expanded(flex: 2, child: save),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CheckTapRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}
