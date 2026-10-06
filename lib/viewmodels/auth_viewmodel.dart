import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../services/network_service.dart';
import '../services/app_logger.dart';
import '../services/notification_service.dart';


class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();


  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  // Giriş yap
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      // Çoklu internet kontrolü
      AppLogger.debug('İnternet bağlantısı kontrol ediliyor...');
      final hasInternet = await NetworkService.hasInternetConnection();
      if (!hasInternet) {
        _error =
            'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin.';
        notifyListeners();
        return false;
      }

      AppLogger.debug('İnternet bağlantısı başarılı, API denemesi yapılıyor...');

      final request = LoginRequest(
        email: email,
        password: password,
        deviceType: 'mobile', // API dökümanına uygun sabit değer
      );
      final response = await _apiService.login(request);

      _user = response.user;
      _isLoggedIn = true;

      // Token'ı sakla - TÜM GİRİŞLER için 10 günlük otomatik giriş aktif
      await TokenManager.saveAccessToken(
        response.accessToken,
        isPhoneLogin: true,
      );
      await TokenManager.saveRefreshToken(response.refreshToken);

      AppLogger.debug('Giriş başarılı - 10 günlük otomatik giriş aktif');
      NotificationService.instance.identifyUser(response.user.id);



      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Kayıt ol
  Future<bool> register(
    String name,
    String email,
    String password,
    String phone, {
    String? referralCode,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // API dökümanına göre deviceType 'mobile' olmalı (Android/iOS ayrımı yerine genel tip)
      final request = RegisterRequest(
        name: name,
        email: email,
        password: password,
        phone: phone,
        deviceType: 'mobile',
        referralCode: referralCode,
      );
      final response = await _apiService.register(request);

      _user = response.user;
      _isLoggedIn = true;

      // Telefon numarası ile kayıt olduğu için 10 günlük otomatik giriş akt if
      await TokenManager.saveAccessToken(
        response.accessToken,
        isPhoneLogin: true,
      );
      await TokenManager.saveRefreshToken(response.refreshToken);

      AppLogger.debug('Telefon ile kayıt yapıldı - 10 günlük otomatik giriş aktif');
      NotificationService.instance.identifyUser(response.user.id);



      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      // Hata olsa bile local logout yap
    }

    _user = null;
    _isLoggedIn = false;
    await TokenManager.clearAllTokens();
    NotificationService.instance.clearUser();



    notifyListeners();
  }

  // Hesap silme
  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      await _apiService.deleteAccount();

      // Başarılı silme sonrası logout işlemleri
      _user = null;
      _isLoggedIn = false;
      await TokenManager.clearAllTokens();
      NotificationService.instance.clearUser();


      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Token yenileme (web projesindeki refresh token sistemi)
  Future<bool> refreshToken() async {
    try {
      AppLogger.debug('Token yenileniyor...');
      final newToken = await _apiService.refreshToken();

      if (newToken != null) {
        AppLogger.debug('Token başarıyla yenilendi');
        return true;
      } else {
        AppLogger.debug('Token yenilenemedi, logout yapılıyor');
        await logout();
        return false;
      }
    } catch (e) {
      AppLogger.debug('Token yenileme hatası: $e');
      await logout();
      return false;
    }
  }

  // Profil bilgilerini güncelle
  Future<void> updateProfile() async {
    if (!_isLoggedIn) {
      AppLogger.debug('updateProfile: Kullanıcı giriş yapmamış');
      return;
    }

    try {
      AppLogger.debug('updateProfile: Profil bilgileri yükleniyor...');
      _user = await _apiService.getProfile();
      AppLogger.debug('updateProfile: Profil bilgileri yüklendi');
      notifyListeners();
    } catch (e) {
      AppLogger.debug('updateProfile: Hata: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // Uygulama başlatıldığında token kontrolü
  Future<void> checkAuthStatus() async {
    final hasToken = await TokenManager.hasToken();
    if (hasToken) {
      try {
        // Token geçerliyse (10 gün içindeyse) otomatik giriş yap
        final isValid = await TokenManager.isTokenValid();
        if (!isValid) {
          // Token süresi dolmuş, temizle
          AppLogger.debug('Token süresi dolmuş, temizleniyor...');
          await TokenManager.clearAllTokens();
          _isLoggedIn = false;
          _user = null;
          notifyListeners();
          return;
        }

        AppLogger.debug('checkAuthStatus: Profil bilgileri yükleniyor...');
        _user = await _apiService.getProfile();
        _isLoggedIn = true;
        AppLogger.debug('checkAuthStatus: Otomatik giriş başarılı');
        NotificationService.instance.identifyUser(_user!.id);
        notifyListeners();
      } catch (e) {
        // Token geçersiz veya API hatası, logout yap
        AppLogger.debug('checkAuthStatus: Token kontrolü hatası: $e');
        await TokenManager.clearAllTokens();
        _isLoggedIn = false;
        _user = null;
        notifyListeners();
      }
    } else {
      AppLogger.debug('checkAuthStatus: Token bulunamadı veya geçersiz');
      _isLoggedIn = false;
      _user = null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
