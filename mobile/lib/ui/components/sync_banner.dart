import 'package:flutter/material.dart';

import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({
    required this.offline,
    required this.pendingOperations,
    required this.lastSyncLabel,
    this.cached = false,
    this.onRetry,
    super.key,
  });

  final bool offline;
  final int pendingOperations;
  final String lastSyncLabel;
  final bool cached;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = offline ? CheckTapColors.danger : CheckTapColors.warning;
    final icon = offline ? Icons.cloud_off_rounded : Icons.sync_rounded;
    final title = offline
        ? 'Sin conexión'
        : pendingOperations > 0
        ? '$pendingOperations cambio(s) pendientes'
        : 'Actualizando datos';
    final detail = offline
        ? 'Puedes seguir trabajando. Sincronizaremos al recuperar la red.'
        : cached
        ? 'Mostrando la información guardada. $lastSyncLabel'
        : lastSyncLabel;

    return Semantics(
      liveRegion: true,
      label: '$title. $detail',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.xs,
          CheckTapSpacing.md,
          0,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CheckTapSpacing.md,
          vertical: CheckTapSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: CheckTapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CheckTapColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              IconButton(
                tooltip: 'Sincronizar ahora',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
