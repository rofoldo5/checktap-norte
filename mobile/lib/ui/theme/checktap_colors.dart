import 'package:flutter/material.dart';

abstract final class CheckTapColors {
  // Identidad principal / modo claro.
  static const Color navy = Color(0xFF172033);
  static const Color navyStrong = Color(0xFF0C1933);
  static const Color primary = Color(0xFF2447A8);
  static const Color primaryStrong = Color(0xFF1545C0);
  static const Color cyan = Color(0xFF17A6D9);
  static const Color teal = Color(0xFF17A673);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF9FBFF);
  static const Color border = Color(0xFFE2E8F2);
  static const Color borderStrong = Color(0xFFD2DBE9);
  static const Color text = Color(0xFF172033);
  static const Color textMuted = Color(0xFF657089);
  static const Color info = Color(0xFF2387D9);
  static const Color success = Color(0xFF17A673);
  static const Color warning = Color(0xFFE59B18);
  static const Color danger = Color(0xFFD64545);

  // Tokens específicos del modo oscuro. Mantienen la identidad azul/cian,
  // pero reducen el aspecto gris/azulado plano del tema anterior.
  static const Color darkBackground = Color(0xFF07111C);
  static const Color darkSurface = Color(0xFF0D1826);
  static const Color darkSurfaceElevated = Color(0xFF111F30);
  static const Color darkSurfaceSoft = Color(0xFF091522);
  static const Color darkBorder = Color(0xFF24364A);
  static const Color darkBorderStrong = Color(0xFF31475E);
  static const Color darkText = Color(0xFFF4F7FB);
  static const Color darkTextMuted = Color(0xFF9DAEC3);
  static const Color darkPrimary = Color(0xFF2F80FF);
  static const Color darkCyan = Color(0xFF1CC7E8);
  static const Color darkTeal = Color(0xFF19C995);
  static const Color darkDanger = Color(0xFFFF5266);
  static const Color darkWarning = Color(0xFFFFB347);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primaryStrong, cyan, Color(0xFF16D0B1)],
  );

  static const LinearGradient quietGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFF2F7FF), Color(0xFFF5FFFD)],
  );

  static const LinearGradient darkQuietGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[darkSurfaceElevated, darkSurfaceSoft],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfaceElevatedFor(BuildContext context) =>
      isDark(context) ? darkSurfaceElevated : surface;

  static Color surfaceSoftFor(BuildContext context) =>
      isDark(context) ? darkSurfaceSoft : surfaceSoft;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color borderStrongFor(BuildContext context) =>
      isDark(context) ? darkBorderStrong : borderStrong;

  static Color textFor(BuildContext context) =>
      isDark(context) ? darkText : text;

  static Color textMutedFor(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color primaryFor(BuildContext context) =>
      isDark(context) ? darkPrimary : primary;

  static Color cyanFor(BuildContext context) =>
      isDark(context) ? darkCyan : cyan;

  static Color tealFor(BuildContext context) =>
      isDark(context) ? darkTeal : teal;

  static Color logoTileFor(BuildContext context) => isDark(context)
      ? darkSurfaceElevated
      : Colors.white.withValues(alpha: 0.86);

  static Color shadowFor(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.28)
      : navy.withValues(alpha: 0.045);

  static LinearGradient quietGradientFor(BuildContext context) =>
      isDark(context) ? darkQuietGradient : quietGradient;

  static Color adaptAccent(BuildContext context, Color color) {
    if (!isDark(context)) {
      return color;
    }
    if (color == primary || color == primaryStrong || color == info) {
      return darkPrimary;
    }
    if (color == cyan) {
      return darkCyan;
    }
    if (color == teal || color == success) {
      return darkTeal;
    }
    if (color == danger) {
      return darkDanger;
    }
    if (color == warning) {
      return darkWarning;
    }
    return color;
  }

  static LinearGradient metricGradientFor(BuildContext context, Color accent) {
    if (!isDark(context)) {
      return const LinearGradient(colors: <Color>[surface, surface]);
    }
    final resolved = adaptAccent(context, accent);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color.alphaBlend(resolved.withValues(alpha: 0.09), darkSurfaceElevated),
        darkSurface,
      ],
    );
  }
}
