import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/form_validators.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../models/task_recurrence.dart';
import '../ui/components/section_header.dart';
import '../ui/components/user_avatar.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class TaskFormValue {
  const TaskFormValue({
    required this.title,
    required this.description,
    required this.priority,
    required this.department,
    required this.assignees,
    required this.recurrence,
  });

  final String title;
  final String description;
  final String priority;
  final DepartmentSummary department;
  final List<AppUser> assignees;
  final TaskRecurrence recurrence;
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    required this.dialogTitle,
    required this.submitLabel,
    required this.departments,
    required this.users,
    required this.initialDepartmentId,
    required this.onSubmit,
    required this.errorMessage,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialPriority = 'MEDIA',
    this.initialAssigneeIds = const <String>{},
    this.initialRecurrence = TaskRecurrence.none,
    this.recurrenceReadOnly = false,
    super.key,
  });

  final String dialogTitle;
  final String submitLabel;
  final List<DepartmentSummary> departments;
  final List<AppUser> users;
  final String initialDepartmentId;
  final String initialTitle;
  final String initialDescription;
  final String initialPriority;
  final Set<String> initialAssigneeIds;
  final TaskRecurrence initialRecurrence;
  final bool recurrenceReadOnly;
  final Future<void> Function(TaskFormValue value) onSubmit;
  final String Function(Object error) errorMessage;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Set<String> _selectedAssigneeIds;
  late String _departmentId;
  late String _priority;
  late String _recurrencePreset;
  late final TextEditingController _customIntervalController;
  late String _customUnit;
  late DateTime _recurrenceDate;
  late TimeOfDay _recurrenceTime;
  late bool _notificationsEnabled;
  late int _reminderMinutesBefore;
  String _timezoneName = 'UTC';
  bool _timezoneLoading = false;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _departmentId =
        widget.departments.any(
          (department) => department.id == widget.initialDepartmentId,
        )
        ? widget.initialDepartmentId
        : widget.departments.first.id;
    _priority = widget.initialPriority;
    _selectedAssigneeIds = Set<String>.of(widget.initialAssigneeIds);

    final recurrence = widget.initialRecurrence;
    _recurrencePreset = _presetFor(recurrence);
    _customIntervalController = TextEditingController(
      text: recurrence.type == 'CUSTOM' ? recurrence.interval.toString() : '15',
    );
    _customUnit = recurrence.unit ?? 'DAYS';
    final defaultLocal = DateTime.now().add(const Duration(hours: 1));
    final startLocal = recurrence.startAt?.toLocal() ?? defaultLocal;
    _recurrenceDate = DateTime(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    _recurrenceTime = TimeOfDay.fromDateTime(startLocal);
    _notificationsEnabled = recurrence.notificationsEnabled;
    _reminderMinutesBefore = recurrence.reminderMinutesBefore;
    _timezoneName = recurrence.isRecurring ? recurrence.timezone : 'UTC';
    _removeUnavailableAssignees();
    if (!recurrence.isRecurring) {
      _loadDeviceTimezone();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  String _presetFor(TaskRecurrence recurrence) {
    if (!recurrence.isRecurring) {
      return 'NONE';
    }
    if (recurrence.type == 'CUSTOM' &&
        recurrence.interval == 15 &&
        recurrence.unit == 'DAYS') {
      return 'BIWEEKLY';
    }
    return recurrence.type;
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
      } else {
        _timezoneLoading = false;
      }
      // UTC remains a safe fallback if the native timezone cannot be read.
    }
  }

  TaskRecurrence _buildRecurrence() {
    if (widget.recurrenceReadOnly) {
      return widget.initialRecurrence;
    }
    if (_recurrencePreset == 'NONE') {
      return TaskRecurrence(timezone: _timezoneName);
    }

    var type = _recurrencePreset;
    var interval = 1;
    String? unit;
    if (_recurrencePreset == 'BIWEEKLY') {
      type = 'CUSTOM';
      interval = 15;
      unit = 'DAYS';
    } else if (_recurrencePreset == 'CUSTOM') {
      interval = int.tryParse(_customIntervalController.text.trim()) ?? 1;
      unit = _customUnit;
    }

    final localStart = DateTime(
      _recurrenceDate.year,
      _recurrenceDate.month,
      _recurrenceDate.day,
      _recurrenceTime.hour,
      _recurrenceTime.minute,
    );
    return TaskRecurrence(
      type: type,
      interval: interval,
      unit: unit,
      startAt: localStart.toUtc(),
      timezone: _timezoneName,
      notificationsEnabled: _notificationsEnabled,
      reminderMinutesBefore: _notificationsEnabled
          ? _reminderMinutesBefore
          : 0,
      isMaster: true,
      scheduledFor: localStart.toUtc(),
    );
  }

  Future<void> _pickRecurrenceDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recurrenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _recurrenceDate = selected);
    }
  }

  Future<void> _pickRecurrenceTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _recurrenceTime,
    );
    if (selected != null && mounted) {
      setState(() => _recurrenceTime = selected);
    }
  }

  Widget _buildRecurrenceSection(BuildContext context) {
    final disabled = _saving || widget.recurrenceReadOnly;
    final recurring = _recurrencePreset != 'NONE';
    final locale = MaterialLocalizations.of(context);
    final dateLabel = locale.formatMediumDate(_recurrenceDate);
    final timeLabel = locale.formatTimeOfDay(_recurrenceTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
          title: 'Programación y recordatorios',
          subtitle:
              'Repite la tarea conservando cada ejecución y sus subchecks en el historial.',
        ),
        const SizedBox(height: CheckTapSpacing.md),
        if (widget.recurrenceReadOnly) ...<Widget>[
          const _InfoMessage(
            icon: Icons.info_outline_rounded,
            message:
                'Esta es una ejecución generada. La programación se modifica desde la tarea original de la serie.',
          ),
          const SizedBox(height: CheckTapSpacing.md),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey<String>(_recurrencePreset),
          initialValue: _recurrencePreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Repetir tarea',
            prefixIcon: Icon(Icons.repeat_rounded),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'NONE', child: Text('No repetir')),
            DropdownMenuItem(value: 'DAILY', child: Text('Todos los días')),
            DropdownMenuItem(value: 'WEEKLY', child: Text('Una vez a la semana')),
            DropdownMenuItem(value: 'BIWEEKLY', child: Text('Cada 15 días')),
            DropdownMenuItem(value: 'MONTHLY', child: Text('Una vez al mes')),
            DropdownMenuItem(value: 'CUSTOM', child: Text('Personalizado')),
          ],
          onChanged: disabled
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _recurrencePreset = value;
                      if (value == 'NONE') {
                        _notificationsEnabled = false;
                      }
                    });
                  }
                },
        ),
        if (recurring) ...<Widget>[
          const SizedBox(height: CheckTapSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 430;
              final dateField = _SchedulePicker(
                icon: Icons.calendar_today_outlined,
                label: 'Fecha de inicio',
                value: dateLabel,
                enabled: !disabled,
                onTap: _pickRecurrenceDate,
              );
              final timeField = _SchedulePicker(
                icon: Icons.schedule_rounded,
                label: 'Hora',
                value: timeLabel,
                enabled: !disabled,
                onTap: _pickRecurrenceTime,
              );
              if (stack) {
                return Column(
                  children: <Widget>[
                    dateField,
                    const SizedBox(height: CheckTapSpacing.sm),
                    timeField,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: dateField),
                  const SizedBox(width: CheckTapSpacing.sm),
                  Expanded(child: timeField),
                ],
              );
            },
          ),
          if (_recurrencePreset == 'CUSTOM') ...<Widget>[
            const SizedBox(height: CheckTapSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _customIntervalController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repetir cada',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: (value) {
                      if (_recurrencePreset != 'CUSTOM') {
                        return null;
                      }
                      final number = int.tryParse(value?.trim() ?? '');
                      if (number == null || number < 1 || number > 365) {
                        return 'Use un valor de 1 a 365.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: CheckTapSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(_customUnit),
                    initialValue: _customUnit,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'DAYS', child: Text('Días')),
                      DropdownMenuItem(value: 'WEEKS', child: Text('Semanas')),
                      DropdownMenuItem(value: 'MONTHS', child: Text('Meses')),
                    ],
                    onChanged: disabled
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _customUnit = value);
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: CheckTapSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _notificationsEnabled,
            onChanged: disabled
                ? null
                : (value) => setState(() => _notificationsEnabled = value),
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notificar a los responsables'),
            subtitle: const Text(
              'El teléfono conserva los próximos avisos para poder recordarlos también sin conexión.',
            ),
          ),
          if (_notificationsEnabled) ...<Widget>[
            const SizedBox(height: CheckTapSpacing.sm),
            DropdownButtonFormField<int>(
              key: ValueKey<int>(_reminderMinutesBefore),
              initialValue: _reminderMinutesBefore,
              decoration: const InputDecoration(
                labelText: 'Avisar',
                prefixIcon: Icon(Icons.alarm_rounded),
              ),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem(value: 0, child: Text('A la hora programada')),
                DropdownMenuItem(value: 15, child: Text('15 minutos antes')),
                DropdownMenuItem(value: 60, child: Text('1 hora antes')),
                DropdownMenuItem(value: 1440, child: Text('1 día antes')),
              ],
              onChanged: disabled
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _reminderMinutesBefore = value);
                      }
                    },
            ),
          ],
          const SizedBox(height: CheckTapSpacing.sm),
          Text(
            _timezoneLoading
                ? 'Detectando zona horaria…'
                : 'Zona horaria: $_timezoneName',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CheckTapColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  DepartmentSummary? _departmentById(String id) {
    for (final department in widget.departments) {
      if (department.id == id) {
        return department;
      }
    }
    return null;
  }

  List<AppUser> _usersForDepartment(String id) {
    return widget.users
        .where((user) => user.isActive && user.departmentIds.contains(id))
        .toList(growable: false);
  }

  void _removeUnavailableAssignees() {
    final availableIds = _usersForDepartment(
      _departmentId,
    ).map((user) => user.id).toSet();
    _selectedAssigneeIds.removeWhere((id) => !availableIds.contains(id));
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final department = _departmentById(_departmentId);
    if (department == null) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      final availableUsers = _usersForDepartment(_departmentId);
      await widget.onSubmit(
        TaskFormValue(
          title: FormValidators.normalizeSingleLine(_titleController.text),
          description: FormValidators.normalizeMultiline(
            _descriptionController.text,
          ),
          priority: _priority,
          department: department,
          assignees: availableUsers
              .where((user) => _selectedAssigneeIds.contains(user.id))
              .toList(growable: false),
          recurrence: _buildRecurrence(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _serverError = widget.errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final content = _TaskFormContent(
      title: widget.dialogTitle,
      submitLabel: widget.submitLabel,
      formKey: _formKey,
      titleController: _titleController,
      descriptionController: _descriptionController,
      departments: widget.departments,
      departmentId: _departmentId,
      departmentUsers: _usersForDepartment(_departmentId),
      selectedAssigneeIds: _selectedAssigneeIds,
      priority: _priority,
      recurrenceSection: _buildRecurrenceSection(context),
      saving: _saving,
      serverError: _serverError,
      onDepartmentChanged: (value) {
        setState(() {
          _departmentId = value;
          _removeUnavailableAssignees();
        });
      },
      onAssigneeChanged: (id, selected) {
        setState(() {
          if (selected) {
            _selectedAssigneeIds.add(id);
          } else {
            _selectedAssigneeIds.remove(id);
          }
        });
      },
      onPriorityChanged: (value) => setState(() => _priority = value),
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
    );

    if (compact) {
      return Dialog.fullscreen(child: content);
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: content,
      ),
    );
  }
}

class _TaskFormContent extends StatelessWidget {
  const _TaskFormContent({
    required this.title,
    required this.submitLabel,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.departments,
    required this.departmentId,
    required this.departmentUsers,
    required this.selectedAssigneeIds,
    required this.priority,
    required this.recurrenceSection,
    required this.saving,
    required this.serverError,
    required this.onDepartmentChanged,
    required this.onAssigneeChanged,
    required this.onPriorityChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<DepartmentSummary> departments;
  final String departmentId;
  final List<AppUser> departmentUsers;
  final Set<String> selectedAssigneeIds;
  final String priority;
  final Widget recurrenceSection;
  final bool saving;
  final String? serverError;
  final ValueChanged<String> onDepartmentChanged;
  final void Function(String id, bool selected) onAssigneeChanged;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: saving ? null : onCancel,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(title),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: const Border(top: BorderSide(color: CheckTapColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackActions =
                  constraints.maxWidth < 390 ||
                  MediaQuery.textScalerOf(context).scale(14) >= 19;
              final cancel = OutlinedButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancelar'),
              );
              final submit = FilledButton.icon(
                onPressed: saving ? null : onSubmit,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Guardando…' : submitLabel),
              );
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    submit,
                    const SizedBox(height: CheckTapSpacing.xs),
                    cancel,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: cancel),
                  const SizedBox(width: CheckTapSpacing.sm),
                  Expanded(flex: 2, child: submit),
                ],
              );
            },
          ),
        ),
      ),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 360 ? 12 : 16,
            8,
            MediaQuery.sizeOf(context).width < 360 ? 12 : 16,
            160,
          ),
          children: <Widget>[
            const SectionHeader(
              title: 'Información',
              subtitle: 'Define claramente qué necesita el equipo.',
            ),
            const SizedBox(height: CheckTapSpacing.md),
            TextFormField(
              controller: titleController,
              enabled: !saving,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Actualizar servidor principal',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: FormValidators.taskTitle,
            ),
            const SizedBox(height: CheckTapSpacing.sm),
            TextFormField(
              controller: descriptionController,
              enabled: !saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Describe el resultado esperado…',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 76),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
              validator: FormValidators.optionalDescription,
            ),
            const SizedBox(height: CheckTapSpacing.xl),
            const SectionHeader(
              title: 'Organización',
              subtitle: 'El departamento completo recibirá los avisos.',
            ),
            const SizedBox(height: CheckTapSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(departmentId),
              initialValue: departmentId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Departamento',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
              items: departments
                  .map(
                    (department) => DropdownMenuItem<String>(
                      value: department.id,
                      child: Text(department.name),
                    ),
                  )
                  .toList(growable: false),
              validator: (value) {
                if (value == null ||
                    !departments.any((department) => department.id == value)) {
                  return 'Seleccione un departamento válido.';
                }
                return null;
              },
              onChanged: saving
                  ? null
                  : (value) {
                      if (value != null) {
                        onDepartmentChanged(value);
                      }
                    },
            ),
            const SizedBox(height: CheckTapSpacing.md),
            Text('Responsables', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              departmentUsers.isEmpty
                  ? 'Este departamento no tiene integrantes disponibles.'
                  : 'Opcional. Todos los integrantes seguirán recibiendo los avisos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CheckTapColors.textMuted),
            ),
            const SizedBox(height: CheckTapSpacing.sm),
            if (departmentUsers.isEmpty)
              const _InfoMessage(
                icon: Icons.group_off_outlined,
                message: 'La tarea quedará disponible para todo el equipo.',
              )
            else
              Wrap(
                spacing: CheckTapSpacing.xs,
                runSpacing: CheckTapSpacing.xs,
                children: departmentUsers
                    .map((user) {
                      final selected = selectedAssigneeIds.contains(user.id);
                      return FilterChip(
                        selected: selected,
                        showCheckmark: false,
                        avatar: UserAvatar.fromUser(user, radius: 12),
                        label: Text(user.name),
                        onSelected: saving
                            ? null
                            : (value) => onAssigneeChanged(user.id, value),
                      );
                    })
                    .toList(growable: false),
              ),
            const SizedBox(height: CheckTapSpacing.xl),
            const SectionHeader(
              title: 'Prioridad',
              subtitle: 'Ayuda al equipo a identificar qué requiere atención.',
            ),
            const SizedBox(height: CheckTapSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackOptions =
                    constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(14) >= 19;
                final options = <Widget>[
                  _PriorityOption(
                    label: 'Baja',
                    value: 'BAJA',
                    selectedValue: priority,
                    color: CheckTapColors.info,
                    onSelected: saving ? null : onPriorityChanged,
                  ),
                  _PriorityOption(
                    label: 'Media',
                    value: 'MEDIA',
                    selectedValue: priority,
                    color: CheckTapColors.warning,
                    onSelected: saving ? null : onPriorityChanged,
                  ),
                  _PriorityOption(
                    label: 'Alta',
                    value: 'ALTA',
                    selectedValue: priority,
                    color: CheckTapColors.danger,
                    onSelected: saving ? null : onPriorityChanged,
                  ),
                ];
                if (stackOptions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (var index = 0; index < options.length; index++) ...[
                        options[index],
                        if (index < options.length - 1)
                          const SizedBox(height: CheckTapSpacing.xs),
                      ],
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    for (var index = 0; index < options.length; index++) ...[
                      Expanded(child: options[index]),
                      if (index < options.length - 1)
                        const SizedBox(width: CheckTapSpacing.xs),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: CheckTapSpacing.xl),
            recurrenceSection,
            if (serverError != null) ...<Widget>[
              const SizedBox(height: CheckTapSpacing.lg),
              _InfoMessage(
                icon: Icons.error_outline_rounded,
                message: serverError!,
                color: CheckTapColors.danger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchedulePicker extends StatelessWidget {
  const _SchedulePicker({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(CheckTapRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          enabled: enabled,
        ),
        child: Text(value),
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.color,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selectedValue;
  final Color color;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Prioridad $label',
      child: InkWell(
        onTap: onSelected == null ? null : () => onSelected!(value),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.13)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(CheckTapRadius.md),
            border: Border.all(
              color: selected ? color : CheckTapColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? color : CheckTapColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({
    required this.icon,
    required this.message,
    this.color = CheckTapColors.info,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: CheckTapSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
