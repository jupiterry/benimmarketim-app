import 'package:flutter/material.dart';

import 'market_palette.dart';
import 'market_ui.dart' show MarketText;

/// Benim Marketim maskotu (alışveriş sepeti karakteri). Görsel yüklenemezse
/// yerine sepet simgesi gösterilir; ekran bozulmaz.
class MarketMascot extends StatelessWidget {
  static const String asset = 'assets/images/mascot.png';

  final double size;

  const MarketMascot({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    // Görsel 512 px; küçük kullanımlarda bellekte gereğinden büyük tutulmaz
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: pixels < 48 ? 48 : (pixels > 512 ? 512 : pixels),
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.shopping_basket_rounded,
          size: size * .6,
          color: MarketPalette.green,
        ),
      ),
    );
  }
}

/// "benim marketim" yazılı logo. Varsayılan, koyu yeşil zeminler için açık
/// renkli sürümdür; [onLight] verilirse açık zeminler için özgün yeşil sürüm
/// kullanılır. Görsel yüklenemezse marka adı yazıyla gösterilir.
class MarketWordmark extends StatelessWidget {
  static const String asset = 'assets/images/logo_wordmark_white.png';
  static const String assetOnLight = 'assets/images/logo_wordmark.png';

  /// Görselin en-boy oranı (720 × 260).
  static const double aspectRatio = 720 / 260;

  final double height;
  final bool onLight;

  const MarketWordmark({super.key, this.height = 34, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final width = height * aspectRatio;
    final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      onLight ? assetOnLight : asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      cacheWidth: pixels < 96 ? 96 : (pixels > 720 ? 720 : pixels),
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Benim Marketim',
      errorBuilder: (_, __, ___) => Text(
        'Benim Marketim',
        style: MarketText.heading(
          color: onLight ? MarketPalette.greenDark : Colors.white,
          size: height * .46,
        ),
      ),
    );
  }
}
