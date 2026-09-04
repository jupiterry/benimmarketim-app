import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, dynamic> _settings = {};
  bool _isLoading = false;
  String? _error;

  SettingsViewModel() {
    loadSettings();
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    // Her 5 saniyede bir ayarları güncelle (kullanıcı görmeden)
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isLoading) {
        _loadSettingsSilently();
      }
      _startPeriodicUpdate(); // Kendini tekrarla
    });
  }

  Future<void> _loadSettingsSilently() async {
    try {
      final settings = await _apiService.getSettings();
      _settings = settings;
      // notifyListeners() çağrılmıyor - kullanıcı görmez
    } catch (e) {
      // Sessizce hata yok sayılır
    }
  }

  Map<String, dynamic> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Minimum sipariş tutarı
  double get minimumOrderAmount =>
      _settings['minimumOrderAmount']?.toDouble() ?? 250.0;

  // Sipariş saatleri
  int get orderStartHour => _settings['orderStartHour'] ?? 10;
  int get orderStartMinute => _settings['orderStartMinute'] ?? 0;
  int get orderEndHour => _settings['orderEndHour'] ?? 1;
  int get orderEndMinute => _settings['orderEndMinute'] ?? 0;

  // Teslimat noktaları
  bool get girlsDormEnabled =>
      _settings['deliveryPoints']?['girlsDorm']?['enabled'] ?? false;
  bool get boysDormEnabled =>
      _settings['deliveryPoints']?['boysDorm']?['enabled'] ?? false;

  // Teslimat noktası isimleri
  String get girlsDormName =>
      _settings['deliveryPoints']?['girlsDorm']?['name'] ?? 'Kız KYK Yurdu';
  String get boysDormName =>
      _settings['deliveryPoints']?['boysDorm']?['name'] ?? 'Erkek KYK Yurdu';

  // Ayarları yükle
  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final settings = await _apiService.getSettings();
      _settings = settings;
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Settings load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ayarları güncelle (admin için)
  Future<bool> updateSettings(Map<String, dynamic> newSettings) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // API'ye PUT request gönder - ApiService'e method ekleyeceğiz
      // Şimdilik sadece local güncelleme yapalım
      _settings = {..._settings, ...newSettings};
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      print('Settings update error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sipariş saatleri kontrolü
  bool get isWithinOrderHours {
    // İşletme Türkiye'de çalıştığı için cihazın/emülatörün saat dilimine
    // güvenmeyiz. Türkiye 2016'dan beri yıl boyunca UTC+3 kullanıyor.
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final currentHour = now.hour;
    final currentMinute = now.minute;

    final startTime = orderStartHour * 60 + orderStartMinute;
    final endTime = orderEndHour * 60 + orderEndMinute;
    final currentTime = currentHour * 60 + currentMinute;

    // 00:00–00:00, yönetim panelinde 24 saat açık anlamına gelir.
    if (startTime == 0 && endTime == 0) {
      return true;
    }

    // Gece yarısını geçen saatler için özel kontrol
    if (endTime <= startTime) {
      return currentTime >= startTime || currentTime <= endTime;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  // Sipariş saatleri mesajı
  String get orderHoursMessage {
    if (isWithinOrderHours) {
      return 'Sipariş saatleri içindeyiz';
    } else {
      return 'Siparişler sadece ${orderStartHour.toString().padLeft(2, '0')}:${orderStartMinute.toString().padLeft(2, '0')} ile ${orderEndHour.toString().padLeft(2, '0')}:${orderEndMinute.toString().padLeft(2, '0')} arasında verilebilir';
    }
  }
}
