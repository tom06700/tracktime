import 'package:flutter/material.dart';

import 'widgets/press_response.dart';

/// Surfaces cinéma et accent ivoire commun à tous les parcours.
abstract final class TtColors {
  static const bg = Color(0xFF101113);
  static const surface = Color(0xFF1A1B1F);
  static const surfaceHi = Color(0xFF2B2C33);
  static const amber = Color(0xFFD4F5A0);
  static const teal = Color(0xFFD4F5A0);
  static const dim = Color(0xFFA6A7AE);
  static const text = Color(0xFFF2F3F5);
  static const danger = Color(0xFFE5636F);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    useMaterial3: true,
    scaffoldBackgroundColor: TtColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: TtColors.amber,
      onPrimary: Color(0xFF131313),
      secondary: TtColors.amber,
      surface: TtColors.surface,
      onSurface: TtColors.text,
      error: TtColors.danger,
    ),
  );

  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      iconColor: TtColors.amber,
      textColor: TtColors.text,
      titleTextStyle: TextStyle(
          fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle: TextStyle(
          fontFamily: 'Inter', fontSize: 13, height: 1.5, color: TtColors.dim),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TtColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        foregroundColor: TtColors.amber,
        side: const BorderSide(color: TtColors.surfaceHi),
        shape: const StadiumBorder(),
      ).copyWith(foregroundBuilder: buttonPressResponse),
    ),
    dividerTheme: const DividerThemeData(
      color: TtColors.surfaceHi,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TtColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: const TextStyle(color: TtColors.dim, fontSize: 15),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TtColors.amber),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TtColors.bg,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: TtColors.text,
        fontFamily: 'Inter',
        fontSize: 30,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: const CardThemeData(
      color: TtColors.surface,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
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
        return IconThemeData(color: selected ? TtColors.amber : TtColors.dim);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TtColors.amber,
    ),
    // Boutons standards restants (dialogues) : coins arrondis cohérents avec
    // le système « verre ». Les actions principales utilisent GlassButton /
    // ProminentGlassButton (lib/widgets/glass.dart).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TtColors.amber,
        foregroundColor: const Color(0xFF131313),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ).copyWith(foregroundBuilder: buttonPressResponse),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TtColors.amber)
          .copyWith(foregroundBuilder: buttonPressResponse),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: TtColors.surfaceHi,
      contentTextStyle: TextStyle(color: TtColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
