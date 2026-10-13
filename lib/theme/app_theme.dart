import 'package:flutter/material.dart';

/// Spotify-style dark design tokens.
///
/// Surfaces step up from the #121212 base (#1F1F1F, #282828, #2A2A2A); the
/// accent is Spotify's current green (#1ED760); text is white with #B3B3B3
/// for secondary information. Typography uses Figtree (bundled), a geometric
/// sans close to Spotify's own typeface.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Figtree';

  // Core palette
  static const Color spotifyBlack = Color(0xFF121212);
  static const Color spotifyDeepBlack = Color(0xFF000000);
  static const Color spotifyCard = Color(0xFF181818);
  static const Color spotifyCardElevated = Color(0xFF282828);
  static const Color spotifyCardHighlight = Color(0xFF2A2A2A);
  static const Color surfaceRaised = Color(0xFF1F1F1F);

  static const Color spotifyGreen = Color(0xFF1ED760);
  static const Color spotifyGreenLight = Color(0xFF3BE477);
  static const Color spotifyGreenDark = Color(0xFF1AB34F);

  static const Color spotifyWhite = Color(0xFFFFFFFF);
  static const Color spotifyLightGrey = Color(0xFFB3B3B3);
  static const Color spotifySubdued = Color(0xFF7A7A7A);
  static const Color spotifyDivider = Color(0xFF282828);

  // Semantic aliases used across the app
  static const Color bgObsidian = spotifyBlack;
  static const Color bgSurface = spotifyCard;
  static const Color bgSurfaceElevated = spotifyCardElevated;
  static const Color bgSurfaceHover = spotifyCardHighlight;

  static const Color borderSubtle = spotifyDivider;
  static const Color borderMedium = Color(0xFF3E3E3E);
  static const Color borderFocus = spotifyGreen;

  static const Color accentAmber = spotifyGreen;
  static const Color accentAmberLight = spotifyGreenLight;
  static const Color accentAmberDeep = spotifyGreenDark;
  static const Color accentCyan = Color(0xFF2E77D0);
  static const Color accentSuccess = spotifyGreen;
  static const Color accentError = Color(0xFFF3727F);

  static const Color textPrimary = spotifyWhite;
  static const Color textSecondary = spotifyLightGrey;
  static const Color textMuted = spotifySubdued;

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  /// Spotify's "Browse all" style category colours; also used as stand-in
  /// colours for collections without artwork.
  static const List<Color> categoryColors = [
    Color(0xFFE13300),
    Color(0xFF1E3264),
    Color(0xFF8400E7),
    Color(0xFF148A08),
    Color(0xFFE8115B),
    Color(0xFF503750),
    Color(0xFF0D73EC),
    Color(0xFFBA5D07),
    Color(0xFF477D95),
    Color(0xFFAF2896),
    Color(0xFF509BF5),
    Color(0xFF27856A),
    Color(0xFF8D67AB),
    Color(0xFFE91429),
    Color(0xFF777777),
    Color(0xFF7358FF),
  ];

  /// Stable colour for a name (album, genre…) from [categoryColors].
  static Color colorFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return categoryColors[h % categoryColors.length];
  }

  static ThemeData get darkTheme {
    const textTheme = TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: textPrimary),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: textPrimary),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      bodySmall: TextStyle(fontSize: 13, color: textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: spotifyBlack,
      canvasColor: spotifyBlack,
      cardColor: spotifyCard,
      dividerColor: borderSubtle,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: spotifyGreen,
        onPrimary: Colors.black,
        primaryContainer: Color(0xFF1B3D27),
        onPrimaryContainer: spotifyGreenLight,
        secondary: spotifyGreen,
        onSecondary: Colors.black,
        surface: spotifyBlack,
        onSurface: textPrimary,
        surfaceContainerHighest: spotifyCardElevated,
        error: accentError,
        onError: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: spotifyBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: spotifyCardHighlight,
        selectedColor: spotifyGreen,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        secondaryLabelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: spotifyCardElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: spotifyCardElevated, surfaceTintColor: Colors.transparent),
      popupMenuTheme: const PopupMenuThemeData(color: spotifyCardElevated, surfaceTintColor: Colors.transparent),
      listTileTheme: const ListTileThemeData(iconColor: spotifyLightGrey, textColor: textPrimary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: spotifyCardElevated, borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontFamily: fontFamily, color: textPrimary, fontSize: 12),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: spotifyWhite,
        inactiveTrackColor: Color(0x4DFFFFFF),
        thumbColor: spotifyWhite,
        overlayColor: Color(0x22FFFFFF),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: spotifyGreen),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFEDEDED),
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.black, fontWeight: FontWeight.w600),
        actionTextColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        // Float above the mini player and bottom bar.
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 140),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
