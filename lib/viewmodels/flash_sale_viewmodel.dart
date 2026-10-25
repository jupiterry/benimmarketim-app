import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/flash_sale.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/server_clock.dart';

/// Flash sale'ler (yönetim panelinden girilen süreli indirimler).
///
/// Sunucu kampanyayı başlatınca indirimi ürünün kendisine uygular
/// (`isDiscounted` / `discountedPrice`); sipariş fiyatı da buradan hesaplanır.
/// Ürün yanıtlarında `actualPrice` siparişte alınacak fiyattır; kampanya
/// sürerken ürünle birlikte `flashSale` özeti de gelir. Bu sınıf müşteriye
/// rozet, geri sayım ve güncel fiyatı göstermek için:
/// - Rozeti önce ürünün kendi `flashSale` alanından verir ([saleOf]); yoksa
///   herkese açık `/flash-sales/active` listesine bakar.
/// - Listeyi uygulama öndeyken dakikada bir ve en yakın kampanya bitince
///   yeniler. Başlama/bitiş sunucu saatine göre hesaplanır ([ServerClock]);
///   telefonun saati yanlış olsa da satış doğru görünür.
/// - Kampanya başlayınca/bitince ürünün güncel halini [latest] ile verir,
///   kayıtlı dinleyicilere (sepet) bildirir ve ürün listelerinin (ana sayfa,
///   kategori) yenilenmesini ister ([addCatalogChangeListener]).
class FlashSaleViewModel extends ChangeNotifier with WidgetsBindingObserver {
  FlashSaleViewModel({
    ApiService? apiService,
    DateTime Function()? clock,
    ServerClock? serverClock,
  })  : _apiService = apiService ?? ApiService(),
        _serverClock = serverClock ??
            (clock != null
                ? ServerClock(deviceClock: clock)
                : ServerClock.instance);

  final ApiService _apiService;
  final ServerClock _serverClock;

  /// Uygulama öndeyken `/flash-sales/active` bu aralıkla okunur.
  static const Duration pollInterval = Duration(seconds: 60);

  /// Sunucu biten kampanyayı `/flash-sales/active` isteğinde (en sık 10 sn'de
  /// bir) geri alır; bitişten bu kadar sonra yeniden okunur ki ürün fiyatı
  /// normale dönmüş olsun.
  static const Duration endGrace = Duration(seconds: 15);

  /// Bellekte tutulan güncel ürün sayısı (kampanya bitince ya da ürün
  /// sayfasında alınanlar).
  static const int _freshLimit = 200;

  List<FlashSale> _flashSales = [];
  Map<String, FlashSale> _byProduct = {};
  final Map<String, Product> _freshProducts = {};
  final List<void Function(List<Product>)> _productListeners = [];
  final List<VoidCallback> _catalogListeners = [];

  bool _isLoading = false;
  bool _loadingActive = false;
  bool _loadedOnce = false;
  bool _started = false;
  bool _disposed = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _endTimer;

  List<FlashSale> get flashSales => _flashSales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Sunucu saatine göre şimdi.
  DateTime get serverNow => _serverClock.now();

  /// Şu an süren kampanyalar, en yakın biteni önce.
  List<FlashSale> get activeFlashSales {
    final now = serverNow;
    return _flashSales.where((sale) => sale.isLiveAt(now)).toList();
  }

  /// `/flash-sales/active` listesinde ürünün şu an süren kampanyası (yoksa
  /// null). Ürün elde varsa [saleOf] tercih edilmeli.
  FlashSale? saleFor(String productId) {
    final sale = _byProduct[productId];
    if (sale == null || !sale.isLiveAt(serverNow)) return null;
    return sale;
  }

  /// Ürünün şu an süren kampanyası (rozet ve geri sayım için).
  ///
  /// Ürünün en güncel halindeki `flashSale` özeti tercih edilir. Özet yoksa
  /// `/flash-sales/active` listesine bakılır; ama elimizdeki ürün kampanya
  /// kaydındaki üründen yeniyse (ör. kampanya bitince/iptal edilince alındı)
  /// ürünün söylediği geçerlidir: kampanya yok.
  FlashSale? saleOf(Product product) {
    final item = latest(product);
    final info = item.flashSale;
    if (info != null && info.isLiveAt(serverNow)) {
      return FlashSale.fromProduct(item, info);
    }
    final sale = saleFor(item.id);
    if (sale == null || item.updatedAt.isAfter(sale.product.updatedAt)) {
      return null;
    }
    return sale;
  }

  /// Elimizdeki en güncel ürün bilgisi: listede gelen ürün, kampanya
  /// kaydındaki ürün ve sunucudan ayrıca alınan ürün (kampanya bitince ya da
  /// ürün sayfasında) arasından en son güncelleneni döner. Fiyat ve stok bu
  /// sürümden gösterilmeli.
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

  /// Sunucudan yeni alınmış ürünü (ör. ürün sayfası açılınca) hatırlar;
  /// listelerdeki kartlar da güncel fiyat ve rozeti gösterir.
  void rememberProduct(Product product) {
    if (_disposed || product.id.isEmpty) return;
    final known = _freshProducts[product.id];
    if (known != null && !product.updatedAt.isAfter(known.updatedAt)) return;
    _storeFresh(product);
    notifyListeners();
  }

  void _storeFresh(Product product) {
    _freshProducts.remove(product.id);
    _freshProducts[product.id] = product;
    while (_freshProducts.length > _freshLimit) {
      _freshProducts.remove(_freshProducts.keys.first);
    }
  }

  /// Kampanya başlayıp bittiğinde güncel ürünleri alacak dinleyici (sepet).
  void addProductRefreshListener(void Function(List<Product>) listener) {
    if (!_productListeners.contains(listener)) _productListeners.add(listener);
  }

  void removeProductRefreshListener(void Function(List<Product>) listener) {
    _productListeners.remove(listener);
  }

  /// Bir kampanya başlayınca ya da bitince çağrılır: ürün listeleri (ana
  /// sayfa rafları, kategori önbelleği) yenilenmeli. İlk okumada çağrılmaz
  /// (listeler açılışta zaten sunucudan gelir).
  void addCatalogChangeListener(VoidCallback listener) {
    if (!_catalogListeners.contains(listener)) _catalogListeners.add(listener);
  }

  void removeCatalogChangeListener(VoidCallback listener) {
    _catalogListeners.remove(listener);
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
      final sentAt = _serverClock.deviceNow();
      final result = await _apiService.getActiveFlashSales();
      if (result == null || _disposed) return;

      // Sunucu saati: isteğin gidiş-dönüşünün ortasında okunmuş sayılır.
      final offsetBefore = _serverClock.offset;
      final serverTime = result.serverTime;
      if (serverTime != null) {
        final receivedAt = _serverClock.deviceNow();
        _serverClock.sync(
          serverTime,
          deviceTime: sentAt.add(receivedAt.difference(sentAt) ~/ 2),
        );
      }
      final clockMoved = (_serverClock.offset - offsetBefore).abs() >
          const Duration(seconds: 1);

      final now = serverNow;
      final next = <String, FlashSale>{};
      for (final sale in result.sales) {
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
      final firstLoad = !_loadedOnce;
      _loadedOnce = true;
      _byProduct = next;
      _flashSales = next.values.toList()
        ..sort((a, b) => a.endDate.compareTo(b.endDate));
      _error = null;
      _scheduleEndRefresh();
      if (listChanged || clockMoved) notifyListeners();

      // Biten kampanyaların ürününü yeniden al: fiyat eski haline döndü.
      for (final id in ended) {
        try {
          final product = await _apiService.getProductById(id);
          if (_disposed) return;
          _storeFresh(product);
          changed.add(product);
        } catch (e) {
          AppLogger.debug('Flash sale sonrası ürün alınamadı ($id): $e');
        }
      }
      if (ended.isNotEmpty) notifyListeners();
      if (changed.isNotEmpty) _notifyProducts(changed);
      // Kampanya başladı/bitti: ürün listeleri de yeni fiyatı göstersin.
      if (listChanged && !firstLoad) _notifyCatalog();
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

  void _notifyCatalog() {
    for (final listener in List.of(_catalogListeners)) {
      try {
        listener();
      } catch (e) {
        AppLogger.debug('Flash sale liste dinleyici hatası: $e');
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_disposed) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => refreshActive());
  }

  /// En yakın kampanyanın bitişinde rozet hemen kalkar (ekran yeniden
  /// çizilir); [endGrace] sonra liste yeniden okunur.
  void _scheduleEndRefresh() {
    _endTimer?.cancel();
    if (!_started || _flashSales.isEmpty || _disposed) return;
    final wait = _flashSales.first.endDate.difference(serverNow);
    _endTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (_disposed) return;
      notifyListeners();
      _endTimer = Timer(endGrace, refreshActive);
    });
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
    _catalogListeners.clear();
    super.dispose();
  }
}
