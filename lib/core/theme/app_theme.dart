import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class AppColors {
  // Ultra-Premium Brand Palette (Urban & Uber Luxury Style)
  static const Color primary = Color(0xFFFFB800); // Electric Amber Gold
  static const Color gold = primary;
  static const Color primaryDark = Color(0xFFF59E0B);
  static const Color accentCyan = Color(0xFF38BDF8); // Sleek secondary accent

  // Deep Obsidian & Slate Background Hierarchy
  static const Color background = Color(0xFF090D16); // Deep Noir Background
  static const Color surface1 = Color(0xFF131B2A);   // Primary Card Surface
  static const Color surface2 = Color(0xFF1E293B);   // Secondary Surface & Inputs
  static const Color surface3 = Color(0xFF2B3A52);   // Elevated Hover / Active Card

  // Precision Hairline Borders & Glass Tinting
  static const Color borderSubtle = Color(0x1F94A3B8); // 12% Slate
  static const Color borderDefault = Color(0x3894A3B8); // 22% Slate
  static const Color borderStrong = Color(0x66FFB800);  // Gold Tint Accent Border

  // High-Contrast Typography Palette
  static const Color textPrimary = Color(0xFFF8FAFC);   // Pure Titanium White
  static const Color textSecondary = Color(0xFFCBD5E1); // Warm Silver
  static const Color textMuted = Color(0xFF94A3B8);     // Subtile Muted Text

  // Crisp Status Colors
  static const Color success = Color(0xFF10B981); // Mint Emerald
  static const Color error = Color(0xFFEF4444);   // Crimson Red
  static const Color info = Color(0xFF3B82F6);    // Electric Blue
  static const Color warning = Color(0xFFF59E0B); // Warm Amber
}

class AppGradients {
  // Ultra-Luxury Gold Button Gradient
  static const Gradient goldButton = LinearGradient(
    colors: [Color(0xFFFFC72C), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Urban Slate Card Gradient
  static const Gradient darkCard = LinearGradient(
    colors: [Color(0xFF182235), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glassmorphic Surface Gradient
  static const Gradient glassSurface = LinearGradient(
    colors: [Color(0x331E293B), Color(0x1A0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero Accent Glow Gradient
  static const Gradient goldGlow = LinearGradient(
    colors: [Color(0x33FFB800), Color(0x00FFB800)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static final List<BoxShadow> goldGlow = [
    const BoxShadow(
      color: Color(0x3DFFB800),
      blurRadius: 24,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> cardElevated = [
    const BoxShadow(
      color: Color(0x99000000),
      blurRadius: 20,
      spreadRadius: -2,
      offset: Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> subtleAmbient = [
    const BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;
}

class AppTextStyles {
  static const TextStyle _base = TextStyle(fontFamily: 'Cairo');

  static final displayLarge = _base.copyWith(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static final displayMedium = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static final headlineLarge = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static final headlineMed = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static final titleLarge = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final titleMed = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final bodyLarge = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static final bodyMed = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final labelLarge = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
  );

  static final labelMed = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );
}

class AppAnimations {
  static CustomTransitionPage fadeSlide({
    required Widget child,
  }) => CustomTransitionPage(
    child: child,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.gold,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.accentCyan,
        surface: AppColors.surface1,
        background: AppColors.background,
        error: AppColors.error,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.surface1,
      dividerColor: AppColors.borderSubtle,
      textTheme: GoogleFonts.cairoTextTheme(Typography.blackCupertino).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.headlineMed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF090D16), // Dark text on gold button
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.xl,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        labelStyle: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface3,
        contentTextStyle: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1,
        modalBackgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }
}
