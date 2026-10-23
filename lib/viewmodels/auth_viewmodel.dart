import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../services/app_logger.dart';
import '../services/meta_app_events_service.dart';
import '../services/notification_service.dart';


class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Token yenilenemeyince ApiService oturumu düşürür; burada ekran durumu
  // da buna uydurulur (kullanıcı tekrar giriş yapana kadar misafir).
  late final StreamSubscription<void> _sessionExpiredSubscription;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AuthViewModel() {
    _sessionExpiredSubscription =
        ApiService.onSessionExpired.listen((_) => _onSessionExpired());
  }

  @override
  void dispose() {
    _sessionExpiredSubscription.cancel();
    super.dispose();
  }

  Future<void> _onSessionExpired() async {
    if (!_isLoggedIn && _user == null) return;
    AppLogger.debug('Oturum süresi doldu, yerel oturum kapatılıyor');
    _user = null;
    _isLoggedIn = false;
    await NotificationService.instance.clearUser();
    notifyListeners();
  }

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

      AppLogger.debug('Giriş başarılı');
      NotificationService.instance.identifyUser(response.user.id);
      unawaited(MetaAppEventsService.instance.logLogin());



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

      AppLogger.debug('Kayıt başarılı');
      NotificationService.instance.identifyUser(response.user.id);
      unawaited(MetaAppEventsService.instance.logCompleteRegistration(
        withReferral: referralCode != null && referralCode.trim().isNotEmpty,
      ));



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
      final user = await _apiService.getProfile();
      _user = user;
      AppLogger.debug('updateProfile: Profil bilgileri yüklendi');
      if (user.id.isNotEmpty) {
        NotificationService.instance.identifyUser(user.id);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.debug('updateProfile: Hata: $e');
      _error = e.toString();
      // Bilerek notifyListeners çağrılmaz: profil ekranı kullanıcı yokken
      // her çizimde updateProfile'ı yeniden dener; bildirim yapılsaydı ağ
      // hatasında sonsuz istek döngüsü oluşurdu.
    }
  }

  /// Telefon numarasını günceller. Başarılıysa null, değilse hata mesajı döner.
  Future<String?> updatePhone(String phone) async {
    try {
      final savedPhone = await _apiService.updatePhone(phone);
      final current = _user;
      if (current != null) {
        _user = current.copyWith(phone: savedPhone);
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Profil fotoğrafını yükler. Başarılıysa null, değilse hata mesajı döner.
  Future<String?> uploadProfilePhoto(Uint8List bytes) async {
    try {
      final avatar = await _apiService.uploadProfilePhoto(bytes);
      final current = _user;
      if (current != null) {
        _user = current.copyWith(avatar: avatar);
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Profil fotoğrafını kaldırır. Başarılıysa null, değilse hata mesajı döner.
  Future<String?> removeProfilePhoto() async {
    try {
      await _apiService.removeProfilePhoto();
      final current = _user;
      if (current != null) {
        _user = current.copyWith(clearAvatar: true);
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  // Uygulama başlatıldığında token kontrolü
  Future<void> checkAuthStatus() async {
    final hasToken = await TokenManager.hasToken();
    if (!hasToken) {
      AppLogger.debug('checkAuthStatus: Token bulunamadı');
      _isLoggedIn = false;
      _user = null;
      return;
    }

    try {
      AppLogger.debug('checkAuthStatus: Profil bilgileri yükleniyor...');
      final user = await _apiService.getProfile();
      _user = user;
      _isLoggedIn = true;
      AppLogger.debug('checkAuthStatus: Otomatik giriş başarılı');
      if (user.id.isNotEmpty) {
        NotificationService.instance.identifyUser(user.id);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.debug('checkAuthStatus: Token kontrolü hatası: $e');
      final status = e is ApiException ? e.statusCode : null;
      final stillHasToken = await TokenManager.hasToken();
      if (status == 401 || status == 403 || !stillHasToken) {
        // Sunucu oturumu reddetti (refresh de başarısız): çıkış yap
        await TokenManager.clearAllTokens();
        _isLoggedIn = false;
        _user = null;
      } else {
        // Ağ/sunucu hatası: token'lar korunur; profil ana sayfada tekrar
        // denenir (HomePage, kullanıcı yoksa updateProfile çağırır).
        _isLoggedIn = true;
        _user = null;
      }
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
