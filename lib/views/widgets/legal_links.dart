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

  /// Metni uygulamanın içinde (Custom Tabs / Safari görünümü) açar; kayıt
  /// formu gibi yarım kalan işler kaybolmaz. Olmazsa tarayıcıya geçer.
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
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
