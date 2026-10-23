import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00BFA5); // Teal A700
  static const Color secondaryColor = Color(0xFF536DFE); // Indigo Accent 200
  static const Color backgroundColor = Color(0xFFF5F7FA); // Very Light Blue/Grey
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFD32F2F);
  
  static const Color textPrimary = Color(0xFF1E293B); // Blue Grey 900
  static const Color textSecondary = Color(0xFF64748B); // Blue Grey 500

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto', // Defaulting to Roboto, can be changed
      appBarTheme: const AppBarTheme(
        backgroundColor: secondaryColor, // Use secondary for AppBar to pop
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      /* cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ), */
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surfaceColor,
        hourMinuteShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: primaryColor, width: 2),
        ),
        dayPeriodBorderSide: const BorderSide(color: primaryColor, width: 2),
        dayPeriodColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryColor.withOpacity(0.2) : Colors.transparent),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryColor : textSecondary),
        dayPeriodShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: primaryColor),
        ),
        hourMinuteColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryColor.withOpacity(0.1) : surfaceColor),
        hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryColor : textPrimary),
        dialHandColor: primaryColor,
        dialBackgroundColor: backgroundColor,
        hourMinuteTextStyle: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        dayPeriodTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        helpTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textSecondary,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(0),
        ),
        dialTextColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected) ? Colors.white : textPrimary),
        entryModeIconColor: primaryColor,
      ),
    );
  }
}
