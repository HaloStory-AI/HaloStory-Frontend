import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF135ACF);
  static const Color brandBlueSoft = Color(0xFFB8D8F8);

  static const Color amoledBlack = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0D0D0D);
  static const Color amoledSurfaceAlt = Color(0xFF141414);
  static const Color amoledBorder = Color(0xFF2A2A2A);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlueSoft,
        primary: brandBlueSoft,
        secondary: brandBlue,
        surface: const Color(0xFFF4F8FB),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F8FB),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: brandBlue,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: brandBlue),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brandBlue,
        unselectedItemColor: Colors.grey,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
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
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme.copyWith(
        surfaceContainerHighest: amoledSurfaceAlt,
        outline: amoledBorder,
      ),
      scaffoldBackgroundColor: amoledBlack,
      canvasColor: amoledBlack,
      dividerColor: amoledBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: amoledBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF7CB3FF),
        unselectedLabelColor: Color(0xFF8F9DB3),
        indicatorColor: Color(0xFF7CB3FF),
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
        fillColor: amoledSurface,
        hintStyle: const TextStyle(color: Color(0xFF8F9DB3)),
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
          borderSide: const BorderSide(color: Color(0xFF7CB3FF), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: amoledSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: amoledSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: amoledSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: amoledSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFD4D4D4),
        textColor: Color(0xFFEDEDED),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: amoledSurfaceAlt,
        contentTextStyle: const TextStyle(color: Color(0xFFEDEDED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: amoledSurface,
        selectedItemColor: Color(0xFF7CB3FF),
        unselectedItemColor: Color(0xFF8F9DB3),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: amoledSurface),
    );
  }
}
