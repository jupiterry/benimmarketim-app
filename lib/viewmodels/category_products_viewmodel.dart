import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/json_file_cache.dart';

/// Kategori ürünleri.
///
/// Hız için:
/// - Gezilen kategoriler bellekte (son 8) ve diskte saklanır. Tekrar girilince
///   liste anında görünür; kayıt birkaç dakikadan eskiyse güncel hali arka
///   planda gelir.
/// - İlk kez girilen kategoride önce ilk sayfa (40 ürün) istenir ve hemen
///   gösterilir, kalan ürünler arkasından gelir.
class CategoryProductsViewModel extends ChangeNotifier {
  CategoryProductsViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const int _firstPageSize = 40;
  static const int _memoryLimit = 8;
  static const Duration _freshFor = Duration(minutes: 3);
  static const Duration _diskMaxAge = Duration(days: 3);

  final Map<String, _CachedList> _memory = {};

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _currentCategoryId;
  int _request = 0;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  /// İlk sayfa gösterildi, kalan ürünler yükleniyor.
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get currentCategoryId => _currentCategoryId;

  static String _diskKey(String categoryId) => 'category_v1_$categoryId';

  Future<void> loadCategoryProducts(String categoryId) async {
    final request = ++_request;
    _currentCategoryId = categoryId;
    _error = null;

    // 1) Bellekte varsa hemen göster
    final memory = _memory[categoryId];
    if (memory != null) {
      _isLoadingMore = false;
      _show(memory.products);
      if (DateTime.now().difference(memory.savedAt) < _freshFor) return;
      await _fetchAll(categoryId, request);
      return;
    }

    // 2) Diskte varsa onu göster, güncelini arkadan al
    _products = [];
    _isLoadingMore = false;
    _setLoading(true);
    final disk = await _readDisk(categoryId);
    if (request != _request) return;
    if (disk != null) {
      _remember(categoryId, disk.products, savedAt: disk.savedAt);
      _isLoading = false;
      _show(disk.products);
      await _fetchAll(categoryId, request);
      return;
    }

    // 3) İlk ziyaret: önce ilk sayfa, sonra tamamı
    try {
      final firstPage = await _apiService.getProducts(
        category: categoryId,
        limit: _firstPageSize,
        page: 1,
        cardFields: true,
      );
      if (request != _request) return;
      final visible = firstPage.where((p) => !p.isHidden).toList();
      _isLoading = false;
      if (firstPage.length < _firstPageSize) {
        // Kategori tek sayfaya sığıyor
        _remember(categoryId, visible);
        unawaited(_writeDisk(categoryId, visible));
        _show(visible);
        return;
      }
      _isLoadingMore = true;
      _show(visible);
      await _fetchAll(categoryId, request);
    } catch (e) {
      if (request != _request) return;
      AppLogger.debug('CategoryProductsViewModel: Error loading products: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Aşağı çekip yenileme: mevcut liste ekranda kalır, gelen liste yerine
  /// geçer (güncel fiyat, stok ve flash sale indirimleri). Hata olursa
  /// mevcut liste korunur.
  Future<void> refreshCategoryProducts(String categoryId) async {
    if (_currentCategoryId != categoryId || _products.isEmpty) {
      await loadCategoryProducts(categoryId);
      return;
    }
    await _fetchAll(categoryId, _request);
  }

  Future<void> _fetchAll(String categoryId, int request) async {
    try {
      final all = await _apiService.getProducts(
        category: categoryId,
        cardFields: true,
      );
      final visible = all.where((p) => !p.isHidden).toList();
      _remember(categoryId, visible);
      unawaited(_writeDisk(categoryId, visible));
      if (request != _request || _currentCategoryId != categoryId) return;
      _error = null;
      _isLoadingMore = false;
      _show(visible);
      AppLogger.debug(
        'CategoryProductsViewModel: Loaded ${visible.length} products for $categoryId',
      );
    } catch (e) {
      AppLogger.debug('CategoryProductsViewModel: Refresh failed: $e');
      if (request != _request) return;
      _isLoadingMore = false;
      if (_products.isEmpty) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      notifyListeners();
    }
  }

  void _show(List<Product> products) {
    _products = products;
    _isLoading = false;
    notifyListeners();
  }

  void _remember(String categoryId, List<Product> products, {DateTime? savedAt}) {
    _memory.remove(categoryId);
    _memory[categoryId] = _CachedList(products, savedAt ?? DateTime.now());
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<_CachedList?> _readDisk(String categoryId) async {
    final cached =
        await JsonFileCache.read(_diskKey(categoryId), maxAge: _diskMaxAge);
    final data = cached?.data;
    if (cached == null || data is! List) return null;
    final products = <Product>[];
    for (final item in data) {
      if (item is! Map) continue;
      try {
        final product = Product.fromJson(Map<String, dynamic>.from(item));
        if (!product.isHidden) products.add(product);
      } catch (_) {}
    }
    if (products.isEmpty) return null;
    return _CachedList(products, cached.savedAt);
  }

  Future<void> _writeDisk(String categoryId, List<Product> products) =>
      JsonFileCache.write(
        _diskKey(categoryId),
        products.map((p) => p.toJson()).toList(),
      );

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

class _CachedList {
  final List<Product> products;
  final DateTime savedAt;

  _CachedList(this.products, this.savedAt);
}
