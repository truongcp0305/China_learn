import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens ported from the Broadsheet design system
/// (mobile-app-mockups/project/_ds/.../styles.css).
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF3F2F2);
  static const surface = Color(0xFFEAE9E9);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFF0088B0);
  static const accent2 = Color(0xFFD6006C);
  static const divider = Color(0x29201E1D); // 16% of text color

  static const neutral100 = Color(0xFFF8F4F4);
  static const neutral200 = Color(0xFFEAE7E7);
  static const neutral300 = Color(0xFFD7D3D3);
  static const neutral600 = Color(0xFF7D7979);
  static const neutral700 = Color(0xFF605D5D);
  static const neutral800 = Color(0xFF444141);

  static const accent100 = Color(0xFFE9F8FF);
  static const accent200 = Color(0xFFCBEEFF);
  static const accent700 = Color(0xFF006786);
  static const accent800 = Color(0xFF004961);

  static const accent2_100 = Color(0xFFFFF1F4);
  static const accent2_700 = Color(0xFFAA0B56);
  static const accent2_800 = Color(0xFF790E3D);
}

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;
  final scaffoldBg = isDark ? const Color(0xFF1B1A1A) : AppColors.bg;
  final surfaceBg = isDark ? const Color(0xFF2A2828) : AppColors.surface;
  final textColor = isDark ? const Color(0xFFEDEBEB) : AppColors.text;
  final dividerColor = isDark ? const Color(0x3DEDEBEB) : AppColors.divider;

  final base = GoogleFonts.sourceSerif4TextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);
  final textTheme = base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.015 * 32),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.015 * 26),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(color: textColor),
    bodyMedium: base.bodyMedium?.copyWith(color: textColor),
    bodySmall: base.bodySmall?.copyWith(color: isDark ? const Color(0xFFBFBBBB) : AppColors.neutral700),
  );

  const radius = BorderRadius.all(Radius.circular(2));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: scaffoldBg,
    ),
    textTheme: textTheme,
    fontFamily: GoogleFonts.sourceSerif4().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: dividerColor,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        disabledBackgroundColor: AppColors.accent.withOpacity(0.45),
        textStyle: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 15),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: dividerColor),
        textStyle: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 15),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 15),
        padding: EdgeInsets.zero,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceBg,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: dividerColor)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: dividerColor)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.accent)),
      hintStyle: TextStyle(color: isDark ? const Color(0xFFBFBBBB) : AppColors.neutral700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: radius)),
        side: WidgetStateProperty.all(BorderSide(color: dividerColor)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.bg;
          return textColor;
        }),
        textStyle: WidgetStateProperty.all(GoogleFonts.sourceSerif4(fontSize: 13)),
      ),
    ),
    dividerTheme: DividerThemeData(color: dividerColor, thickness: 1, space: 1),
  );
}
