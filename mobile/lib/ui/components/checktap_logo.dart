import 'package:flutter/material.dart';

import '../theme/checktap_colors.dart';

class CheckTapLogo extends StatelessWidget {
  const CheckTapLogo({
    this.width = 188,
    this.semanticLabel = 'Logo CheckTap',
    super.key,
  });

  final double width;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Image.asset(
        'assets/branding/checktap_logo.png',
        width: width,
        cacheWidth: cacheWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const _FallbackMark(),
      ),
    );
  }
}

class CheckTapWordmark extends StatelessWidget {
  const CheckTapWordmark({
    this.fontSize = 20,
    this.centered = false,
    super.key,
  });

  final double fontSize;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.2,
    );
    return Semantics(
      header: true,
      label: 'CheckTap',
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'CHECK',
              style: style?.copyWith(
                color: CheckTapColors.isDark(context)
                    ? CheckTapColors.darkText
                    : CheckTapColors.primary,
              ),
            ),
            TextSpan(
              text: 'TAP',
              style: style?.copyWith(
                color: CheckTapColors.isDark(context)
                    ? CheckTapColors.darkCyan
                    : CheckTapColors.teal,
              ),
            ),
          ],
        ),
        textAlign: centered ? TextAlign.center : TextAlign.start,
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: CheckTapColors.brandGradient,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.done_all_rounded, color: Colors.white, size: 40),
      ),
    );
  }
}
