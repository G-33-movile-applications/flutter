import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette
  static const Color primaryColor = Color(0xFF86AFEF);
  static const Color cardColor = Color(0xFF9FB3DF);
  static const Color buttonBackgroundColor = Color(0xFFF2F4F7);
  static const Color buttonTextColor = Color(0xFF1F2937);
  static const Color scaffoldBackgroundColor = Color(0xFFF7FAFC);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF1F2937);
  
  // Enhanced pharmacy colors for better contrast
  static const Color pharmacyPrimaryBlue = Color(0xFF1565C0);
  static const Color pharmacySuccessGreen = Color(0xFF2E7D32);
  static const Color pharmacyWarningOrange = Color(0xFFE65100);
  static const Color pharmacyErrorRed = Color(0xFFC62828);
  static const Color pharmacyTextDark = Color(0xFF0F172A);
  static const Color pharmacyTextMedium = Color(0xFF475569);
  static const Color pharmacyBackgroundLight = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      cardColor: cardColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: cardColor,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poetsenOne(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),

      // ElevatedButton theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackgroundColor,
          foregroundColor: buttonTextColor,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(88, 48),
          textStyle: GoogleFonts.balsamiqSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        // Headlines use Poetsen One
        headlineLarge: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: GoogleFonts.poetsenOne(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        
        // Body text uses Balsamiq Sans
        bodyLarge: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        bodySmall: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        
        // Labels use Balsamiq Sans
        labelLarge: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelMedium: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.balsamiqSans(
          color: textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}