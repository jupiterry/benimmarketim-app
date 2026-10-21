import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../models/cart_item.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../services/meta_app_events_service.dart';

class CartViewModel extends ChangeNotifier {
  final List<CartItem> _cartItems = [];
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();

  // Kupon bilgileri
  String? _appliedCouponCode;
  Map<String, dynamic>? _appliedCoupon;
  double _discountAmount = 0;
  bool _isValidatingCoupon = false;
  String? _couponError;
  Map<String, dynamic>? _recommendedCoupon;
  Timer? _couponSyncTimer;
  Timer? _cartSyncTimer;
  bool _cartSeenFilled = false;
  // Kupon doğrulama/öneri istekleri sırayla numaralanır; sepet bu arada
  // değiştiyse eski (geç gelen) yanıt yok sayılır.
  int _couponRequestSeq = 0;

  CartViewModel() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    final items = await _databaseService.getCartItems();
    _cartItems.addAll(items);

    // Uygulama açılışında sepet durumunu güncelle (OneSignal)
    NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);

    notifyListeners();
    _scheduleCouponSync();

    if (_cartItems.isEmpty) return;

    // Sunucudan güncel fiyat/stok çekilir. Bu sırada kullanıcı sepete
    // dokunmuş olabilir; bu yüzden liste baştan yazılmaz, ürün kimliğine
    // göre birleştirilir: hâlâ sepette olan kalemlerin ürün bilgisi
    // güncellenir, bu arada eklenenler korunur, yalnızca sunucuda artık
    // bulunmayan (404) ürünler sepetten düşer.
    final snapshot = List<CartItem>.of(_cartItems);
    final fresh = <String, Product>{};
    final gone = <String>{};
    await Future.wait(
      snapshot.map((item) async {
        try {
          fresh[item.product.id] =
              await _apiService.getProductById(item.product.id);
        } on ApiException catch (e) {
          if (e.statusCode == 404) gone.add(item.product.id);
        } catch (_) {
          // Ağ hatası: eldeki bilgiyle devam
        }
      }),
    );

    var changed = false;
    for (var index = _cartItems.length - 1; index >= 0; index--) {
      final item = _cartItems[index];
      final id = item.product.id;
      if (gone.contains(id)) {
        _cartItems.removeAt(index);
        unawaited(_databaseService.removeFromCart(id));
        changed = true;
        continue;
      }
      final product = fresh[id];
      if (product == null) continue;
      final updated = item.copyWith(product: product);
      _cartItems[index] = updated;
      unawaited(_databaseService.saveCartItem(updated));
      changed = true;
    }
    if (!changed) return;
    NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);
    notifyListeners();
    _scheduleCouponSync();
  }

  // Getters
  List<CartItem> get items => List.unmodifiable(_cartItems);
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  int get itemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  bool get isEmpty => _cartItems.isEmpty;

  // Kupon getters
  String? get appliedCouponCode => _appliedCouponCode;
  Map<String, dynamic>? get appliedCoupon => _appliedCoupon;
  double get discountAmount => _discountAmount;
  bool get isValidatingCoupon => _isValidatingCoupon;
  String? get couponError => _couponError;
  Map<String, dynamic>? get recommendedCoupon => _recommendedCoupon;
  double get finalPrice =>
      (totalPrice - _discountAmount).clamp(0, double.infinity);

  // Sepete ürün ekle
  void addToCart(Product product) {
    final existingItemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      // Ürün zaten sepette, miktarını artır
      final updatedItem = _cartItems[existingItemIndex].copyWith(
        product: product,
        quantity: _cartItems[existingItemIndex].quantity + 1,
      );
      _cartItems[existingItemIndex] = updatedItem;
      _databaseService.saveCartItem(updatedItem);
    } else {
      // Yeni ürün ekle
      final newItem = CartItem(product: product);
      _cartItems.add(newItem);
      _databaseService.addToCart(newItem);
    }

    _scheduleCouponSync();

    // Sepet durumunu güncelle (Dolu)
    NotificationService.instance.updateCartTag(true);

    // Meta: sepete ekleme (izin yoksa gönderilmez)
    unawaited(MetaAppEventsService.instance.logAddToCart(product));

    notifyListeners();
  }

  /// Ürünü verilen adetle tek seferde sepete ekler (tekrar sipariş, asistan
  /// önerisi, favori sepet). Adet tek yazmayla kaydedildiği için uygulama
  /// yeniden açıldığında da doğru kalır.
  void addQuantity(Product product, int quantity) {
    if (quantity < 1) return;
    final existingItemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      final updatedItem = _cartItems[existingItemIndex].copyWith(
        product: product,
        quantity: _cartItems[existingItemIndex].quantity + quantity,
      );
      _cartItems[existingItemIndex] = updatedItem;
      _databaseService.saveCartItem(updatedItem);
    } else {
      final newItem = CartItem(product: product, quantity: quantity);
      _cartItems.add(newItem);
      _databaseService.addToCart(newItem);
    }

    _scheduleCouponSync();
    NotificationService.instance.updateCartTag(true);
    unawaited(
      MetaAppEventsService.instance.logAddToCart(product, quantity: quantity),
    );
    notifyListeners();
  }

  /// Sunucudan gelen güncel ürün bilgisini (ör. flash sale başlayıp bitince)
  /// sepetteki kalemlere uygular; adetler değişmez. Böylece sepette görünen
  /// fiyat sunucunun siparişte uygulayacağı fiyatla aynı kalır.
  void applyFreshProducts(List<Product> products) {
    var changed = false;
    for (final product in products) {
      final index =
          _cartItems.indexWhere((item) => item.product.id == product.id);
      if (index < 0) continue;
      final current = _cartItems[index].product;
      if (current.actualPrice == product.actualPrice &&
          current.price == product.price &&
          current.isOutOfStock == product.isOutOfStock) {
        continue;
      }
      final updated = _cartItems[index].copyWith(product: product);
      _cartItems[index] = updated;
      _databaseService.saveCartItem(updated);
      changed = true;
    }
    if (!changed) return;
    _scheduleCouponSync();
    notifyListeners();
  }

  // Sepetten ürün çıkar
  void removeFromCart(Product product) {
    final existingItemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      if (_cartItems[existingItemIndex].quantity > 1) {
        // Miktarı azalt
        _cartItems[existingItemIndex].quantity--;
        _databaseService.updateCartItemQuantity(
          product.id,
          _cartItems[existingItemIndex].quantity,
        );
      } else {
        // Ürünü tamamen çıkar
        _cartItems.removeAt(existingItemIndex);
        _databaseService.removeFromCart(product.id);
      }
    }

    _scheduleCouponSync();

    // Sepet durumunu güncelle
    NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);

    notifyListeners();
  }

  // Ürün miktarını güncelle
  void updateQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      // Ürünü miktarından bağımsız olarak tamamen çıkar.
      final index = _cartItems.indexWhere((i) => i.product.id == product.id);
      if (index < 0) return;
      _cartItems.removeAt(index);
      _databaseService.removeFromCart(product.id);
      _scheduleCouponSync();
      NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);
      notifyListeners();
      return;
    }

    final itemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (itemIndex >= 0) {
      _cartItems[itemIndex].quantity = quantity;
      _databaseService.saveCartItem(_cartItems[itemIndex]);

      _scheduleCouponSync();

      notifyListeners();
    }
  }

  // Sepeti temizle
  void clearCart() {
    _cartItems.clear();
    _databaseService.clearCart();

    // Kupon bilgilerini temizle
    _appliedCouponCode = null;
    _appliedCoupon = null;
    _discountAmount = 0;
    _couponError = null;
    _recommendedCoupon = null;

    // Sepet durumunu güncelle (Boş)
    NotificationService.instance.updateCartTag(false);
    _scheduleCartSync();

    notifyListeners();
  }

  // Kupon kodu doğrula ve uygula
  Future<bool> applyCoupon(String code) async {
    if (code.trim().isEmpty) {
      _couponError = 'Kupon kodunu yaz';
      notifyListeners();
      return false;
    }

    _isValidatingCoupon = true;
    _couponError = null;
    notifyListeners();
    final requestId = ++_couponRequestSeq;

    try {
      final response = await _apiService.validateCoupon(
        code.trim(),
        totalPrice,
        products: _couponProducts,
        channel: _channel,
      );

      if (response['success'] == true && response['coupon'] != null) {
        _appliedCouponCode = code.trim().toUpperCase();
        _appliedCoupon = Map<String, dynamic>.from(response['coupon']);
        _discountAmount =
            (response['coupon']['calculatedDiscount'] ?? 0).toDouble();
        _couponError = null;
        _isValidatingCoupon = false;
        // Doğrulama sürerken sepet değiştiyse indirim güncel sepete göre
        // yeniden hesaplanır.
        if (requestId != _couponRequestSeq) _scheduleCouponSync();
        notifyListeners();
        return true;
      } else {
        _couponError = response['message'] ?? 'Bu kupon geçerli değil';
        _isValidatingCoupon = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _couponError = e.toString().replaceAll('Exception: ', '');
      _isValidatingCoupon = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> validateCouponForDeliveryPoint(String deliveryPoint) async {
    if (_appliedCouponCode == null) return true;
    _isValidatingCoupon = true;
    _couponError = null;
    notifyListeners();
    try {
      final response = await _apiService.validateCoupon(
        _appliedCouponCode!,
        totalPrice,
        products: _couponProducts,
        channel: _channel,
        deliveryPoint: deliveryPoint,
      );
      if (response['success'] == true && response['coupon'] != null) {
        _appliedCoupon = Map<String, dynamic>.from(response['coupon']);
        _discountAmount =
            (response['coupon']['calculatedDiscount'] ?? 0).toDouble();
        return true;
      }
      _couponError = response['message'] ??
          'Bu kupon seçtiğin teslimat noktasında geçerli değil';
      return false;
    } catch (e) {
      _couponError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isValidatingCoupon = false;
      notifyListeners();
    }
  }

  // Kuponu kaldır
  void removeCoupon() {
    _appliedCouponCode = null;
    _appliedCoupon = null;
    _discountAmount = 0;
    _couponError = null;
    notifyListeners();
  }

  String get _channel => Platform.isIOS ? 'ios' : 'android';

  List<Map<String, dynamic>> get _couponProducts => _cartItems
      .map((item) => {'product': item.product.id, 'quantity': item.quantity})
      .toList();

  // Sepet telefonda tutulur. Sunucunun sepet hatırlatması ve "sepetinde ürün
  // olanlar" bildirimi gönderebilmesi için son hâli kısa bir beklemeyle
  // sunucuya bildirilir. Giriş yapılmamışsa ya da bağlantı yoksa atlanır.
  //
  // Boş sepet yalnızca bu oturumda sepette ürün görüldüyse bildirilir; yoksa
  // uygulamayı boş sepetle açmak, müşterinin web sitesinde doldurduğu sepeti
  // sunucudan silerdi.
  void _scheduleCartSync() {
    if (_cartItems.isNotEmpty) {
      _cartSeenFilled = true;
    } else if (!_cartSeenFilled) {
      return;
    }
    _cartSyncTimer?.cancel();
    _cartSyncTimer = Timer(const Duration(seconds: 2), _syncCartToServer);
  }

  Future<void> _syncCartToServer() async {
    try {
      if (!await TokenManager.hasToken()) return;
      await _apiService.syncCart([
        for (final item in _cartItems)
          {'productId': item.product.id, 'quantity': item.quantity},
      ]);
    } catch (_) {
      // Eşitleme isteğe bağlıdır; sepetin çalışmasını etkilemez
    }
  }

  void _scheduleCouponSync() {
    _scheduleCartSync();
    _couponSyncTimer?.cancel();
    _couponSyncTimer = Timer(const Duration(milliseconds: 400), _syncCoupon);
  }

  Future<void> _syncCoupon() async {
    final requestId = ++_couponRequestSeq;
    if (_cartItems.isEmpty) {
      _recommendedCoupon = null;
      return;
    }
    try {
      if (_appliedCouponCode != null) {
        final response = await _apiService.validateCoupon(
          _appliedCouponCode!,
          totalPrice,
          products: _couponProducts,
          channel: _channel,
        );
        // Bu arada yeni bir istek başladıysa bu yanıt eskidir
        if (requestId != _couponRequestSeq) return;
        if (response['success'] == true && response['coupon'] != null) {
          _appliedCoupon = Map<String, dynamic>.from(response['coupon']);
          _discountAmount =
              (response['coupon']['calculatedDiscount'] ?? 0).toDouble();
          _couponError = null;
        } else {
          _couponError =
              response['message'] ?? 'Kupon artık sepetin için geçerli değil';
          _appliedCouponCode = null;
          _appliedCoupon = null;
          _discountAmount = 0;
        }
      } else {
        final response = await _apiService.recommendCoupons(
          totalPrice,
          products: _couponProducts,
          channel: _channel,
        );
        if (requestId != _couponRequestSeq) return;
        _recommendedCoupon = response['bestCoupon'] == null
            ? null
            : Map<String, dynamic>.from(response['bestCoupon']);
      }
      notifyListeners();
    } catch (_) {
      // Ağ geçici olarak yoksa mevcut sepet akışı kesilmez; siparişte sunucu tekrar doğrular.
    }
  }

  @override
  void dispose() {
    _couponSyncTimer?.cancel();
    _cartSyncTimer?.cancel();
    super.dispose();
  }

  // Belirli ürünün sepetteki miktarını getir
  int getProductQuantity(String productId) {
    for (final item in _cartItems) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  // Ürün sepette var mı kontrol et
  bool isInCart(String productId) {
    return _cartItems.any((item) => item.product.id == productId);
  }
}
