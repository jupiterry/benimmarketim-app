import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../services/notification_service.dart';


class CartViewModel extends ChangeNotifier {
  final List<CartItem> _cartItems = [];
  final DatabaseService _databaseService = DatabaseService();


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
      notifyListeners();
    }
  }

  // Sepeti temizle
  void clearCart() {
    _cartItems.clear();
    _databaseService.clearCart();
    
    // Sepet durumunu güncelle (Boş)
    NotificationService.instance.updateCartTag(false);
    
    notifyListeners();
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
