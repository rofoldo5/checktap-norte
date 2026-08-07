import 'package:flutter/material.dart';

import 'checktap_colors.dart';
import 'checktap_spacing.dart';

abstract final class CheckTapTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: CheckTapColors.primary,
      brightness: Brightness.light,
      primary: CheckTapColors.primary,
      secondary: CheckTapColors.cyan,
      tertiary: CheckTapColors.teal,
      surface: CheckTapColors.surface,
      error: CheckTapColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: CheckTapColors.background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: CheckTapColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: CheckTapColors.text),
        actionsIconTheme: IconThemeData(color: CheckTapColors.text),
      ),
      cardTheme: CardThemeData(
        color: CheckTapColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.lg),
          side: const BorderSide(color: CheckTapColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CheckTapColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CheckTapColors.surfaceSoft,
        labelStyle: const TextStyle(color: CheckTapColors.textMuted),
        hintStyle: const TextStyle(color: CheckTapColors.textMuted),
        helperStyle: const TextStyle(color: CheckTapColors.textMuted),
        prefixIconColor: CheckTapColors.textMuted,
        suffixIconColor: CheckTapColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CheckTapSpacing.md,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(color: CheckTapColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(color: CheckTapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(
            color: CheckTapColors.primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(color: CheckTapColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(
            color: CheckTapColors.danger,
            width: 1.6,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: CheckTapSpacing.lg,
            vertical: CheckTapSpacing.sm,
          ),
          backgroundColor: CheckTapColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CheckTapColors.borderStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CheckTapRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          foregroundColor: CheckTapColors.primary,
          side: const BorderSide(color: CheckTapColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CheckTapRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CheckTapColors.primary,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CheckTapColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: CheckTapColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE8F0FF),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? CheckTapColors.primary : CheckTapColors.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? CheckTapColors.primary : CheckTapColors.textMuted,
            size: 23,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: CheckTapColors.surface,
        indicatorColor: Color(0xFFE8F0FF),
        selectedIconTheme: IconThemeData(color: CheckTapColors.primary),
        unselectedIconTheme: IconThemeData(color: CheckTapColors.textMuted),
        selectedLabelTextStyle: TextStyle(
          color: CheckTapColors.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: CheckTapColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CheckTapColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CheckTapColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CheckTapColors.surface,
        selectedColor: const Color(0xFFE8F0FF),
        disabledColor: CheckTapColors.border,
        side: const BorderSide(color: CheckTapColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.pill),
        ),
        labelStyle: const TextStyle(
          color: CheckTapColors.text,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CheckTapColors.primary,
        linearTrackColor: Color(0xFFE7ECF4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CheckTapColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: CheckTapColors.cyan,
      brightness: Brightness.dark,
      primary: const Color(0xFF8BB6FF),
      secondary: const Color(0xFF66D8FF),
      tertiary: const Color(0xFF5CE0B3),
      surface: const Color(0xFF152038),
      error: const Color(0xFFFF8585),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0E1628),
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF152038),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.lg),
          side: const BorderSide(color: Color(0xFF273550)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111C31),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(color: Color(0xFF2A3852)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: const BorderSide(color: Color(0xFF2A3852)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CheckTapRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF152038),
        indicatorColor: const Color(0xFF263A61),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
