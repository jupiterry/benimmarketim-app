import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../views/widgets/market_palette.dart';

// Renk Paleti (Color Palette)
// Eski ekranların kullandığı adlar korunur; değerler marka paletine bağlıdır.
class AppColors {
  static const Color successGreen = MarketPalette.green;
  static const Color successGreenLight = MarketPalette.greenSoft;
  static const Color successGreenLighter = Color(0xFFF4FAF6);
  static const Color successGreenMedium = Color(0xFFA9DDBE);
  static const Color successGreenDark = MarketPalette.greenDark;

  static const Color errorRed = MarketPalette.red;
  static const Color errorRedLight = MarketPalette.redSoft;
  static const Color errorRedMedium = Color(0xFFF2A1A1);

  static const Color warningOrange = MarketPalette.orangeInk;
  static const Color warningOrangeLight = MarketPalette.orangeSoft;

  static const Color infoBlue = MarketPalette.blue;
  static const Color infoBlueLight = MarketPalette.blueSoft;
}

// Application Theme
class AppThemes {
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MarketPalette.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: MarketPalette.green,
      onPrimary: Colors.white,
      primaryContainer: MarketPalette.greenSoft,
      onPrimaryContainer: MarketPalette.greenDeep,
      secondary: MarketPalette.greenDark,
      secondaryContainer: MarketPalette.limeSoft,
      onSecondaryContainer: MarketPalette.greenDeep,
      tertiary: MarketPalette.lime,
      error: MarketPalette.red,
      surface: MarketPalette.surface,
      onSurface: MarketPalette.ink,
      onSurfaceVariant: MarketPalette.muted,
      outline: MarketPalette.lineStrong,
      outlineVariant: MarketPalette.line,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: MarketPalette.canvas,
      surfaceContainer: MarketPalette.surfaceMuted,
      surfaceContainerHigh: MarketPalette.surfaceMuted,
      surfaceContainerHighest: const Color(0xFFE8ECE8),
    );

    final baseText = GoogleFonts.interTextTheme().apply(
      bodyColor: MarketPalette.ink,
      displayColor: MarketPalette.ink,
    );
    final heading = GoogleFonts.manrope(
      color: MarketPalette.ink,
      fontWeight: FontWeight.w800,
      letterSpacing: -.3,
    );
    final textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.merge(heading),
      headlineMedium: baseText.headlineMedium?.merge(heading),
      headlineSmall: baseText.headlineSmall?.merge(heading),
      titleLarge: baseText.titleLarge?.merge(heading),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MarketRadius.md),
    );
    final buttonText = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarketRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MarketPalette.canvas,
      canvasColor: MarketPalette.canvas,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: MarketPalette.canvas,
        foregroundColor: MarketPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(
          color: MarketPalette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          side: const BorderSide(color: MarketPalette.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MarketPalette.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDCE4DE),
          disabledForegroundColor: MarketPalette.subtle,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarketPalette.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDCE4DE),
          disabledForegroundColor: MarketPalette.subtle,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MarketPalette.greenDark,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: MarketPalette.lineStrong),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MarketPalette.greenDark,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadius.sm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: MarketPalette.ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MarketPalette.green,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(
          color: MarketPalette.subtle,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.inter(color: MarketPalette.muted, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(
          color: MarketPalette.greenDark,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: MarketPalette.muted,
        suffixIconColor: MarketPalette.muted,
        border: inputBorder(MarketPalette.line),
        enabledBorder: inputBorder(MarketPalette.line),
        focusedBorder: inputBorder(MarketPalette.green, 1.6),
        errorBorder: inputBorder(MarketPalette.red),
        focusedErrorBorder: inputBorder(MarketPalette.red, 1.6),
        errorStyle: GoogleFonts.inter(
          color: MarketPalette.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MarketPalette.greenDeep,
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: MarketPalette.lime,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadius.md)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadius.xl)),
        titleTextStyle: GoogleFonts.manrope(
          color: MarketPalette.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: MarketPalette.muted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MarketPalette.canvas,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: MarketPalette.greenSoft,
        side: const BorderSide(color: MarketPalette.line),
        labelStyle: GoogleFonts.inter(
          color: MarketPalette.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadius.sm)),
        checkmarkColor: MarketPalette.greenDark,
      ),
      dividerTheme: const DividerThemeData(
        color: MarketPalette.line,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: MarketPalette.greenDark,
        titleTextStyle: GoogleFonts.inter(
          color: MarketPalette.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: MarketPalette.muted,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : MarketPalette.subtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MarketPalette.green
              : MarketPalette.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : MarketPalette.lineStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MarketPalette.green
              : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MarketPalette.green
              : MarketPalette.subtle,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MarketPalette.green,
        linearTrackColor: MarketPalette.greenSoft,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: MarketPalette.green,
        inactiveTrackColor: MarketPalette.greenSoft,
        thumbColor: MarketPalette.green,
        overlayColor: Color(0x22168A52),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MarketPalette.ink,
          borderRadius: BorderRadius.circular(MarketRadius.sm),
        ),
        textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
