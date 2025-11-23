import 'package:flutter/foundation.dart';
import '../models/category.dart' as models;
import '../services/api_service.dart';

class CategoryViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<models.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _apiService.getCategories();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Category loading error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  models.Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  List<models.Category> getActiveCategories() {
    return _categories.where((category) => category.isActive).toList();
  }
}
