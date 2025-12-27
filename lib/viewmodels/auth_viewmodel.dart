import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../services/network_service.dart';


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
      print('İnternet bağlantısı kontrol ediliyor...');
      final hasInternet = await NetworkService.hasInternetConnection();
      if (!hasInternet) {
        _error =
            'İnternet bağlantısı bulunamadı. Lütfen bağlantınızı kontrol edin.';
        notifyListeners();
        return false;
      }

      print('İnternet bağlantısı başarılı, API denemesi yapılıyor...');

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

      print('Giriş başarılı - 10 günlük otomatik giriş aktif');



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

      print('Telefon ile kayıt yapıldı - 10 günlük otomatik giriş aktif');



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
      print('Token yenileniyor...');
      final newToken = await _apiService.refreshToken();

      if (newToken != null) {
        print('Token başarıyla yenilendi');
        return true;
      } else {
        print('Token yenilenemedi, logout yapılıyor');
        await logout();
        return false;
      }
    } catch (e) {
      print('Token yenileme hatası: $e');
      await logout();
      return false;
    }
  }

  // Profil bilgilerini güncelle
  Future<void> updateProfile() async {
    if (!_isLoggedIn) {
      print('updateProfile: Kullanıcı giriş yapmamış');
      return;
    }

    try {
      print('updateProfile: Profil bilgileri yükleniyor...');
      _user = await _apiService.getProfile();
      print('updateProfile: Profil bilgileri yüklendi: ${_user?.name}');
      notifyListeners();
    } catch (e) {
      print('updateProfile: Hata: $e');
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
          print('Token süresi dolmuş, temizleniyor...');
          await TokenManager.clearAllTokens();
          _isLoggedIn = false;
          _user = null;
          notifyListeners();
          return;
        }

        print('checkAuthStatus: Profil bilgileri yükleniyor...');
        _user = await _apiService.getProfile();
        _isLoggedIn = true;
        print(
          'checkAuthStatus: Otomatik giriş başarılı - User: ${_user?.name}',
        );
        notifyListeners();
      } catch (e) {
        // Token geçersiz veya API hatası, logout yap
        print('checkAuthStatus: Token kontrolü hatası: $e');
        await TokenManager.clearAllTokens();
        _isLoggedIn = false;
        _user = null;
        notifyListeners();
      }
    } else {
      print('checkAuthStatus: Token bulunamadı veya geçersiz');
      _isLoggedIn = false;
      _user = null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
