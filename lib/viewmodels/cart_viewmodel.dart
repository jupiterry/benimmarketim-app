import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';


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

  CartViewModel() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    final items = await _databaseService.getCartItems();
    _cartItems.addAll(items);
    
    // Uygulama açılışında sepet durumunu güncelle (OneSignal)
    NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);
    
    notifyListeners();
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
  double get finalPrice => (totalPrice - _discountAmount).clamp(0, double.infinity);

  // Sepete ürün ekle
  void addToCart(Product product) {
    final existingItemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingItemIndex >= 0) {
      // Ürün zaten sepette, miktarını artır
      _cartItems[existingItemIndex].quantity++;
      _databaseService.updateCartItemQuantity(
        product.id,
        _cartItems[existingItemIndex].quantity,
      );
    } else {
      // Yeni ürün ekle
      final newItem = CartItem(product: product);
      _cartItems.add(newItem);
      _databaseService.addToCart(newItem);
    }

    // Kupon indirimi varsa yeniden hesapla
    if (_appliedCouponCode != null) {
      _recalculateDiscount();
    }

    // Sepet durumunu güncelle (Dolu)
    NotificationService.instance.updateCartTag(true);

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

    // Kupon indirimi varsa yeniden hesapla
    if (_appliedCouponCode != null) {
      _recalculateDiscount();
    }
    
    // Sepet durumunu güncelle
    NotificationService.instance.updateCartTag(_cartItems.isNotEmpty);
    
    notifyListeners();
  }

  // Ürün miktarını güncelle
  void updateQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      removeFromCart(product);
      return;
    }

    final itemIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (itemIndex >= 0) {
      _cartItems[itemIndex].quantity = quantity;
      _databaseService.updateCartItemQuantity(product.id, quantity);
      
      // Kupon indirimi varsa yeniden hesapla
      if (_appliedCouponCode != null) {
        _recalculateDiscount();
      }
      
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
    
    // Sepet durumunu güncelle (Boş)
    NotificationService.instance.updateCartTag(false);
    
    notifyListeners();
  }

  // Kupon kodu doğrula ve uygula
  Future<bool> applyCoupon(String code) async {
    if (code.trim().isEmpty) {
      _couponError = 'Kupon kodu giriniz';
      notifyListeners();
      return false;
    }

    _isValidatingCoupon = true;
    _couponError = null;
    notifyListeners();

    try {
      final response = await _apiService.validateCoupon(code.trim(), totalPrice);
      
      if (response['success'] == true && response['coupon'] != null) {
        _appliedCouponCode = code.trim().toUpperCase();
        _appliedCoupon = response['coupon'];
        _discountAmount = (response['coupon']['calculatedDiscount'] ?? 0).toDouble();
        _couponError = null;
        _isValidatingCoupon = false;
        notifyListeners();
        return true;
      } else {
        _couponError = response['message'] ?? 'Kupon geçersiz';
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

  // Kuponu kaldır
  void removeCoupon() {
    _appliedCouponCode = null;
    _appliedCoupon = null;
    _discountAmount = 0;
    _couponError = null;
    notifyListeners();
  }

  // İndirim yeniden hesapla
  void _recalculateDiscount() {
    if (_appliedCoupon != null) {
      final discountType = _appliedCoupon!['discountType'] ?? 'percentage';
      final discountPercentage = (_appliedCoupon!['discountPercentage'] ?? 0).toDouble();
      final discountFixed = (_appliedCoupon!['discountAmount'] ?? 0).toDouble();
      final maxDiscount = _appliedCoupon!['maximumDiscount']?.toDouble();
      
      if (discountType == 'percentage') {
        _discountAmount = totalPrice * discountPercentage / 100;
        if (maxDiscount != null && _discountAmount > maxDiscount) {
          _discountAmount = maxDiscount;
        }
      } else {
        _discountAmount = discountFixed;
      }
      
      // Toplam fiyatı geçemez
      if (_discountAmount > totalPrice) {
        _discountAmount = totalPrice;
      }
    }
  }

  // Belirli ürünün sepetteki miktarını getir
  int getProductQuantity(String productId) {
    final item = _cartItems.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(
        product: Product(
          id: '',
          name: '',
          description: '',
          price: 0,
          originalPrice: 0,
          actualPrice: 0,
          image: '',
          category: '',
          categoryId: '',
          isDiscounted: false,
          isOutOfStock: false,
          isFeatured: false,
          isHidden: false,
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
    return item.quantity;
  }

  // Ürün sepette var mı kontrol et
  bool isInCart(String productId) {
    return _cartItems.any((item) => item.product.id == productId);
  }
}

