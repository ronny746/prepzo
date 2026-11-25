import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Source of truth: The Prepzo brand identity
  static const Color primary = Color(0xFF025036); // Prepzo Forest Emerald Green ("prep")
  static const Color secondary = Color(0xFFE5A00D); // Prepzo Vibrant Golden Amber ("zo")
  static const Color accent = Color(0xFFE5A00D); // Prepzo Golden Amber Accent
  static const Color brandGreen = Color(0xFF025036); // Prepzo Primary Mark
  static const Color brandGold = Color(0xFFE5A00D); // Prepzo Accent Gold
  static const Color brandZo = Color(0xFFE5A00D); // Prepzo "zo" Color
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFE5A00D);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(
    0xFFF7FAF8,
  ); // Prepzo Soft Crisp Background
  static const Color surface = Color(0xFFFFFFFF); // Surface White
  static const Color darkBackground = Color(
    0xFF061A13,
  ); // Prepzo Deep Forest Dark Background
  static const Color darkSurface = Color(0xFF0E281F); // Prepzo Deep Forest Surface
  static const Color dividerColor = Color(0x3C3C432F); // iOS thin divider

  static bool isDarkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Main text colour that stays readable in light and dark mode.
  static Color ink(BuildContext context) =>
      isDarkOf(context) ? Colors.white : const Color(0xFF0F172A);

  /// Secondary text (labels, captions).
  static Color inkSoft(BuildContext context) =>
      isDarkOf(context) ? Colors.white70 : const Color(0xFF334155);

  /// Emerald brand text / icons in light mode, amber in dark mode.
  static Color brandInk(BuildContext context) =>
      isDarkOf(context) ? accent : primary;

  /// Card / sheet background.
  static Color card(BuildContext context) =>
      isDarkOf(context) ? darkSurface : Colors.white;

  /// Page background for screens that used a flat slate-50 page.
  static Color page(BuildContext context) =>
      isDarkOf(context) ? darkBackground : const Color(0xFFF8FAFC);

  /// Soft fill for chips, inputs and segmented controls.
  static Color soft(BuildContext context) => isDarkOf(context)
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF1F5F9);

  /// Hairline border.
  static Color line(BuildContext context) => isDarkOf(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFFE2E8F0);

  /// A card or chip colour that may be too dark to read on a dark screen
  /// (e.g. a course's deep emerald theme colour) is swapped for amber there.
  static Color readableAccent(BuildContext context, Color color) {
    if (!isDarkOf(context)) return color;
    return color.computeLuminance() < 0.12 ? accent : color;
  }

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: const Color(0xFF025036),
      tertiary: accent,
      onTertiary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: isDark ? darkSurface : surface,
      onSurface: isDark
          ? Colors.white
          : const Color(0xFF111827), // Text Primary
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBackground : background,
    );

    final interTextTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: interTextTheme.copyWith(
        headlineLarge: interTextTheme.headlineLarge?.copyWith(
          fontSize: 28.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        headlineMedium: interTextTheme.headlineMedium?.copyWith(
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        headlineSmall: interTextTheme.headlineSmall?.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        titleLarge: interTextTheme.titleLarge?.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        titleMedium: interTextTheme.titleMedium?.copyWith(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        bodyLarge: interTextTheme.bodyLarge?.copyWith(
          fontSize: 13.sp,
          height: 1.5,
          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
        ),
        bodyMedium: interTextTheme.bodyMedium?.copyWith(
          fontSize: 12.sp,
          height: 1.45,
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Light screens need dark status-bar icons and vice versa; without this
        // the clock/battery were invisible (QA Step 1 problem 1).
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 18.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface.withValues(alpha: 0.9) : surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64.h,
        backgroundColor: isDark
            ? darkSurface.withValues(alpha: 0.95)
            : surface.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
          fontSize: 12.sp,
        ),
        prefixIconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
        suffixIconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          side: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
      ),
    );
  }
}
