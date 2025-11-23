import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';

class SearchViewModel extends ChangeNotifier {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<models.Category> _categories = [];

  String _searchQuery = '';
  String _selectedCategory = '';
  String _sortBy = 'name'; // name, price, popularity
  double _minPrice = 0;
  double _maxPrice = 1000;
  bool _isLoading = false;

  // Getters
  List<Product> get filteredProducts => _filteredProducts;
  List<models.Category> get categories => _categories;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get sortBy => _sortBy;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  bool get isLoading => _isLoading;

  // Set all products
  void setProducts(List<Product> products) {
    _allProducts = products;
    _applyFilters();
  }

  // Set categories
  void setCategories(List<models.Category> categories) {
    _categories = categories;
    notifyListeners();
  }

  // Search
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Arama yap
  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final apiService = ApiService();
      final searchResult = await apiService.searchProducts(
        query: query,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 1000 ? _maxPrice : null,
        sort: _sortBy,
      );

      // Gizli ürünleri filtrele
      _filteredProducts = searchResult.products
          .where((product) => !product.isHidden)
          .toList();
    } catch (e) {
      _filteredProducts = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Category filter
  void setSelectedCategory(String categoryId) {
    _selectedCategory = categoryId;
    _applyFilters();
  }

  // Sort
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
  }

  // Price range
  void setPriceRange(double min, double max) {
    _minPrice = min;
    _maxPrice = max;
    _applyFilters();
  }

  // Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = '';
    _sortBy = 'name';
    _minPrice = 0;
    _maxPrice = 1000;
    _applyFilters();
  }

  // Apply all filters
  void _applyFilters() {
    _isLoading = true;
    notifyListeners();

    List<Product> filtered = List.from(_allProducts);

    // Gizli ürünleri filtrele (isHidden: false olanları al)
    filtered = filtered.where((product) => !product.isHidden).toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            product.description.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    // Category filter
    if (_selectedCategory.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.categoryId == _selectedCategory;
      }).toList();
    }

    // Price filter
    filtered = filtered.where((product) {
      return product.actualPrice >= _minPrice &&
          product.actualPrice <= _maxPrice;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'price_low':
        filtered.sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
        break;
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'popularity':
        // Bu örnekte rastgele sıralama yapıyoruz
        filtered.shuffle();
        break;
    }

    _filteredProducts = filtered;
    _isLoading = false;
    notifyListeners();
  }

  // Get available price range
  double get minAvailablePrice {
    if (_allProducts.isEmpty) return 0;
    return _allProducts
        .map((p) => p.actualPrice)
        .reduce((a, b) => a < b ? a : b);
  }

  double get maxAvailablePrice {
    if (_allProducts.isEmpty) return 1000;
    return _allProducts
        .map((p) => p.actualPrice)
        .reduce((a, b) => a > b ? a : b);
  }
}
