import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY BRAND COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF137FEC);
  static const Color primaryLight = Color(0xFF4A9FF0);
  static const Color primaryDark = Color(0xFF0D5FAB);
  static const Color primarySoft = Color(0xFFE8F4FD);

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED ACCENT COLORS (Use these instead of random colors)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color accent1 = Color(0xFF8B5CF6); // Purple - Premium/VIP
  static const Color accent1Light = Color(0xFFEDE9FE);
  static const Color accent2 = Color(0xFF06B6D4); // Cyan - Info/Highlight
  static const Color accent2Light = Color(0xFFCFFAFE);
  static const Color accent3 = Color(0xFFEC4899); // Pink - Special/Featured
  static const Color accent3Light = Color(0xFFFCE7F3);
  static const Color accent4 = Color(0xFFF59E0B); // Amber - Rewards/Points
  static const Color accent4Light = Color(0xFFFEF3C7);
  static const Color accent5 = Color(0xFF10B981); // Emerald - Verified/Active
  static const Color accent5Light = Color(0xFFD1FAE5);

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color backgroundDark = Color(0xFF101922);

  // ═══════════════════════════════════════════════════════════════════════════
  // SURFACE COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1A2332);

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color textPrimaryLight = Color(0xFF111418);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF6B7280);

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME-AWARE COLOR HELPERS (Use these for dark mode support!)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns primary text color based on current theme
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textPrimaryDark 
        : textPrimaryLight;
  }

  /// Returns secondary text color based on current theme
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textSecondaryDark 
        : textSecondaryLight;
  }

  /// Returns tertiary text color based on current theme
  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textTertiaryDark 
        : textTertiaryLight;
  }

  /// Returns surface color based on current theme
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? surfaceDark 
        : surfaceLight;
  }

  /// Returns background color based on current theme
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? backgroundDark 
        : backgroundLight;
  }

  /// Returns border color based on current theme
  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? borderDark 
        : borderLight;
  }

  /// Returns icon color based on current theme (same as textSecondary)
  static Color iconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? textSecondaryDark 
        : textSecondaryLight;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS (Unified across all pages)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF97316);
  static const Color warningLight = Color(0xFFFED7AA);
  static const Color warningDark = Color(0xFFEA580C);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color urgent = Color(0xFFDC2626);
  static const Color neutral = Color(0xFF6B7280);
  static const Color neutralLight = Color(0xFFF3F4F6);

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER & DIVIDER COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASS/FROSTED EFFECT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color glassLight = Color(0xB3FFFFFF); // 70% white
  static const Color glassDark = Color(0x4D1A2332); // 30% dark
  static const Color glassOverlay = Color(0x1AFFFFFF); // 10% white overlay
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white border

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIMMER COLORS (Loading states)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color shimmerBase = Color(0xFFE8E8E8);
  static const Color shimmerHighlight = Color(0xFFF8F8F8);

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED GRADIENTS (Use these across all pages)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary gradient for headers, cards, CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  /// Extended primary gradient for larger areas
  static LinearGradient get primaryGradientExtended => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight, primary.withBlue(230)],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN THEME (Dark, professional look for admin panels)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color adminDark1 = Color(0xFF1a1a2e);
  static const Color adminDark2 = Color(0xFF16213e);
  static const Color adminAccent = Color(0xFF0f3460);
  
  /// Admin header gradient - dark professional look
  static LinearGradient get adminGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [adminDark1, adminDark2, adminAccent],
  );

  /// Success gradient for positive states
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF34D399)],
  );

  /// Warning gradient for attention states
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, Color(0xFFFBBF24)],
  );

  /// Premium/VIP gradient
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent1, Color(0xFFA78BFA)],
  );

  /// Referral/Rewards gradient
  static const LinearGradient rewardsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent3, accent1],
  );

  /// Glass gradient overlay for frosted effects
  static LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
  );

  /// Subtle background gradient for pages
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundLight, backgroundLight, primary.withAlpha(10)],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get fabShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: primary.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> softShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASS DECORATIONS (Frosted/Glassmorphism effects)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Standard glass card decoration
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: glassLight,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: glassBorder),
    boxShadow: glassShadow,
  );

  /// Dark glass card decoration
  static BoxDecoration get glassDarkDecoration => BoxDecoration(
    color: glassDark,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
    boxShadow: glassShadow,
  );

  /// Glass pill decoration for badges/chips
  static BoxDecoration glassChipDecoration({Color? baseColor}) => BoxDecoration(
    color: (baseColor ?? Colors.white).withOpacity(0.2),
    borderRadius: BorderRadius.circular(radiusFull),
    border: Border.all(color: (baseColor ?? Colors.white).withOpacity(0.3)),
  );

  /// Colored glass card decoration
  static BoxDecoration coloredGlassDecoration(Color color) => BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: color.withOpacity(0.2)),
  );

  /// Gradient card with glass overlay
  static BoxDecoration gradientGlassDecoration({
    Gradient? gradient,
    double borderRadius = radiusXl,
  }) => BoxDecoration(
    gradient: gradient ?? primaryGradient,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: fabShadow,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // AVATAR COLORS (Consistent set for user avatars)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Color> avatarColors = [
    primary,
    accent1,
    accent2,
    accent3,
    accent4,
    accent5,
    Color(0xFF6366F1), // Indigo
    Color(0xFF14B8A6), // Teal
  ];

  /// Get consistent avatar color based on string (name, id, etc)
  static Color getAvatarColor(String seed) {
    final index = seed.hashCode.abs() % avatarColors.length;
    return avatarColors[index];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════════════
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: surfaceLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimaryLight,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimaryLight,
            letterSpacing: -0.5,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimaryLight,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimaryLight,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimaryLight,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textSecondaryLight,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondaryLight,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textSecondaryLight,
            letterSpacing: 0.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
        iconTheme: const IconThemeData(color: textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: borderLight),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textSecondaryLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primary,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: surfaceDark,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimaryDark,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimaryDark,
            letterSpacing: -0.5,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimaryDark,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimaryDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimaryDark,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textSecondaryDark,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryDark,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondaryDark,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textSecondaryDark,
            letterSpacing: 0.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        iconTheme: const IconThemeData(color: textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: borderDark),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textSecondaryDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primary,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLOR HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get status color based on status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'awaiting':
        return warning;
      case 'approved':
      case 'completed':
      case 'resolved':
      case 'active':
      case 'verified':
        return success;
      case 'rejected':
      case 'failed':
      case 'error':
      case 'cancelled':
        return error;
      case 'in_progress':
      case 'in-progress':
      case 'inprogress':
      case 'assigned':
      case 'processing':
        return info;
      case 'urgent':
      case 'high':
        return urgent;
      default:
        return neutral;
    }
  }

  /// Get background color for status badges
  static Color getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'awaiting':
        return warningLight;
      case 'approved':
      case 'completed':
      case 'resolved':
      case 'active':
      case 'verified':
        return successLight;
      case 'rejected':
      case 'failed':
      case 'error':
      case 'cancelled':
        return errorLight;
      case 'in_progress':
      case 'in-progress':
      case 'inprogress':
      case 'assigned':
      case 'processing':
        return infoLight;
      case 'urgent':
      case 'high':
        return errorLight;
      default:
        return neutralLight;
    }
  }

  /// Get notification type color
  static Color getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'promotional':
      case 'promo':
        return accent3;
      case 'reminder':
      case 'alert':
        return accent4;
      case 'update':
      case 'info':
        return info;
      case 'success':
        return success;
      case 'warning':
        return warning;
      case 'error':
        return error;
      default:
        return primary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// A reusable glass card widget with frosted glass effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppTheme.radiusLg,
    this.backgroundColor,
    this.blur = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.glassLight,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: AppTheme.glassShadow,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADIENT HEADER DECORATION
// ═══════════════════════════════════════════════════════════════════════════

/// Consistent decorative circles for gradient headers
class HeaderDecoration extends StatelessWidget {
  const HeaderDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(15),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(10),
            ),
          ),
        ),
      ],
    );
  }
}
