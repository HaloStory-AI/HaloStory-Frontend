import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF135ACF);
  static const Color brandBlueSoft = Color(0xFFB8D8F8);

  /// MomoTalk-style mobile / desktop rail (light theme only — dark uses [ColorScheme.surface]).
  static const Color momoLightTopBar = Color(0xFF8DC5FF);
  static const Color momoRailBackground = Color(0xFF4C5B72);
  static const Color momoRailSelected = Color(0xFF627089);

  static const Color botBubbleLight = Color(0xFFE8F0FE);
  static const Color botBubbleDark = Color(0xFF1E1E2E);

  static const Color amoledBlack = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0D0D0D);
  static const Color amoledSurfaceAlt = Color(0xFF141414);
  static const Color amoledBorder = Color(0xFF2A2A2A);

  static ThemeData lightTheme() {
    const lightColorScheme = ColorScheme.light(
      primary: brandBlue,
      onPrimary: Colors.white,
      secondary: brandBlueSoft,
      onSecondary: Color(0xFF0F172A),
      surface: Color(0xFFF4F8FB),
      onSurface: Color(0xFF1F2937),
      onSurfaceVariant: Color(0xFF5F6B7A),
      outline: Color(0xFFD5DEE8),
      outlineVariant: Color(0xFFE3EAF2),
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final scheme = lightColorScheme.copyWith(
      surfaceContainer: Colors.white,
      surfaceContainerHighest: const Color.fromARGB(76, 91, 114, 209),
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        brightness: Brightness.light,
      ).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: scheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: scheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surfaceContainer),
    );
  }

  static ThemeData amoledTheme() {
    const darkColorScheme = ColorScheme.dark(
      primary: Color(0xFF7CB3FF),
      onPrimary: Colors.black,
      secondary: Color(0xFF90BFFF),
      onSecondary: Colors.black,
      surface: amoledSurface,
      onSurface: Color(0xFFEDEDED),
      onSurfaceVariant: Color(0xFF9CA8BC),
      outlineVariant: Color(0xFF1C1C1C),
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
    );

    final scheme = darkColorScheme.copyWith(
      surfaceContainer: amoledSurface,
      surfaceContainerHighest: amoledSurfaceAlt,
      outline: amoledBorder,
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        brightness: Brightness.dark,
      ).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: amoledBlack,
      canvasColor: amoledBlack,
      dividerColor: amoledBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: amoledBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A6FDF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amoledBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amoledBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: const Color(0xFFCFDDF0),
        textColor: scheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: amoledSurfaceAlt,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
    );
  }
}
