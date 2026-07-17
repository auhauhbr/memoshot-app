import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFFEAF2FF);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF086ACB);
  static const secondary = Color(0xFF2B70B7);
  static const textPrimary = Color(0xFF171717);
  static const textSecondary = Color(0xFF5F6368);
  static const border = Color(0xFFD7E1EF);
  static const secondarySurface = Color(0xFFF5F8FC);

  static const _colorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCEBFF),
    onPrimaryContainer: Color(0xFF064C91),
    secondary: secondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE5EFFA),
    onSecondaryContainer: Color(0xFF174D82),
    surface: surface,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outline: Color(0xFFAAB9CC),
    outlineVariant: border,
    surfaceContainerLowest: surface,
    surfaceContainerLow: secondarySurface,
    surfaceContainer: Color(0xFFEDF3FA),
    surfaceContainerHigh: Color(0xFFE6EDF6),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: background,
    dividerColor: border,
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: secondarySurface,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
