import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.primary,
        primary: AdminColors.primary,
        surface: AdminColors.surface,
        error: AdminColors.danger,
        background: AdminColors.background,
      ),
      scaffoldBackgroundColor: AdminColors.background,
      textTheme: TextTheme(
        // Inter for everything
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
        displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminColors.textPrimary, fontSize: 24),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 20),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 18),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 16),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 14),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 12),
        
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: AdminColors.textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: AdminColors.textSecondary, fontSize: 14),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400, color: AdminColors.textSecondary, fontSize: 12),
        
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AdminColors.textPrimary, fontSize: 14),
        labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AdminColors.textPrimary, fontSize: 12),
        labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AdminColors.textSecondary, fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
    );
  }
}
