import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';

/// Google Maps anahtarı ve hangi harita sağlayıcısının kullanılacağı.
///
/// Anahtar repoya yazılmaz; derlemede verilir:
/// `flutter run --dart-define=MAPS_API_KEY=...` (ya da
/// `--dart-define-from-file=secrets.json`). Aynı değer Android'de
/// `android/app/build.gradle.kts` ile manifest'e, iOS'ta [initialize] ile
/// `GMSServices`'e geçer.
///
/// Anahtar yoksa uygulama çökmez: harita OpenStreetMap, adres arama
/// Nominatim ile çalışır.
abstract final class MapsConfig {
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY');

  /// Testlerde Google yolunu denemek için.
  @visibleForTesting
  static String? debugApiKey;

  static String get apiKey => debugApiKey ?? _apiKey;

  /// Google Maps + Places + Geocoding kullanılır mı?
  static bool get useGoogle => apiKey.isNotEmpty;

  static const _channel = MethodChannel('benimmarketim/maps');

  /// iOS'ta Google Maps SDK'ya anahtarı verir (harita açılmadan önce,
  /// açılışta bir kez). Android anahtarı manifest'ten okur.
  static Future<void> initialize() async {
    if (!useGoogle || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setApiKey', apiKey);
    } catch (e) {
      AppLogger.debug('Google Maps anahtarı verilemedi: $e');
    }
  }
}
