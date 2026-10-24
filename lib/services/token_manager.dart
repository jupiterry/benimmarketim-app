import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_logger.dart';

/// Oturum token'ları (Secure Storage).
///
/// Okumalar hiçbir zaman hata fırlatmaz: Android otomatik yedeği şifreli
/// kaydı geri getirip Keystore anahtarını getirmezse kayıt çözülemez ve her
/// okuma [PlatformException] verir. Bu durumda bozuk token kayıtları silinir
/// ve null döner (kullanıcı bir kez yeniden giriş yapar). Depo yanıt
/// vermezse [readTimeout] sonunda null döner (kayıt silinmez). Böylece token
/// okuyan hiçbir istek askıda kalmaz.
class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenSavedDateKey = 'token_saved_date';

  static const _keys = [_accessTokenKey, _refreshTokenKey, _tokenSavedDateKey];

  // Secure Storage instance
  static const _secureStorage = FlutterSecureStorage();

  /// Depo bu sürede yanıt vermezse okuma null döner.
  static Duration readTimeout = const Duration(seconds: 5);

  static Future<String?> _read(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(readTimeout);
    } on TimeoutException {
      AppLogger.debug('Secure Storage okuması zaman aşımına uğradı ($key)');
      return null;
    } on PlatformException catch (e) {
      // Çözülemeyen (bozuk) kayıt: silinir, kullanıcı yeniden giriş yapar.
      AppLogger.debug(
          'Secure Storage okunamadı ($key), token\'lar siliniyor: $e');
      await _deleteKeys();
      return null;
    } catch (e) {
      AppLogger.debug('Secure Storage okunamadı ($key): $e');
      return null;
    }
  }

  /// Bu sınıfın yazdığı anahtarları siler; hata fırlatmaz.
  static Future<void> _deleteKeys() async {
    for (final key in _keys) {
      try {
        await _secureStorage.delete(key: key).timeout(readTimeout);
      } catch (e) {
        AppLogger.debug('Secure Storage kaydı silinemedi ($key): $e');
      }
    }
  }

  // SharedPreferences'ı başlat (Artık kullanılmıyor ama uyumluluk için boş bırakıyoruz)
  static Future<void> init() async {
    AppLogger.debug('TokenManager başlatıldı (Secure Storage)');
  }

  // Access token kaydetme (Secure Storage). Oturum süresi sunucudaki access
  // token + refresh token akışıyla yönetilir; burada süre sınırı yoktur.
  // [isPhoneLogin] eski çağrılarla uyumluluk için tutulur.
  static Future<void> saveAccessToken(
    String token, {
    bool isPhoneLogin = false,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    await _secureStorage.write(
      key: _tokenSavedDateKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  // Access token alma (Secure Storage)
  static Future<String?> getAccessToken() => _read(_accessTokenKey);

  // Refresh token kaydetme (Secure Storage)
  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  // Refresh token alma (Secure Storage)
  static Future<String?> getRefreshToken() => _read(_refreshTokenKey);

  // Token kayıt tarihini alma
  static Future<DateTime?> getTokenSavedDate() async {
    final dateString = await _read(_tokenSavedDateKey);
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        AppLogger.debug('Token kayıt tarihi parse edilemedi: $e');
        return null;
      }
    }
    return null;
  }

  // Yerel olarak token var mı? (Süre kontrolü yapılmaz; süresi dolan access
  // token sunucuda 401 verir ve refresh token ile yenilenir.)
  static Future<bool> isTokenValid() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Tüm token'ları temizle (hata fırlatmaz)
  static Future<void> clearAllTokens() async {
    // Yalnızca bu sınıfın yazdığı anahtarları sil.
    await _deleteKeys();
    AppLogger.debug('Tüm token\'lar Secure Storage\'dan temizlendi');
  }

  // Token var mı kontrol et
  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Debug: Token durumunu göster
  static Future<void> debugTokens() async {
    final savedDate = await getTokenSavedDate();
    final hasAccess = await getAccessToken() != null;
    final hasRefresh = await getRefreshToken() != null;

    AppLogger.debug('=== Token Debug (Secure Storage) ===');
    AppLogger.debug('Access Token: ${hasAccess ? "Var" : "Yok"}');
    AppLogger.debug('Refresh Token: ${hasRefresh ? "Var" : "Yok"}');
    AppLogger.debug('Token Kayıt Tarihi: $savedDate');
    AppLogger.debug('==================');
  }
}
