import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'market_palette.dart';

/// Keeps the status area consistent, including routes without an AppBar.
class MarketSystemFrame extends StatelessWidget {
  const MarketSystemFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: ColoredBox(
        color: MarketPalette.greenDeep,
        child: SafeArea(bottom: false, left: false, right: false, child: child),
      ),
    );
  }
}
