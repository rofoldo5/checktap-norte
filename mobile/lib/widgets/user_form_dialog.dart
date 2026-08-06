import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../models/app_user.dart';
import '../models/department.dart';

class UserFormValue {
  const UserFormValue({
    required this.name,
    required this.email,
    required this.password,
    required this.isAdmin,
    required this.isActive,
    required this.departmentIds,
  });

  final String name;
  final String? email;
  final String? password;
  final bool isAdmin;
  final bool isActive;
  final List<String> departmentIds;
}

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    required this.departments,
    required this.onSubmit,
    required this.errorMessage,
    this.user,
    this.currentUserId,
    super.key,
  });

  final List<DepartmentSummary> departments;
  final AppUser? user;
  final String? currentUserId;
  final Future<void> Function(UserFormValue value) onSubmit;
  final String Function(Object error) errorMessage;

  bool get isCreate => user == null;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final Set<String> _selectedDepartmentIds;
  late bool _isAdmin;
  late bool _isActive;
  bool _hidePassword = true;
  bool _saving = false;
  String? _serverError;

  bool get _isSelf => widget.user?.id == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _isAdmin = user?.isAdmin ?? false;
    _isActive = user?.isActive ?? true;
    _selectedDepartmentIds = (user?.departmentIds ?? const <String>[])
        .where(
          (id) => widget.departments.any((department) => department.id == id),
        )
        .toSet();
    if (_selectedDepartmentIds.isEmpty && widget.departments.isNotEmpty) {
      _selectedDepartmentIds.add(widget.departments.first.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      final password = _passwordController.text;
      await widget.onSubmit(
        UserFormValue(
          name: FormValidators.normalizeSingleLine(_nameController.text),
          email: widget.isCreate
              ? FormValidators.normalizeEmail(_emailController.text)
              : null,
          password: password.isEmpty ? null : password,
          isAdmin: _isAdmin,
          isActive: _isActive,
          departmentIds: _selectedDepartmentIds.toList(growable: false),
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
    final user = widget.user;
    return AlertDialog(
      title: Text(widget.isCreate ? 'Nuevo usuario' : 'Editar ${user!.name}'),
      content: SizedBox(
        width: 520,
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
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: FormValidators.personName,
                ),
                const SizedBox(height: 12),
                if (widget.isCreate)
                  TextFormField(
                    controller: _emailController,
                    enabled: !_saving,
                    maxLength: 254,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    validator: FormValidators.email,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(user!.email),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_saving,
                  maxLength: 128,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.isCreate
                        ? 'Contraseña inicial'
                        : 'Nueva contraseña (opcional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: _saving
                          ? null
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => FormValidators.password(
                    value,
                    optional: !widget.isCreate,
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Administrador'),
                  subtitle: _isSelf
                      ? const Text(
                          'No puede retirarse este permiso a sí mismo.',
                        )
                      : const Text(
                          'El administrador puede gestionar todos los departamentos.',
                        ),
                  value: _isAdmin,
                  onChanged: _saving || _isSelf
                      ? null
                      : (value) => setState(() => _isAdmin = value),
                ),
                if (!widget.isCreate)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cuenta activa'),
                    subtitle: _isSelf
                        ? const Text('No puede desactivar su propia cuenta.')
                        : null,
                    value: _isActive,
                    onChanged: _saving || _isSelf
                        ? null
                        : (value) => setState(() => _isActive = value),
                  ),
                const Divider(height: 24),
                Text(
                  'Departamentos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'El usuario recibirá los avisos de todos los departamentos seleccionados.',
                ),
                const SizedBox(height: 6),
                FormField<Set<String>>(
                  initialValue: Set<String>.of(_selectedDepartmentIds),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Seleccione al menos un departamento.'
                      : null,
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ...widget.departments.map(
                          (department) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(department.name),
                            subtitle: Text(
                              '${department.memberCount} integrante(s)',
                            ),
                            value: _selectedDepartmentIds.contains(
                              department.id,
                            ),
                            onChanged: _saving
                                ? null
                                : (selected) {
                                    if (selected == true) {
                                      _selectedDepartmentIds.add(department.id);
                                    } else {
                                      _selectedDepartmentIds.remove(
                                        department.id,
                                      );
                                    }
                                    field.didChange(
                                      Set<String>.of(_selectedDepartmentIds),
                                    );
                                  },
                          ),
                        ),
                        if (field.errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
              : Text(widget.isCreate ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}
