import 'package:flutter/material.dart';

/// Impeccable Design System: Spotify Dark Theme
/// Adheres strictly to craft-floor design rules & Spotify's visual identity:
/// - True Spotify Black (#121212) & Deep Black (#000000)
/// - Iconic Spotify Green (#1DB954) as primary accent
/// - High-contrast white typography (#FFFFFF) & neutral secondary (#B3B3B3)
/// - Strict 4px / 8px spatial grid, 48x48dp touch targets
/// - Borderless elevation cards (#181818, #242424, #2A2A2A)
/// - Directional soft shadows without neon halos
class AppTheme {
  AppTheme._();

  // Spotify Official Palette
  static const Color spotifyBlack = Color(0xFF121212);
  static const Color spotifyDeepBlack = Color(0xFF000000);
  static const Color spotifyCard = Color(0xFF181818);
  static const Color spotifyCardElevated = Color(0xFF242424);
  static const Color spotifyCardHighlight = Color(0xFF2A2A2A);

  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color spotifyGreenLight = Color(0xFF1ED760);
  static const Color spotifyGreenDark = Color(0xFF169C46);

  static const Color spotifyWhite = Color(0xFFFFFFFF);
  static const Color spotifyLightGrey = Color(0xFFB3B3B3);
  static const Color spotifySubdued = Color(0xFF727272);
  static const Color spotifyDivider = Color(0xFF282828);

  // Semantic Aliases for Compatibility
  static const Color bgObsidian = spotifyBlack;
  static const Color bgSurface = spotifyCard;
  static const Color bgSurfaceElevated = spotifyCardElevated;
  static const Color bgSurfaceHover = spotifyCardHighlight;

  static const Color borderSubtle = spotifyDivider;
  static const Color borderMedium = Color(0xFF333333);
  static const Color borderFocus = spotifyGreen;

  // Accents (Spotify Green as primary)
  static const Color accentAmber = spotifyGreen;
  static const Color accentAmberLight = spotifyGreenLight;
  static const Color accentAmberDeep = spotifyGreenDark;
  static const Color accentCyan = Color(0xFF2E77D0);
  static const Color accentSuccess = spotifyGreen;
  static const Color accentError = Color(0xFFE91429);

  // Typography
  static const Color textPrimary = spotifyWhite;
  static const Color textSecondary = spotifyLightGrey;
  static const Color textMuted = spotifySubdued;

  // Spotify Soft Ambient Shadows
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x66000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: spotifyBlack,
      canvasColor: spotifyBlack,
      cardColor: spotifyCard,
      dividerColor: borderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: spotifyGreen,
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF1B3D27),
        onPrimaryContainer: spotifyGreenLight,
        secondary: spotifyGreen,
        onSecondary: Color(0xFF000000),
        surface: spotifyCard,
        onSurface: textPrimary,
        error: accentError,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: spotifyDeepBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: spotifyGreen,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: spotifyCardElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderMedium),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: spotifyGreen,
        inactiveTrackColor: Color(0xFF4D4D4D),
        thumbColor: spotifyWhite,
        overlayColor: Color(0x291DB954),
        trackHeight: 3.5,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: spotifyCardElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
