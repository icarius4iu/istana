import 'package:flutter/material.dart';

/// Paleta y tipografía inspiradas en Spotify.
///
/// Nota: no se distribuye la fuente propietaria "Spotify Circular" (su
/// licencia no permite redistribuirla dentro de otra app). Se usa la familia
/// tipográfica por defecto de Material 3 con los mismos pesos/tamaños, así
/// que el look queda equivalente sin infringir la licencia de la fuente.
class AppTheme {
  AppTheme._();

  // ===== COLORES SPOTIFY =====
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color spotifyGreenDark = Color(0xFF1AA34A);
  static const Color darkBg = Color(0xFF121212);
  static const Color cardBg = Color(0xFF282828);
  static const Color elevatedBg = Color(0xFF3E3E3E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color error = Color(0xFFE91429);

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: spotifyGreen,
    onPrimary: Colors.black,
    secondary: spotifyGreen,
    onSecondary: Colors.black,
    error: error,
    onError: Colors.white,
    surface: cardBg,
    onSurface: textPrimary,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    primaryColor: spotifyGreen,
    scaffoldBackgroundColor: darkBg,
    cardColor: cardBg,
    dividerColor: divider,
    splashColor: spotifyGreen.withValues(alpha: 0.15),
    highlightColor: Colors.transparent,

    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      centerTitle: false,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: spotifyGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),

    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(textPrimary)),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      labelLarge: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textSecondary),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: spotifyGreen,
      inactiveTrackColor: textSecondary.withValues(alpha: 0.3),
      thumbColor: textPrimary,
      trackHeight: 3,
      overlayColor: spotifyGreen.withValues(alpha: 0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: textSecondary,
      textColor: textPrimary,
    ),

    dividerTheme: const DividerThemeData(color: divider, thickness: 1),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: elevatedBg,
      contentTextStyle: TextStyle(color: textPrimary),
      behavior: SnackBarBehavior.floating,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardBg,
      selectedItemColor: textPrimary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
