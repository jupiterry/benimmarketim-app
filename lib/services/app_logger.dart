import 'package:flutter/foundation.dart';

/// Uygulama genelindeki tek log noktası.
///
/// - Release modunda hiçbir şey yazmaz.
/// - Şifre, token, telefon, adres gibi hassas veriler buraya hiç
///   gönderilmemelidir; [_redact] yalnızca gözden kaçan token kalıplarına
///   karşı ek bir güvenlik katmanıdır.
class AppLogger {
  AppLogger._();

  static bool get enabled => !kReleaseMode;

  static final List<RegExp> _sensitivePatterns = [
    // JWT (header.payload.signature)
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    // Authorization: Bearer xxx
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    // "password": "...", accessToken=..., refreshToken: ...
    RegExp(
      r'''((?:password|şifre|accessToken|refreshToken|access_token|refresh_token|token)["']?\s*[:=]\s*)["']?[^\s,"'}]+["']?''',
      caseSensitive: false,
    ),
  ];

  static String _redact(String message) {
    var result = message;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAllMapped(pattern, (match) {
        final prefix = match.groupCount >= 1 ? match.group(1) : null;
        return prefix != null ? '$prefix***' : '***';
      });
    }
    return result;
  }

  static void debug(Object? message) {
    if (!enabled) return;
    debugPrint(_redact('$message'));
  }

  static void error(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    final buffer = StringBuffer('$message');
    if (error != null) buffer.write(': $error');
    debugPrint(_redact(buffer.toString()));
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }

  @visibleForTesting
  static String redactForTest(String message) => _redact(message);
}
