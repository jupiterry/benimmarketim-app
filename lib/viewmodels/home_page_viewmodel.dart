import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class HomePageViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Product> get products => _products;
  List<Product> get featuredProducts => _featuredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constructor'da yükleme yapma, UI'dan tetiklenecek

  // Ana sayfa ürünlerini yükle (Rastgele 50)
  Future<void> loadHomeProducts() async {
    // Eğer zaten ürün varsa tekrar yükleme (Session Persistence)
    if (_products.isNotEmpty) {
      print('HomePageViewModel: Using cached products');
      return;
    }

    print('HomePageViewModel: Loading fresh home products');
    _setLoading(true);
    _error = null;

    try {
      // Tüm ürünleri çek
      final allProducts = await _apiService.getProducts();

      if (allProducts.isNotEmpty) {
        // Gizli ürünleri filtrele (isHidden: false olanları al)
        final visibleProducts = allProducts
            .where((product) => !product.isHidden)
            .toList();

        // Listeyi karıştır
        visibleProducts.shuffle();

        // İlk 50 tanesini al
        _products = visibleProducts.take(50).toList();
        print(
          'HomePageViewModel: Selected 50 random visible products (filtered ${allProducts.length - visibleProducts.length} hidden)',
        );
      } else {
        _products = [];
      }

      // Öne çıkanları da yükle
      await _loadFeaturedProducts();

      notifyListeners();
    } catch (e) {
      print('HomePageViewModel: Error loading products: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Öne çıkan ürünleri yükle
  Future<void> _loadFeaturedProducts() async {
    try {
      _featuredProducts = await _apiService.getFeaturedProducts();
    } catch (e) {
      print('HomePageViewModel: Error loading featured products: $e');
      // Hata durumunda mevcut ürünlerden seç
      _featuredProducts = _products.where((p) => p.isFeatured).take(4).toList();
    }
  }

  // Manuel yenileme için (Pull to refresh vb.)
  Future<void> refreshProducts() async {
    _products.clear(); // Cache'i temizle
    await loadHomeProducts();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
