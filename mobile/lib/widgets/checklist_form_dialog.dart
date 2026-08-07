import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class ChecklistDraft {
  const ChecklistDraft({required this.title, required this.itemTitles});

  final String title;
  final List<String> itemTitles;
}

class ChecklistFormDialog extends StatefulWidget {
  const ChecklistFormDialog({super.key});

  @override
  State<ChecklistFormDialog> createState() => _ChecklistFormDialogState();
}

class _ChecklistFormDialogState extends State<ChecklistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _itemControllers = <TextEditingController>[
    TextEditingController(),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final normalized = FormValidators.normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return 'Ingrese el nombre del checklist.';
    }
    if (normalized.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (normalized.length > 180) {
      return 'El nombre no puede superar 180 caracteres.';
    }
    return null;
  }

  String? _validateItem(String? value) {
    final normalized = FormValidators.normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length < 2) {
      return 'La actividad debe tener al menos 2 caracteres.';
    }
    if (normalized.length > 300) {
      return 'La actividad no puede superar 300 caracteres.';
    }
    return null;
  }

  void _addItemField() {
    if (_itemControllers.length >= 20) {
      return;
    }
    setState(() => _itemControllers.add(TextEditingController()));
  }

  void _removeItemField(int index) {
    if (_itemControllers.length == 1) {
      _itemControllers.first.clear();
      return;
    }
    final controller = _itemControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final title = FormValidators.normalizeSingleLine(_titleController.text);
    final items = _itemControllers
        .map(
          (controller) => FormValidators.normalizeSingleLine(controller.text),
        )
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(ChecklistDraft(title: title, itemTitles: items));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: CheckTapColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(CheckTapRadius.md),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: CheckTapColors.primary,
                      ),
                    ),
                    const SizedBox(width: CheckTapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Nuevo checklist',
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
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del checklist',
                    hintText: 'Ej. Preparación para producción',
                    prefixIcon: Icon(Icons.list_alt_rounded),
                  ),
                  validator: _validateTitle,
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Actividades iniciales',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _itemControllers.length >= 20
                          ? null
                          : _addItemField,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                Text(
                  'Puedes agregarlas ahora o después desde el detalle.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CheckTapColors.textMuted,
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.sm),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _itemControllers.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: CheckTapSpacing.sm),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _itemControllers[index],
                              maxLength: 300,
                              textInputAction:
                                  index == _itemControllers.length - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Actividad ${index + 1}',
                                hintText: 'Describe una acción verificable',
                                prefixIcon: const Icon(
                                  Icons.check_box_outline_blank_rounded,
                                ),
                              ),
                              validator: _validateItem,
                              onFieldSubmitted: (_) {
                                if (index == _itemControllers.length - 1 &&
                                    _itemControllers[index].text
                                        .trim()
                                        .isNotEmpty) {
                                  _addItemField();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: CheckTapSpacing.xs),
                          IconButton(
                            tooltip: 'Quitar actividad',
                            onPressed: () => _removeItemField(index),
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: CheckTapSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions =
                        constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(14) >= 19;
                    final cancel = OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    );
                    final submit = FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Crear checklist'),
                    );
                    if (stackActions) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChecklistTextDialog extends StatefulWidget {
  const ChecklistTextDialog({
    required this.title,
    required this.label,
    required this.submitLabel,
    this.initialValue = '',
    this.maxLength = 300,
    super.key,
  });

  final String title;
  final String label;
  final String submitLabel;
  final String initialValue;
  final int maxLength;

  @override
  State<ChecklistTextDialog> createState() => _ChecklistTextDialogState();
}

class _ChecklistTextDialogState extends State<ChecklistTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validator(String? value) {
    final normalized = FormValidators.normalizeSingleLine(value ?? '');
    if (normalized.isEmpty) {
      return 'Este campo es obligatorio.';
    }
    if (normalized.length < 2) {
      return 'Ingrese al menos 2 caracteres.';
    }
    if (normalized.length > widget.maxLength) {
      return 'No puede superar ${widget.maxLength} caracteres.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(
      context,
    ).pop(FormValidators.normalizeSingleLine(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: widget.label),
          validator: _validator,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
