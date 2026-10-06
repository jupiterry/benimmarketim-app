import 'package:flutter/foundation.dart';
import '../models/banner.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';

class BannerViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Banner> _banners = [];
  bool _isLoading = false;
  String? _error;

  List<Banner> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBanners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _banners = await _apiService.getBanners();
      _error = null;
      AppLogger.debug('BannerViewModel: Loaded ${_banners.length} banners');
    } catch (e) {
      _error = e.toString();
      AppLogger.debug('BannerViewModel: Error loading banners: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

