import 'package:flutter/foundation.dart';
import '../models/flash_sale.dart';
import '../services/api_service.dart';

class FlashSaleViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<FlashSale> _flashSales = [];
  bool _isLoading = false;
  String? _error;

  List<FlashSale> get flashSales => _flashSales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Aktif flash sale'leri getir
  List<FlashSale> get activeFlashSales {
    return _flashSales.where((flashSale) => flashSale.isCurrentlyActive).toList();
  }

  // Flash sale'leri yükle
  Future<void> loadFlashSales() async {
    _setLoading(true);
    _error = null;

    try {
      final flashSales = await _apiService.getFlashSales();
      _flashSales = flashSales;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Flash sale oluştur (admin)
  Future<bool> createFlashSale({
    required String productId,
    required String name,
    required double discountPercentage,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final flashSale = await _apiService.createFlashSale(
        productId: productId,
        name: name,
        discountPercentage: discountPercentage,
        startDate: startDate,
        endDate: endDate,
      );
      
      _flashSales.add(flashSale);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Flash sale güncelle (admin)
  Future<bool> updateFlashSale({
    required String id,
    required String name,
    required double discountPercentage,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
  }) async {
    try {
      final updatedFlashSale = await _apiService.updateFlashSale(
        id: id,
        name: name,
        discountPercentage: discountPercentage,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
      );
      
      final index = _flashSales.indexWhere((fs) => fs.id == id);
      if (index != -1) {
        _flashSales[index] = updatedFlashSale;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Flash sale sil (admin)
  Future<bool> deleteFlashSale(String id) async {
    try {
      await _apiService.deleteFlashSale(id);
      _flashSales.removeWhere((fs) => fs.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
