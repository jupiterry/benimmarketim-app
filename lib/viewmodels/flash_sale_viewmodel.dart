import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/flash_sale.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';

/// Flash sale'ler (yönetim panelinden girilen süreli indirimler).
///
/// Sunucu kampanyayı başlatınca indirimi ürünün kendisine uygular
/// (`isDiscounted` / `discountedPrice`); sipariş fiyatı da buradan hesaplanır.
/// Bu sınıf müşteriye rozet, geri sayım ve güncel fiyatı göstermek için
/// herkese açık `/flash-sales/active` listesini okur:
/// - Uygulama öndeyken düzenli aralıkla ve en yakın kampanya bitince yeniler.
/// - Kampanya başlayınca/bitince ürünün güncel halini [latest] ile verir ve
///   kayıtlı dinleyicilere (sepet) bildirir; böylece sepetteki fiyat da
///   sunucunun uygulayacağı fiyatla aynı kalır.
class FlashSaleViewModel extends ChangeNotifier with WidgetsBindingObserver {
  FlashSaleViewModel({ApiService? apiService, DateTime Function()? clock})
      : _apiService = apiService ?? ApiService(),
        _clock = clock ?? DateTime.now;

  final ApiService _apiService;
  final DateTime Function() _clock;

  static const Duration pollInterval = Duration(minutes: 2);

  /// Sunucu kampanyaları dakikada bir senkronlar; bitişten sonra bu kadar
  /// bekleyip yeniden okunur ki ürün fiyatı geri alınmış olsun.
  static const Duration endGrace = Duration(seconds: 75);

  List<FlashSale> _flashSales = [];
  Map<String, FlashSale> _byProduct = {};
  final Map<String, Product> _freshProducts = {};
  final List<void Function(List<Product>)> _productListeners = [];

  bool _isLoading = false;
  bool _loadingActive = false;
  bool _started = false;
  bool _disposed = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _endTimer;

  List<FlashSale> get flashSales => _flashSales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Şu an süren kampanyalar, en yakın biteni önce.
  List<FlashSale> get activeFlashSales {
    final now = _clock();
    return _flashSales.where((sale) => sale.isLiveAt(now)).toList();
  }

  /// Ürünün şu an süren kampanyası (yoksa null).
  FlashSale? saleFor(String productId) {
    final sale = _byProduct[productId];
    if (sale == null || !sale.isLiveAt(_clock())) return null;
    return sale;
  }

  /// Elimizdeki en güncel ürün bilgisi: listede gelen ürün, kampanya
  /// kaydındaki ürün ve kampanya değişince sunucudan alınan ürün arasından
  /// en son güncelleneni döner. Fiyat ve stok bu sürümden gösterilmeli.
  Product latest(Product product) {
    var best = product;
    final saleProduct = saleFor(product.id)?.product;
    if (saleProduct != null &&
        saleProduct.id == product.id &&
        !saleProduct.updatedAt.isBefore(best.updatedAt)) {
      best = saleProduct;
    }
    final fresh = _freshProducts[product.id];
    if (fresh != null && fresh.updatedAt.isAfter(best.updatedAt)) {
      best = fresh;
    }
    return best;
  }

  /// Kampanya başlayıp bittiğinde güncel ürünleri alacak dinleyici (sepet).
  void addProductRefreshListener(void Function(List<Product>) listener) {
    if (!_productListeners.contains(listener)) _productListeners.add(listener);
  }

  void removeProductRefreshListener(void Function(List<Product>) listener) {
    _productListeners.remove(listener);
  }

  /// Uygulama açılışında bir kez çağrılır: hemen okur, sonra öndeyken
  /// düzenli olarak yeniler.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshActive());
    _schedulePoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshActive());
      _schedulePoll();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _endTimer?.cancel();
    }
  }

  /// Süren kampanyaları sunucudan okur. İstek başarısızsa son liste korunur.
  Future<void> refreshActive() async {
    if (_loadingActive || _disposed) return;
    _loadingActive = true;
    try {
      final sales = await _apiService.getActiveFlashSales();
      if (sales == null || _disposed) return;

      final now = _clock();
      final next = <String, FlashSale>{};
      for (final sale in sales) {
        if (!sale.isLiveAt(now)) continue;
        final existing = next[sale.productId];
        // Aynı ürüne çakışan kampanya sunucuda engelli; yine de olursa
        // önce biteni tut.
        if (existing == null || sale.endDate.isBefore(existing.endDate)) {
          next[sale.productId] = sale;
        }
      }

      final previous = _byProduct;
      final changed = <Product>[];
      final ended = <String>[];
      for (final entry in next.entries) {
        final before = previous[entry.key];
        final sale = entry.value;
        if (before == null ||
            before.id != sale.id ||
            before.discountPercentage != sale.discountPercentage ||
            before.product.actualPrice != sale.product.actualPrice) {
          if (sale.product.id.isNotEmpty) changed.add(sale.product);
        }
      }
      for (final id in previous.keys) {
        if (!next.containsKey(id)) ended.add(id);
      }

      final listChanged = changed.isNotEmpty || ended.isNotEmpty;
      _byProduct = next;
      _flashSales = next.values.toList()
        ..sort((a, b) => a.endDate.compareTo(b.endDate));
      _error = null;
      _scheduleEndRefresh();
      if (listChanged) notifyListeners();

      // Biten kampanyaların ürününü yeniden al: fiyat eski haline döndü.
      for (final id in ended) {
        try {
          final product = await _apiService.getProductById(id);
          if (_disposed) return;
          _freshProducts[id] = product;
          changed.add(product);
        } catch (e) {
          AppLogger.debug('Flash sale sonrası ürün alınamadı ($id): $e');
        }
      }
      if (ended.isNotEmpty) notifyListeners();
      if (changed.isNotEmpty) _notifyProducts(changed);
    } catch (e) {
      _error = e.toString();
      AppLogger.debug('Flash sale yenileme hatası: $e');
    } finally {
      _loadingActive = false;
    }
  }

  void _notifyProducts(List<Product> products) {
    for (final listener in List.of(_productListeners)) {
      try {
        listener(products);
      } catch (e) {
        AppLogger.debug('Flash sale dinleyici hatası: $e');
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_disposed) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => refreshActive());
  }

  void _scheduleEndRefresh() {
    _endTimer?.cancel();
    if (!_started || _flashSales.isEmpty || _disposed) return;
    final wait = _flashSales.first.endDate.difference(_clock()) + endGrace;
    _endTimer = Timer(wait.isNegative ? endGrace : wait, refreshActive);
  }

  // ---------------------------------------------------------------------
  // Eski arayüz (geriye uyumluluk). Müşteri hesabı yönetici uç noktasını
  // okuyamadığı için liste artık herkese açık aktif kampanyalardan gelir.
  // ---------------------------------------------------------------------

  Future<void> loadFlashSales() async {
    _setLoading(true);
    try {
      await refreshActive();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _endTimer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _productListeners.clear();
    super.dispose();
  }
}
