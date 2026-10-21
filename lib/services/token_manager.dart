import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_logger.dart';

class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenSavedDateKey = 'token_saved_date';

  // Secure Storage instance
  static const _secureStorage = FlutterSecureStorage();

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
  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  // Refresh token kaydetme (Secure Storage)
  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  // Refresh token alma (Secure Storage)
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  // Token kayıt tarihini alma
  static Future<DateTime?> getTokenSavedDate() async {
    final dateString = await _secureStorage.read(key: _tokenSavedDateKey);
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

  // Tüm token'ları temizle
  static Future<void> clearAllTokens() async {
    // Yalnızca bu sınıfın yazdığı anahtarları sil.
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenSavedDateKey);
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
    final hasAccess = await _secureStorage.containsKey(key: _accessTokenKey);
    final hasRefresh = await _secureStorage.containsKey(key: _refreshTokenKey);

    AppLogger.debug('=== Token Debug (Secure Storage) ===');
    AppLogger.debug('Access Token: ${hasAccess ? "Var" : "Yok"}');
    AppLogger.debug('Refresh Token: ${hasRefresh ? "Var" : "Yok"}');
    AppLogger.debug('Token Kayıt Tarihi: $savedDate');
    AppLogger.debug('==================');
  }
}
