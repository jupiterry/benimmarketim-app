import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_feed.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/json_file_cache.dart';
import '../services/token_manager.dart';

/// Son siparişte seçilen teslimat noktası (girlsDorm / boysDorm). Sipariş
/// sayfası yazar; ana sayfa önerileri yurda göre isterken okur.
const lastDeliveryPointPrefsKey = 'last_delivery_point';

/// Ana sayfa rafları.
///
/// Hız için:
/// - Son raflar diskte saklanır; açılışta önce o gösterilir, güncel hali arka
///   planda gelir (ana sayfa boş iskeletle beklemez).
/// - Sunucu destekliyorsa tüm raflar tek istekte gelir (`/products/home-feed`);
///   desteklemiyorsa eski uç noktalar kullanılır ama tüm katalog (~1500
///   ürün) yerine yalnızca ilk sayfa istenir.
/// - Uygulama uzun süre arka planda kaldıysa öne gelince raflar tazelenir.
class HomePageViewModel extends ChangeNotifier with WidgetsBindingObserver {
  HomePageViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String _cacheKey = 'home_feed_v1';
  static const Duration _cacheMaxAge = Duration(days: 3);
  static const Duration _staleAfter = Duration(minutes: 10);
  static const int _legacyPageSize = 60;

  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<Product> _personalizedProducts = [];
  String _forYouStrategy = 'popular';
  bool _isLoading = false;
  String? _error;
  DateTime? _fetchedAt;
  Future<void>? _fetching;
  bool _observing = false;
  bool _disposed = false;

  /// Genel ürün listesi (popüler + öneriler); sepet önerileri ve yedek
  /// gösterimler bunu kullanır.
  List<Product> get products => _products;

  /// İndirimli ürünler önce, ardından öne çıkanlar ("Bugünün fırsatları").
  List<Product> get featuredProducts => _featuredProducts;

  /// "Senin için seçtik" rafı.
  List<Product> get personalizedProducts => _personalizedProducts;

  /// `personal`: sipariş geçmişine göre; `popular`: çok satanlar;
  /// `catalog`: sunucu öneri desteklemiyor, katalog sırası.
  String get forYouStrategy => _forYouStrategy;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Tab State
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  bool get _hasData =>
      _products.isNotEmpty ||
      _featuredProducts.isNotEmpty ||
      _personalizedProducts.isNotEmpty;

  /// Ana sayfa ilk açıldığında çağrılır. Bellekte veri varsa hemen döner.
  /// Diskte kayıt varsa onu gösterip döner (güncel hali arka planda gelir);
  /// yoksa ağdan yüklenmesini bekler.
  Future<void> loadHomeProducts() async {
    if (_hasData) return;
    if (await _restoreFromCache()) {
      unawaited(_fetch());
      return;
    }
    if (_fetching == null) _setLoading(true);
    await _fetch();
  }

  /// Aşağı çekip yenileme: mevcut raflar ekranda kalır.
  Future<void> refreshProducts() => _fetch();

  /// Son yüklemeden bu yana [_staleAfter] geçtiyse arka planda tazeler.
  Future<void> refreshIfStale() async {
    final fetchedAt = _fetchedAt;
    if (fetchedAt == null || DateTime.now().difference(fetchedAt) < _staleAfter) {
      return;
    }
    await _fetch();
  }

  /// Uygulama öne gelince eskimiş rafları tazeler (main.dart'ta bir kez).
  void startAutoRefresh() {
    if (_observing || _disposed) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshIfStale());
  }

  Future<bool> _restoreFromCache() async {
    final cached = await JsonFileCache.read(_cacheKey, maxAge: _cacheMaxAge);
    final data = cached?.data;
    if (data is! Map || _disposed || _hasData) return false;
    try {
      final feed = HomeFeed.fromJson(Map<String, dynamic>.from(data));
      if (feed.isEmpty) return false;
      _apply(feed);
      AppLogger.debug('HomePageViewModel: Showing cached shelves');
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aynı anda tek ağ isteği; ikinci çağrı ilkini bekler.
  Future<void> _fetch() {
    final inFlight = _fetching;
    if (inFlight != null) return inFlight;
    final future = _fetchFromNetwork().whenComplete(() => _fetching = null);
    _fetching = future;
    return future;
  }

  Future<void> _fetchFromNetwork() async {
    try {
      final deliveryPoint = await _lastDeliveryPoint();
      final feed = await _apiService.getHomeFeed(deliveryPoint: deliveryPoint) ??
          await _legacyFeed(deliveryPoint);
      if (_disposed) return;
      if (feed.isEmpty && _hasData) return; // boş yanıt eldekini silmesin
      _apply(feed);
      _error = null;
      _fetchedAt = DateTime.now();
      unawaited(JsonFileCache.write(_cacheKey, feed.toJson()));
      AppLogger.debug(
        'HomePageViewModel: ${_featuredProducts.length} deals, '
        '${_personalizedProducts.length} for you ($_forYouStrategy)',
      );
    } catch (e) {
      AppLogger.debug('HomePageViewModel: Error loading products: $e');
      // Eldeki (önbellekteki) raflar varsa hata gösterilmez.
      if (!_hasData) _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Sunucu `/home-feed` desteklemiyorsa eski uç noktalarla aynı raflar.
  Future<HomeFeed> _legacyFeed(String? deliveryPoint) async {
    final loggedIn = await TokenManager.hasToken();
    final results = await Future.wait([
      _apiService.getProducts(limit: _legacyPageSize, cardFields: true),
      _apiService.getFeaturedProducts(),
      if (loggedIn)
        _apiService.getPersonalizedProducts(deliveryPoint: deliveryPoint)
      else
        Future.value(const <Product>[]),
    ]);
    final visible = results[0].where((p) => !p.isHidden).toList();
    final featured = results[1].where((p) => !p.isHidden).toList();
    final personal = results[2].where((p) => !p.isHidden).toList();
    return HomeFeed(
      deals: featured,
      forYou: personal,
      popular: visible,
      // Eski sunucuda popülerlik yok; liste katalog sırasıdır.
      strategy: personal.isNotEmpty ? 'personal' : 'catalog',
    );
  }

  void _apply(HomeFeed feed) {
    _featuredProducts = feed.deals;
    _personalizedProducts = feed.forYou.isNotEmpty ? feed.forYou : feed.popular;
    _forYouStrategy = feed.forYou.isNotEmpty || feed.strategy == 'catalog'
        ? feed.strategy
        : 'popular';
    final seen = <String>{};
    _products = [
      for (final p in [...feed.popular, ...feed.forYou, ...feed.deals])
        if (seen.add(p.id)) p,
    ];
  }

  Future<String?> _lastDeliveryPoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(lastDeliveryPointPrefsKey);
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
