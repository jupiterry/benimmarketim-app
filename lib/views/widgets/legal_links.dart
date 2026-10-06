import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'market_ui.dart';

/// Web sitesindeki yasal metinlerin adresleri. Metinler tek yerde (web)
/// tutulur; uygulama yalnızca bağlantı verir.
abstract final class LegalLinks {
  static const _base = 'https://devrekbenimmarketim.com';

  static const terms = '$_base/terms';
  static const privacy = '$_base/privacy';
  static const kvkk = '$_base/kvkk';
  static const distanceSales = '$_base/distance-sales';
  static const returnPolicy = '$_base/return-policy';

  static Future<void> open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showMarketSnack(
        context,
        'Sayfa açılamadı. İnternet bağlantını kontrol edip tekrar dene.',
        error: true,
      );
    }
  }
}
