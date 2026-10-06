import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_logger.dart';

class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenSavedDateKey = 'token_saved_date';
  static const int _tokenValidityDays = 10; // 10 gün

  // Secure Storage instance
  static const _secureStorage = FlutterSecureStorage();

  // SharedPreferences'ı başlat (Artık kullanılmıyor ama uyumluluk için boş bırakıyoruz)
  static Future<void> init() async {
    AppLogger.debug('TokenManager başlatıldı (Secure Storage)');
  }

  // Access token kaydetme (Secure Storage)
  static Future<void> saveAccessToken(
    String token, {
    bool isPhoneLogin = false,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);

    // Tarih bilgisini SharedPreferences'ta tutabiliriz (hassas değil)
    // veya Secure Storage'da da tutabiliriz, tutarlılık için Secure Storage kullanalım
    if (isPhoneLogin) {
      await _secureStorage.write(
        key: _tokenSavedDateKey,
        value: DateTime.now().toIso8601String(),
      );
      AppLogger.debug('Token kayıt tarihi saklandı: ${DateTime.now()}');
    } else {
      // Her girişte tarihi güncelle (10 gün kuralı için)
      await _secureStorage.write(
        key: _tokenSavedDateKey,
        value: DateTime.now().toIso8601String(),
      );
    }
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

  // Token'ın geçerli olup olmadığını kontrol et (10 gün içinde mi?)
  static Future<bool> isTokenValid() async {
    final savedDate = await getTokenSavedDate();
    if (savedDate == null) {
      // Eğer kayıt tarihi yoksa, eski sistem - token varsa geçerli say
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    }

    final now = DateTime.now();
    final difference = now.difference(savedDate);

    // 10 günden fazla geçmişse token geçersiz
    if (difference.inDays > _tokenValidityDays) {
      AppLogger.debug('Token süresi dolmuş: ${difference.inDays} gün geçmiş');
      return false;
    }

    AppLogger.debug('Token geçerli: ${difference.inDays} gün kaldı');
    return true;
  }

  // Tüm token'ları temizle
  static Future<void> clearAllTokens() async {
    // Yalnızca bu sınıfın yazdığı anahtarları sil.
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenSavedDateKey);
    AppLogger.debug('Tüm token\'lar Secure Storage\'dan temizlendi');
  }

  // Token var mı kontrol et (10 günlük kontrol ile)
  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    // Token geçerliliğini kontrol et
    return await isTokenValid();
  }

  // Debug: Token durumunu göster
  static Future<void> debugTokens() async {
    final savedDate = await getTokenSavedDate();
    final isValid = await isTokenValid();
    final daysLeft = savedDate != null
        ? _tokenValidityDays - DateTime.now().difference(savedDate).inDays
        : null;

    final hasAccess = await _secureStorage.containsKey(key: _accessTokenKey);
    final hasRefresh = await _secureStorage.containsKey(key: _refreshTokenKey);

    AppLogger.debug('=== Token Debug (Secure Storage) ===');
    AppLogger.debug('Access Token: ${hasAccess ? "Var" : "Yok"}');
    AppLogger.debug('Refresh Token: ${hasRefresh ? "Var" : "Yok"}');
    AppLogger.debug('Token Kayıt Tarihi: $savedDate');
    AppLogger.debug('Token Geçerli: $isValid');
    AppLogger.debug('Kalan Gün: $daysLeft');
    AppLogger.debug('Has Token: ${await hasToken()}');
    AppLogger.debug('==================');
  }
}
