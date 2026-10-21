import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Ürün listelerinin diskteki kopyası. Uygulama açılırken ve bir kategoriye
/// girilince son liste anında gösterilir, güncel liste arka planda gelir.
///
/// SharedPreferences yerine dosya kullanılır: Android'de tüm tercihler
/// açılışta belleğe okunur, yüzlerce ürünlük listeler açılışı yavaşlatırdı.
abstract final class JsonFileCache {
  static Future<Directory>? _directory;

  static Future<Directory> _dir() => _directory ??= () async {
        final base = await getApplicationCacheDirectory();
        final dir = Directory('${base.path}/market_cache');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }();

  static String _fileName(String key) =>
      '${key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.json';

  /// Kayıt yoksa, bozuksa ya da [maxAge]'den eskiyse null döner.
  static Future<CachedJson?> read(String key, {Duration? maxAge}) async {
    try {
      final file = File('${(await _dir()).path}/${_fileName(key)}');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse('${decoded['savedAt']}');
      if (savedAt == null) return null;
      if (maxAge != null && DateTime.now().difference(savedAt) > maxAge) {
        return null;
      }
      return CachedJson(savedAt: savedAt, data: decoded['data']);
    } catch (e) {
      AppLogger.debug('Önbellek okunamadı ($key): $e');
      return null;
    }
  }

  /// Önce geçici dosyaya yazar, sonra yerine taşır; yarım kalan yazma eski
  /// kaydı bozmaz.
  static Future<void> write(String key, Object? data) async {
    try {
      final dir = await _dir();
      final target = File('${dir.path}/${_fileName(key)}');
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(
        jsonEncode({'savedAt': DateTime.now().toIso8601String(), 'data': data}),
        flush: true,
      );
      await temp.rename(target.path);
    } catch (e) {
      AppLogger.debug('Önbellek yazılamadı ($key): $e');
    }
  }
}

class CachedJson {
  final DateTime savedAt;
  final Object? data;

  const CachedJson({required this.savedAt, required this.data});
}
