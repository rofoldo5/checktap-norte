import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../models/app_user.dart';
import '../models/department.dart';

class TaskFormValue {
  const TaskFormValue({
    required this.title,
    required this.description,
    required this.priority,
    required this.department,
    required this.assignees,
  });

  final String title;
  final String description;
  final String priority;
  final DepartmentSummary department;
  final List<AppUser> assignees;
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
    _removeUnavailableAssignees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    final departmentUsers = _usersForDepartment(_departmentId);
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(
                    labelText: 'Departamento',
                    helperText: 'Todos sus integrantes recibirán los avisos.',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.departments
                      .map(
                        (department) => DropdownMenuItem<String>(
                          value: department.id,
                          child: Text(department.name),
                        ),
                      )
                      .toList(growable: false),
                  validator: (value) {
                    if (value == null || _departmentById(value) == null) {
                      return 'Seleccione un departamento válido.';
                    }
                    return null;
                  },
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _departmentId = value;
                            _removeUnavailableAssignees();
                          });
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleController,
                  enabled: !_saving,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: FormValidators.taskTitle,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 3000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: FormValidators.optionalDescription,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                    DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                    DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _priority = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                Text(
                  'Responsables opcionales',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'La responsabilidad no limita los avisos: todo el departamento será notificado.',
                ),
                if (departmentUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Este departamento todavía no tiene integrantes activos.',
                    ),
                  )
                else
                  ...departmentUsers.map(
                    (user) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      value: _selectedAssigneeIds.contains(user.id),
                      onChanged: _saving
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedAssigneeIds.add(user.id);
                                } else {
                                  _selectedAssigneeIds.remove(user.id);
                                }
                              });
                            },
                    ),
                  ),
                if (_serverError != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _serverError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
