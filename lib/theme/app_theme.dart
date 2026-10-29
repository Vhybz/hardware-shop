import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class AppTheme {
  static ThemeData getLightTheme(Color primaryColor) {
    final bool isTooLight = primaryColor.computeLuminance() > 0.45;
    final Color effectivePrimary = isTooLight ? const Color(0xFF0F172A) : primaryColor;
    final bool isLightPrimary = effectivePrimary.computeLuminance() > 0.35;
    final bool isMonochromeWhite = primaryColor.toARGB32() == 0xFFFFFFFF;
    final baseTextTheme = ThemeData.light().textTheme;
    final Color onPrimaryColor = Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textDark),
        headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textDark),
        headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textDark),
        titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.textDark),
        titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyLarge: GoogleFonts.plusJakartaSans(color: AppColors.textDark, fontSize: 14),
        bodyMedium: GoogleFonts.plusJakartaSans(color: const Color(0xFF334155), fontSize: 13),
        bodySmall: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 12),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: effectivePrimary,
        primary: effectivePrimary,
        onPrimary: onPrimaryColor,
        secondary: const Color(0xFF0F172A),
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF475569),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        brightness: Brightness.light,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isMonochromeWhite ? Colors.white : primaryColor,
        elevation: isMonochromeWhite ? 1 : 2,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: isMonochromeWhite ? AppColors.textDark : onPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: isMonochromeWhite ? AppColors.textDark : onPrimaryColor),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isMonochromeWhite ? Colors.white : primaryColor,
        surfaceTintColor: Colors.transparent,
        width: 260,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderGray),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        disabledColor: AppColors.borderGray,
        selectedColor: primaryColor.withValues(alpha: 0.15),
        secondarySelectedColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          side: const BorderSide(color: AppColors.borderGray),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textDark, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.08)),
        dataRowColor: WidgetStateProperty.all(Colors.white),
        headingTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13),
        dataTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.textDark, fontSize: 12),
        dividerThickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textLight),
        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textLight.withValues(alpha: 0.6)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isMonochromeWhite ? const Color(0xFF18181B) : primaryColor,
        foregroundColor: isMonochromeWhite ? Colors.white : onPrimaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isMonochromeWhite ? const Color(0xFF18181B) : primaryColor,
          foregroundColor: isMonochromeWhite ? Colors.white : onPrimaryColor,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isMonochromeWhite ? const Color(0xFF18181B) : primaryColor,
          foregroundColor: isMonochromeWhite ? Colors.white : onPrimaryColor,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isMonochromeWhite ? const Color(0xFF18181B) : (isLightPrimary ? const Color(0xFF18181B) : primaryColor),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isMonochromeWhite ? const Color(0xFF18181B) : (isLightPrimary ? const Color(0xFF18181B) : primaryColor),
          side: BorderSide(color: isMonochromeWhite ? const Color(0xFF18181B) : primaryColor),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: BorderSide(color: isMonochromeWhite ? const Color(0xFFCBD5E1) : AppColors.borderGray),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontSize: 14,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: isMonochromeWhite ? const Color(0xFFCBD5E1) : AppColors.borderGray),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF18181B),
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textDark,
        textColor: AppColors.textDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    );
  }

  static ThemeData getDarkTheme(Color primaryColor) {
    const darkBg = Color(0xFF121212); // Onyx High Contrast
    const darkSurface = Color(0xFF1E1E20); // Dark Card Surface
    const darkBorder = Color(0xFF2E2E32); // Dark Border

    final Color effectivePrimary = HSLColor.fromColor(primaryColor)
        .withLightness((HSLColor.fromColor(primaryColor).lightness).clamp(0.25, 0.75))
        .toColor();

    final bool isLightPrimary = effectivePrimary.computeLuminance() > 0.35;
    final Color onPrimaryColor = isLightPrimary ? AppColors.textDark : Colors.white;

    final baseTextTheme = const TextTheme(
      headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFFECEFF1)),
      bodyMedium: TextStyle(color: Color(0xFFB0BEC5)),
      bodySmall: TextStyle(color: Color(0xFF90A4AE)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
        headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
        headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
        titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: effectivePrimary,
        onPrimary: onPrimaryColor,
        secondary: effectivePrimary.withValues(alpha: 0.8),
        surface: darkSurface,
        onSurface: const Color(0xFFFAFAFA),
        onSurfaceVariant: const Color(0xFFB0BEC5),
        surfaceContainerHighest: const Color(0xFF1E1E20),
        brightness: Brightness.dark,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF1E1E20),
        surfaceTintColor: Colors.transparent,
        width: 260,
      ),
      dividerTheme: const DividerThemeData(color: darkBorder),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        disabledColor: darkBorder,
        selectedColor: effectivePrimary.withValues(alpha: 0.25),
        secondarySelectedColor: effectivePrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          side: const BorderSide(color: darkBorder),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(color: effectivePrimary, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(effectivePrimary.withValues(alpha: 0.15)),
        dataRowColor: WidgetStateProperty.all(darkSurface),
        headingTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        dataTextStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFECEFF1), fontSize: 12),
        dividerThickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFB0BEC5),
        textColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFB0BEC5)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF161618),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFB0BEC5)),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF78909C)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: onPrimaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: onPrimaryColor,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }
}
