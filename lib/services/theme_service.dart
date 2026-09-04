import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Renk Paleti (Color Palette)
class AppColors {
  // Success Green (Renk paletinden)
  static const Color successGreen = Color(0xFF00C639);
  static const Color successGreenLight = Color(0xFFEBFFEF);
  static const Color successGreenLighter = Color(0xFFF6FFF8);
  static const Color successGreenMedium = Color(0xFF94F3AA);
  static const Color successGreenDark = Color(0xFF007022);

  // Error Red (Renk paletinden)
  static const Color errorRed = Color(0xFFE43700);
  static const Color errorRedLight = Color(0xFFFFECE6);
  static const Color errorRedMedium = Color(0xFFFF9E80);

  // Warning Orange (Renk paletinden)
  static const Color warningOrange = Color(0xFFCA8E22);
  static const Color warningOrangeLight = Color(0xFFFFF7EA);

  // Info Blue (Renk paletinden)
  static const Color infoBlue = Color(0xFF004CDF);
  static const Color infoBlueLight = Color(0xFFE6EEFF);
}

// Application Theme
class AppThemes {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.successGreen,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
