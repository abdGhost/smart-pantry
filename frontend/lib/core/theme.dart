import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData buildTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryTeal,
        primary: AppColors.primaryTeal,
        secondary: AppColors.accentOrange,
        background: AppColors.creamBackground,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.creamBackground,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final textTheme = base.textTheme;

    final montserratHeadlines = GoogleFonts.montserratTextTheme(textTheme).copyWith(
      headlineLarge: GoogleFonts.montserrat(
        textStyle: textTheme.headlineLarge,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoalText,
      ),
      headlineMedium: GoogleFonts.montserrat(
        textStyle: textTheme.headlineMedium,
        fontWeight: FontWeight.w500,
        color: AppColors.charcoalText,
      ),
      headlineSmall: GoogleFonts.montserrat(
        textStyle: textTheme.headlineSmall,
        fontWeight: FontWeight.w500,
        color: AppColors.charcoalText,
      ),
    );

    final bodyText = GoogleFonts.openSansTextTheme(textTheme).copyWith(
      bodyLarge: GoogleFonts.openSans(
        textStyle: textTheme.bodyLarge,
        color: AppColors.charcoalText,
      ),
      bodyMedium: GoogleFonts.openSans(
        textStyle: textTheme.bodyMedium,
        color: AppColors.charcoalText,
      ),
      bodySmall: GoogleFonts.openSans(
        textStyle: textTheme.bodySmall,
        color: AppColors.charcoalText.withOpacity(0.85),
      ),
    );

    final mergedTextTheme = bodyText.copyWith(
      headlineLarge: montserratHeadlines.headlineLarge,
      headlineMedium: montserratHeadlines.headlineMedium,
      headlineSmall: montserratHeadlines.headlineSmall,
    );

    return base.copyWith(
      textTheme: mergedTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.creamBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: mergedTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoalText,
        ),
        iconTheme: const IconThemeData(color: AppColors.charcoalText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
    );
  }
}

