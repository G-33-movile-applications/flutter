import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette
  static const Color primaryColor = Color(0xFF86AFEF);
  static const Color cardColor = Color(0xFF9FB3DF);
  static const Color buttonBackgroundColor = Color(0xFFFFF1D5);
  static const Color buttonTextColor = Color(0xFF1F2937);
  static const Color scaffoldBackgroundColor = Color(0xFFF7FAFC);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF1F2937);
  
  static const Color darkPrimaryColor = Color(0xFF5B89D4);
  static const Color darkCardColor = Color(0xFF2C3B52);
  static const Color darkScaffoldBackgroundColor = Color(0xFF121212);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

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
        surface: Colors.white, // Changed from cardColor to white for text fields
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: darkPrimaryColor,
      cardColor: darkCardColor,
      scaffoldBackgroundColor: darkScaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryColor,
        brightness: Brightness.dark,
        primary: darkPrimaryColor,
        surface: darkCardColor,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: darkCardColor,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor,
          foregroundColor: darkTextPrimary,
          elevation: 4,
          shadowColor: Colors.black45,
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

      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: GoogleFonts.poetsenOne(
          color: darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.balsamiqSans(
          color: darkTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.balsamiqSans(
          color: darkTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  static ThemeData getLowPowerTheme(bool isDark) {
    final baseTheme = isDark ? darkTheme : lightTheme;
    
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: (isDark ? darkPrimaryColor : primaryColor).withOpacity(0.7),
        secondary: (isDark ? darkCardColor : cardColor).withOpacity(0.7),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: (baseTheme.elevatedButtonTheme.style ?? ElevatedButton.styleFrom()).copyWith(
          elevation: MaterialStateProperty.all(2),
          animationDuration: const Duration(milliseconds: 0),
        ),
      ),
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: 1,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}