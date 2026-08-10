import 'package:flutter/material.dart';

import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = CheckTapColors.adaptAccent(context, color);
    final dark = CheckTapColors.isDark(context);

    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CheckTapRadius.lg),
          child: Ink(
            padding: const EdgeInsets.all(CheckTapSpacing.md),
            decoration: BoxDecoration(
              gradient: CheckTapColors.metricGradientFor(context, color),
              borderRadius: BorderRadius.circular(CheckTapRadius.lg),
              border: Border.all(
                color: accent.withValues(alpha: dark ? 0.28 : 0.16),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CheckTapColors.shadowFor(context),
                  blurRadius: dark ? 24 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.13 : 0.10),
                        borderRadius: BorderRadius.circular(CheckTapRadius.sm),
                        border: dark
                            ? Border.all(color: accent.withValues(alpha: 0.12))
                            : null,
                      ),
                      child: Icon(icon, color: accent, size: 19),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: accent,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) => Text(
                    '$animatedValue',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CheckTapColors.textMutedFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
