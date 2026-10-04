import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// MediFlow Pro Light Theme — Material 3
class AppTheme {
  AppTheme._();

  // ──────────────────────── LIGHT THEME ────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      error: AppColors.error,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: _buildAppBarTheme(Brightness.light),
      cardTheme: _buildCardTheme(Brightness.light),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(Brightness.light),
      bottomNavigationBarTheme: _buildBottomNavTheme(Brightness.light),
      navigationBarTheme: _buildNavigationBarTheme(Brightness.light),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
      ),
      chipTheme: _buildChipTheme(Brightness.light),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
    );
  }

  // ──────────────────────── DARK THEME ────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.darkBackground,
      secondaryContainer: AppColors.secondaryDark,
      error: AppColors.error,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: _buildAppBarTheme(Brightness.dark),
      cardTheme: _buildCardTheme(Brightness.dark),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(Brightness.dark),
      bottomNavigationBarTheme: _buildBottomNavTheme(Brightness.dark),
      navigationBarTheme: _buildNavigationBarTheme(Brightness.dark),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
      ),
      chipTheme: _buildChipTheme(Brightness.dark),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.darkBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        backgroundColor: AppColors.darkSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
    );
  }

  // ──────────────────────── TEXT THEME ────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? AppColors.lightText
        : AppColors.darkText;
    final secondaryColor = brightness == Brightness.light
        ? AppColors.lightTextSecondary
        : AppColors.darkTextSecondary;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  // ──────────────────────── APP BAR ────────────────────────
  static AppBarTheme _buildAppBarTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      backgroundColor: isLight ? AppColors.lightBackground : AppColors.darkBackground,
      foregroundColor: isLight ? AppColors.lightText : AppColors.darkText,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isLight ? AppColors.lightText : AppColors.darkText,
      ),
      iconTheme: IconThemeData(
        color: isLight ? AppColors.lightText : AppColors.darkText,
      ),
    );
  }

  // ──────────────────────── CARD ────────────────────────
  static CardThemeData _buildCardTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return CardThemeData(
      elevation: 0,
      color: isLight ? AppColors.lightCard : AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: BorderSide(
          color: isLight ? AppColors.lightDivider : AppColors.darkDivider,
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ──────────────────────── ELEVATED BUTTON ────────────────────────
  static ElevatedButtonThemeData _buildElevatedButtonTheme(
      ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────── OUTLINED BUTTON ────────────────────────
  static OutlinedButtonThemeData _buildOutlinedButtonTheme(
      ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
        side: BorderSide(color: colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────── TEXT BUTTON ────────────────────────
  static TextButtonThemeData _buildTextButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────── INPUT DECORATION ────────────────────────
  static InputDecorationTheme _buildInputDecorationTheme(
      Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final borderColor =
        isLight ? AppColors.lightDivider : AppColors.darkDivider;
    final fillColor = isLight ? AppColors.slate50 : AppColors.slate800;

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(
        color: isLight ? AppColors.slate400 : AppColors.slate500,
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: isLight ? AppColors.slate500 : AppColors.slate400,
        fontSize: 14,
      ),
    );
  }

  // ──────────────────────── BOTTOM NAV ────────────────────────
  static BottomNavigationBarThemeData _buildBottomNavTheme(
      Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return BottomNavigationBarThemeData(
      backgroundColor:
          isLight ? AppColors.lightSurface : AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor:
          isLight ? AppColors.slate400 : AppColors.slate500,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );
  }

  // ──────────────────────── NAVIGATION BAR (M3) ────────────────────────
  static NavigationBarThemeData _buildNavigationBarTheme(
      Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return NavigationBarThemeData(
      backgroundColor:
          isLight ? AppColors.lightSurface : AppColors.darkSurface,
      indicatorColor: AppColors.primaryContainer,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    );
  }

  // ──────────────────────── CHIP ────────────────────────
  static ChipThemeData _buildChipTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ChipThemeData(
      backgroundColor: isLight ? AppColors.slate100 : AppColors.slate800,
      selectedColor: AppColors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
  }
}
