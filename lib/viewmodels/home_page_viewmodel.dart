import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class HomePageViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<Product> _personalizedProducts = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Product> get products => _products;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get personalizedProducts => _personalizedProducts;
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

  // Constructor'da yükleme yapma, UI'dan tetiklenecek

  // Ana sayfa ürünlerini yükle (kullanıcıya hızlı keşif için sınırlı liste)
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
      // Ürünleri ve öne çıkanları paralel yükle
      final results = await Future.wait([
        _apiService.getProducts(),
        _apiService.getFeaturedProducts(),
        _apiService.getPersonalizedProducts(),
      ]);

      final allProducts = results[0] as List<Product>;
      _featuredProducts = results[1] as List<Product>;
      _personalizedProducts = results[2] as List<Product>;

      if (allProducts.isNotEmpty) {
        // Gizli ürünleri filtrele (isHidden: false olanları al)
        final visibleProducts =
            allProducts.where((product) => !product.isHidden).toList();

        // Listeyi karıştırmadan sırayı koru; ürün keşfi tutarlı kalsın.
        _products = visibleProducts.take(50).toList();
        print(
          'HomePageViewModel: Selected 50 random visible products (filtered ${allProducts.length - visibleProducts.length} hidden)',
        );
      } else {
        _products = [];
      }

      notifyListeners();
    } catch (e) {
      print('HomePageViewModel: Error loading products: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Manuel yenileme için (Pull to refresh vb.)
  Future<void> refreshProducts() async {
    _products.clear(); // Cache'i temizle
    _personalizedProducts.clear();
    await loadHomeProducts();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
