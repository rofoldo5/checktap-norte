import 'package:flutter/material.dart';

import '../../models/task_checklist.dart';
import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';

class TaskChecklistCard extends StatelessWidget {
  const TaskChecklistCard({
    required this.checklist,
    required this.enabled,
    required this.hideCompleted,
    required this.onToggleHideCompleted,
    required this.onToggleChecklist,
    required this.onToggleItem,
    required this.onAddItem,
    required this.onEditChecklist,
    required this.onDeleteChecklist,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.formatDate,
    super.key,
  });

  final TaskChecklist checklist;
  final bool enabled;
  final bool hideCompleted;
  final VoidCallback onToggleHideCompleted;
  final ValueChanged<bool> onToggleChecklist;
  final void Function(TaskChecklistItem item, bool value) onToggleItem;
  final VoidCallback onAddItem;
  final VoidCallback onEditChecklist;
  final VoidCallback onDeleteChecklist;
  final ValueChanged<TaskChecklistItem> onEditItem;
  final ValueChanged<TaskChecklistItem> onDeleteItem;
  final String Function(DateTime? value) formatDate;

  @override
  Widget build(BuildContext context) {
    final visibleItems = hideCompleted
        ? checklist.items.where((item) => !item.isCompleted).toList()
        : checklist.items;
    final triState = checklist.isCompleted
        ? true
        : checklist.isPartiallyCompleted
        ? null
        : false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        border: Border.all(
          color: checklist.isCompleted
              ? CheckTapColors.success.withValues(alpha: 0.35)
              : CheckTapColors.border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.navy.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  label: checklist.isCompleted
                      ? 'Reabrir checklist ${checklist.title}'
                      : 'Completar checklist ${checklist.title}',
                  child: Checkbox(
                    tristate: true,
                    value: triState,
                    onChanged: enabled
                        ? (_) => onToggleChecklist(!checklist.isCompleted)
                        : null,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        checklist.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              decoration: checklist.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${checklist.completedCount} de ${checklist.itemCount} completadas',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CheckTapColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones del checklist',
                  onSelected: (value) {
                    switch (value) {
                      case 'hide':
                        onToggleHideCompleted();
                        break;
                      case 'edit':
                        onEditChecklist();
                        break;
                      case 'delete':
                        onDeleteChecklist();
                        break;
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'hide',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            hideCompleted
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            hideCompleted
                                ? 'Mostrar completadas'
                                : 'Ocultar completadas',
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Editar nombre'),
                          ],
                        ),
                      ),
                    if (enabled)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.delete_outline_rounded,
                              color: CheckTapColors.danger,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Eliminar checklist',
                              style: TextStyle(color: CheckTapColors.danger),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CheckTapSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: checklist.progress,
                backgroundColor: CheckTapColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  checklist.isCompleted
                      ? CheckTapColors.success
                      : CheckTapColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: CheckTapSpacing.sm),
          if (checklist.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text(
                'Este checklist todavía no tiene actividades.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CheckTapColors.textMuted,
                ),
              ),
            )
          else if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: CheckTapColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Todas las actividades visibles están completadas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in visibleItems)
              _ChecklistItemRow(
                item: item,
                enabled: enabled,
                onToggle: (value) => onToggleItem(item, value),
                onEdit: () => onEditItem(item),
                onDelete: () => onDeleteItem(item),
                formatDate: formatDate,
              ),
          if (enabled) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(CheckTapSpacing.xs),
              child: TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar actividad'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.item,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
  });

  final TaskChecklistItem item;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime? value) formatDate;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.isCompleted
        ? '${item.completedBy?.name ?? 'Usuario'} · ${formatDate(item.completedAt)}'
        : 'Pendiente';
    return InkWell(
      onTap: enabled ? () => onToggle(!item.isCompleted) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: item.isCompleted,
              onChanged: enabled ? (value) => onToggle(value ?? false) : null,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? CheckTapColors.textMuted
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: item.isCompleted
                            ? CheckTapColors.success
                            : CheckTapColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (enabled)
              PopupMenuButton<String>(
                tooltip: 'Opciones de la actividad',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.delete_outline_rounded,
                          color: CheckTapColors.danger,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: CheckTapColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
