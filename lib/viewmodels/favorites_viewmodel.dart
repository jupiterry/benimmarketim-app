import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/product.dart';

class FavoritesViewModel extends ChangeNotifier {
  List<Product> _favorites = [];
  bool _isLoading = false;
  final DatabaseService _databaseService = DatabaseService();

  List<Product> get favorites => _favorites;
  bool get isLoading => _isLoading;
  int get favoritesCount => _favorites.length;

  FavoritesViewModel() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      _favorites = await _databaseService.getFavorites();
    } catch (e) {
      print('Favoriler yüklenirken hata: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(String productId) {
    return _favorites.any((product) => product.id == productId);
  }

  Future<void> toggleFavorite(Product product) async {
    if (isFavorite(product.id)) {
      _favorites.removeWhere((p) => p.id == product.id);
      await _databaseService.removeFromFavorites(product.id);
    } else {
      _favorites.add(product);
      await _databaseService.addToFavorites(product);
    }
    notifyListeners();
  }

  Future<void> removeFavorite(String productId) async {
    _favorites.removeWhere((product) => product.id == productId);
    await _databaseService.removeFromFavorites(productId);
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _databaseService.clearFavorites();
    notifyListeners();
  }
}
