import 'package:flutter/material.dart';

/// Firma visual discreta del proyecto CheckTap.
///
/// Se usa únicamente en Login y Dashboard para reconocer la autoría sin
/// competir con las acciones principales de la interfaz.
class DeveloperCredit extends StatelessWidget {
  const DeveloperCredit({
    this.onBrandSurface = false,
    this.alignment = TextAlign.center,
    super.key,
  });

  final bool onBrandSurface;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final color = onBrandSurface
        ? Colors.white.withValues(alpha: 0.78)
        : Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.84);

    return Semantics(
      label: 'Creado: Rodolfo Betancourt',
      child: Text(
        'Creado: Rodolfo Betancourt',
        textAlign: alignment,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
