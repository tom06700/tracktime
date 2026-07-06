import 'package:flutter/material.dart';

/// Palette reprise de la version web.
abstract final class TtColors {
  static const bg = Color(0xFF0D1017);
  static const surface = Color(0xFF161B26);
  static const surfaceHi = Color(0xFF1F2634);
  static const amber = Color(0xFFF5B942);
  static const teal = Color(0xFF4FD1C5);
  static const dim = Color(0xFF8B93A7);
  static const text = Color(0xFFF2F4F8);
  static const danger = Color(0xFFE5636F);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: TtColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: TtColors.amber,
      onPrimary: Color(0xFF131313),
      secondary: TtColors.teal,
      surface: TtColors.surface,
      onSurface: TtColors.text,
      error: TtColors.danger,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: TtColors.bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: TtColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: const CardThemeData(
      color: TtColors.surface,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TtColors.surface,
      indicatorColor: TtColors.amber.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? TtColors.amber : TtColors.dim,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? TtColors.amber : TtColors.dim,
        );
      }),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: TtColors.amber),
    // Boutons standards restants (dialogues) : coins arrondis cohérents avec
    // le système « verre ». Les actions principales utilisent GlassButton /
    // ProminentGlassButton (lib/widgets/glass.dart).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TtColors.amber,
        foregroundColor: const Color(0xFF131313),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TtColors.amber),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: TtColors.surfaceHi,
      contentTextStyle: TextStyle(color: TtColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
