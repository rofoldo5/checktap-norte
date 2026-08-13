import 'package:flutter/material.dart';

import '../models/control_item.dart';
import '../models/department.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class ControlSectionDraft {
  const ControlSectionDraft({
    required this.name,
    required this.description,
    required this.iconKey,
    required this.department,
  });

  final String name;
  final String description;
  final String iconKey;
  final DepartmentSummary department;
}

class ControlSectionFormDialog extends StatefulWidget {
  const ControlSectionFormDialog({
    required this.departments,
    this.section,
    this.initialDepartmentId,
    super.key,
  });

  final List<DepartmentSummary> departments;
  final ControlSectionItem? section;
  final String? initialDepartmentId;

  @override
  State<ControlSectionFormDialog> createState() =>
      _ControlSectionFormDialogState();
}

class _ControlSectionFormDialogState extends State<ControlSectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _iconKey;
  String? _departmentId;

  static const Map<String, IconData> _icons = <String, IconData>{
    'folder': Icons.folder_open_rounded,
    'globe': Icons.public_rounded,
    'server': Icons.dns_rounded,
    'daily': Icons.today_rounded,
    'maintenance': Icons.handyman_rounded,
    'security': Icons.security_rounded,
    'license': Icons.badge_rounded,
    'cloud': Icons.cloud_outlined,
    'storage': Icons.storage_rounded,
    'devices': Icons.devices_other_rounded,
  };

  static const Map<String, String> _iconLabels = <String, String>{
    'folder': 'General',
    'globe': 'Dominios / web',
    'server': 'Servidores',
    'daily': 'Diario',
    'maintenance': 'Mantenimiento',
    'security': 'Seguridad',
    'license': 'Licencias',
    'cloud': 'Nube',
    'storage': 'Almacenamiento',
    'devices': 'Equipos',
  };

  @override
  void initState() {
    super.initState();
    final section = widget.section;
    _nameController = TextEditingController(text: section?.name ?? '');
    _descriptionController = TextEditingController(
      text: section?.description ?? '',
    );
    _iconKey = _icons.containsKey(section?.iconKey)
        ? section!.iconKey
        : 'folder';
    final requested = section?.department.id ?? widget.initialDepartmentId;
    _departmentId = widget.departments.any((item) => item.id == requested)
        ? requested
        : (widget.departments.isEmpty ? null : widget.departments.first.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return 'Ingrese al menos 2 caracteres.';
    }
    if (normalized.length > 120) {
      return 'No puede superar 120 caracteres.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _departmentId == null) {
      return;
    }
    final department = widget.departments.firstWhere(
      (item) => item.id == _departmentId,
    );
    Navigator.of(context).pop(
      ControlSectionDraft(
        name: _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        description: _descriptionController.text.trim(),
        iconKey: _iconKey,
        department: department,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.section != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset * 0.08),
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
                        color: CheckTapColors.cyanFor(
                          context,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(CheckTapRadius.md),
                      ),
                      child: Icon(
                        _icons[_iconKey],
                        color: CheckTapColors.cyanFor(context),
                      ),
                    ),
                    const SizedBox(width: CheckTapSpacing.sm),
                    Expanded(
                      child: Text(
                        editing ? 'Editar secci\u00f3n' : 'Nueva secci\u00f3n',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: CheckTapSpacing.lg),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _nameController,
                          autofocus: !editing,
                          maxLength: 120,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            hintText: 'Ej. Dominios, Servidores, Mantenimientos',
                            prefixIcon: Icon(Icons.folder_open_rounded),
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        TextFormField(
                          controller: _descriptionController,
                          maxLength: 2000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descripci\u00f3n',
                            hintText: 'Explica qu\u00e9 se controla en esta secci\u00f3n.',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: CheckTapSpacing.sm),
                        DropdownButtonFormField<String>(
                          initialValue: _departmentId,
                          decoration: const InputDecoration(
                            labelText: 'Departamento *',
                            prefixIcon: Icon(Icons.apartment_rounded),
                          ),
                          items: widget.departments
                              .map(
                                (department) => DropdownMenuItem<String>(
                                  value: department.id,
                                  child: Text(department.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) =>
                              setState(() => _departmentId = value),
                          validator: (value) => value == null
                              ? 'Seleccione un departamento.'
                              : null,
                        ),
                        const SizedBox(height: CheckTapSpacing.md),
                        Text(
                          'Icono',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: CheckTapSpacing.xs),
                        Wrap(
                          spacing: CheckTapSpacing.xs,
                          runSpacing: CheckTapSpacing.xs,
                          children: _icons.entries.map((entry) {
                            final selected = entry.key == _iconKey;
                            return ChoiceChip(
                              selected: selected,
                              avatar: Icon(entry.value, size: 18),
                              label: Text(_iconLabels[entry.key]!),
                              onSelected: (_) =>
                                  setState(() => _iconKey = entry.key),
                            );
                          }).toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: CheckTapSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          editing ? Icons.save_rounded : Icons.add_rounded,
                        ),
                        label: Text(editing ? 'Guardar cambios' : 'Crear secci\u00f3n'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
