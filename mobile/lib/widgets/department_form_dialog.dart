import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../models/app_user.dart';

class DepartmentFormValue {
  const DepartmentFormValue({
    required this.name,
    required this.isActive,
    required this.memberIds,
  });

  final String name;
  final bool isActive;
  final List<String> memberIds;
}

class DepartmentFormDialog extends StatefulWidget {
  const DepartmentFormDialog({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.errorMessage,
    this.initialName = '',
    this.initialIsActive = true,
    this.users = const <AppUser>[],
    this.initialMemberIds = const <String>{},
    this.showMembers = false,
    super.key,
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final bool initialIsActive;
  final List<AppUser> users;
  final Set<String> initialMemberIds;
  final bool showMembers;
  final Future<void> Function(DepartmentFormValue value) onSubmit;
  final String Function(Object error) errorMessage;

  @override
  State<DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final Set<String> _selectedMemberIds;
  late bool _isActive;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedMemberIds = Set<String>.of(widget.initialMemberIds);
    _isActive = widget.initialIsActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      await widget.onSubmit(
        DepartmentFormValue(
          name: FormValidators.normalizeSingleLine(_nameController.text),
          isActive: _isActive,
          memberIds: _selectedMemberIds.toList(growable: false),
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: widget.showMembers ? 520 : 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del departamento',
                    border: OutlineInputBorder(),
                  ),
                  validator: FormValidators.departmentName,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (widget.showMembers) ...<Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Departamento activo'),
                    subtitle: const Text(
                      'Los departamentos inactivos no pueden recibir tareas nuevas.',
                    ),
                    value: _isActive,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isActive = value),
                  ),
                  const Divider(height: 28),
                  Text(
                    'Integrantes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Todos los integrantes activos reciben los avisos de las tareas del departamento.',
                  ),
                  const SizedBox(height: 8),
                  if (widget.users.isEmpty)
                    const Text('No hay usuarios disponibles.')
                  else
                    ...widget.users.map(
                      (user) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(user.name),
                        subtitle: Text(
                          '${user.email} · ${user.isActive ? 'Activo' : 'Inactivo'}',
                        ),
                        value: _selectedMemberIds.contains(user.id),
                        onChanged: _saving || !user.isActive
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedMemberIds.add(user.id);
                                  } else {
                                    _selectedMemberIds.remove(user.id);
                                  }
                                });
                              },
                      ),
                    ),
                ],
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
