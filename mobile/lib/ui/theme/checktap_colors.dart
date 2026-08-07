import 'package:flutter/material.dart';

abstract final class CheckTapColors {
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
}
