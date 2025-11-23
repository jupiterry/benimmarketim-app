import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CategoryProductsViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String? _currentCategoryId;

  // Getters
  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentCategoryId => _currentCategoryId;

  // Kategori ürünlerini yükle
  Future<void> loadCategoryProducts(String categoryId) async {
    // Eğer aynı kategori zaten yüklüyse tekrar yükleme
    if (_currentCategoryId == categoryId && _products.isNotEmpty) {
      print(
        'CategoryProductsViewModel: Using cached products for category $categoryId',
      );
      return;
    }

    print(
      'CategoryProductsViewModel: Loading products for category: $categoryId',
    );
    _currentCategoryId = categoryId;
    _setLoading(true);
    _error = null;
    _products = []; // Önceki ürünleri temizle

    try {
      final allProducts = await _apiService.getProducts(category: categoryId);

      // Gizli ürünleri filtrele (isHidden: false olanları al)
      _products = allProducts.where((product) => !product.isHidden).toList();

      print(
        'CategoryProductsViewModel: Loaded ${_products.length} visible products (filtered ${allProducts.length - _products.length} hidden)',
      );
      notifyListeners();
    } catch (e) {
      print('CategoryProductsViewModel: Error loading products: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
