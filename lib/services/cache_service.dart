import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheService {
  static CacheService? _instance;
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};

  CacheService._();

  static CacheService get instance {
    _instance ??= CacheService._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Bellek önbelleği
  void setMemoryCache(String key, dynamic value) {
    _memoryCache[key] = value;
  }

  T? getMemoryCache<T>(String key) {
    return _memoryCache[key] as T?;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }

  // Kalıcı önbellek
  Future<void> setCache(String key, dynamic value, {Duration? expiry}) async {
    await init();
    final data = {
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    await _prefs!.setString(key, json.encode(data));
  }

  Future<T?> getCache<T>(String key) async {
    await init();
    final data = _prefs!.getString(key);
    if (data == null) return null;

    try {
      final decoded = json.decode(data);
      final timestamp = decoded['timestamp'] as int;
      final expiry = decoded['expiry'] as int?;
      
      // Süresi dolmuş mu kontrol et
      if (expiry != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - timestamp > expiry) {
          await removeCache(key);
          return null;
        }
      }
      
      return decoded['value'] as T?;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeCache(String key) async {
    await init();
    await _prefs!.remove(key);
  }

  Future<void> clearAllCache() async {
    await init();
    await _prefs!.clear();
    clearMemoryCache();
  }

  // Resim önbelleği
  static final CacheManager imageCacheManager = CacheManager(
    Config(
      'image_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  // API yanıtları için önbellek
  Future<void> cacheApiResponse(String endpoint, dynamic response, {Duration? expiry}) async {
    final key = 'api_$endpoint';
    await setCache(key, response, expiry: expiry ?? const Duration(minutes: 5));
  }

  Future<T?> getCachedApiResponse<T>(String endpoint) async {
    final key = 'api_$endpoint';
    return await getCache<T>(key);
  }

  // Ürün önbelleği
  Future<void> cacheProducts(List<dynamic> products) async {
    await setCache('products', products, expiry: const Duration(minutes: 10));
  }

  Future<List<dynamic>?> getCachedProducts() async {
    return await getCache<List<dynamic>>('products');
  }

  // Kategori önbelleği
  Future<void> cacheCategories(List<dynamic> categories) async {
    await setCache('categories', categories, expiry: const Duration(hours: 1));
  }

  Future<List<dynamic>?> getCachedCategories() async {
    return await getCache<List<dynamic>>('categories');
  }
}
