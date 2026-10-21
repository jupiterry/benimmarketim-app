import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class NotificationService {
  static NotificationService? _instance;

  /// Bildirim izni bir kez sorulur; sonucu ne olursa olsun tekrar sorulmaz
  /// (kullanıcı isterse sistem ayarlarından açar).
  static const String _permissionAskedKey = 'notif_permission_asked';

  bool _oneSignalReady = false;
  String? _pendingUserId;

  // Bildirime dokununca açılabilecek ekranlar (sunucudaki listeyle aynı)
  static final RegExp _allowedRoute = RegExp(
      r'^/(home|cart|orders|referral|feedback|photocopy-history|rate-app|chat(/[a-fA-F0-9]{24})?)$');
  void Function(String route)? _onOpenRoute;
  String? _pendingRoute;

  /// O an açık olan ekranın yolunu döndürür (main.dart tarafından verilir).
  String? Function()? currentLocation;

  /// Bildirime dokunulduğunda çağrılacak yönlendirici. Uygulama bildirimle
  /// açıldıysa bekleyen yönlendirme hemen iletilir.
  set onOpenRoute(void Function(String route)? handler) {
    _onOpenRoute = handler;
    final pending = _pendingRoute;
    if (handler != null && pending != null) {
      _pendingRoute = null;
      handler(pending);
    }
  }

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> init() async {
    // OneSignal Başlat
    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize("6469a309-0cce-496c-bc0c-e993566e421d");
    _oneSignalReady = true;
    _registerOneSignalListeners();
    // Başlatmadan önce giriş yapılmışsa bekleyen kullanıcıyı şimdi eşle
    final pending = _pendingUserId;
    if (pending != null) {
      _pendingUserId = null;
      await identifyUser(pending);
    }

    // Bildirim izni burada İSTENMEZ: açılışta sistem penceresi çıkmasın
    // diye izin, onboarding bitince ya da ilk sepet/sipariş ekranında
    // [requestPermissionIfNeeded] ile sorulur.
  }

  /// Bildirim izni daha önce sorulmadıysa sorar. Sorulduysa (ya da OneSignal
  /// hazır değilse) hiçbir şey yapmaz. Dönüş: izin verildi mi.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_oneSignalReady) return false;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_permissionAskedKey) == true) {
        return OneSignal.Notifications.permission;
      }
    } catch (e) {
      AppLogger.debug('Bildirim izni bayrağı okunamadı: $e');
    }
    try {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      AppLogger.debug('OneSignal Permission accepted: $accepted');
      await prefs?.setBool(_permissionAskedKey, true);
      return accepted;
    } catch (e) {
      AppLogger.debug('OneSignal izin isteği hatası: $e');
      return false;
    }
  }

  // --- OneSignal Bildirim Olayları ---
  String? _routeFromData(Map<String, dynamic>? data) {
    final route = data?['route'];
    if (route is String && _allowedRoute.hasMatch(route)) return route;
    return null;
  }

  void _registerOneSignalListeners() {
    // Bildirime dokunulduğunda ilgili ekranı aç
    OneSignal.Notifications.addClickListener((event) {
      final route = _routeFromData(event.notification.additionalData);
      if (route == null) return;
      final handler = _onOpenRoute;
      if (handler != null) {
        handler(route);
      } else {
        _pendingRoute = route;
      }
    });

    // Kullanıcı zaten o sohbet ekranındaysa mesaj bildirimini ayrıca gösterme
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      final route = _routeFromData(data);
      if (data?['type'] == 'chat_message' &&
          route != null &&
          currentLocation?.call() == route) {
        event.preventDefault();
      }
    });
  }

  // --- OneSignal Kullanıcı Eşleme (Sipariş durumu bildirimleri) ---
  // Sunucu, bildirimi kullanıcı kimliğiyle (external_id) hedefler.
  Future<void> identifyUser(String userId) async {
    if (userId.isEmpty) return;
    if (!_oneSignalReady) {
      _pendingUserId = userId;
      return;
    }
    try {
      await OneSignal.login(userId);
      AppLogger.debug("OneSignal: kullanıcı eşlendi");
    } catch (e) {
      AppLogger.debug("OneSignal login hatası: $e");
    }
  }

  Future<void> clearUser() async {
    _pendingUserId = null;
    if (!_oneSignalReady) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      AppLogger.debug("OneSignal logout hatası: $e");
    }
  }

  // --- OneSignal Tag Yönetimi (Sepet Takibi) ---
  Future<void> updateCartTag(bool hasItems) async {
    if (hasItems) {
      AppLogger.debug("OneSignal Tag: cart_status = dolu");
      OneSignal.User.addTagWithKey("cart_status", "dolu");
      // Son güncelleme zamanını ekle (timestamp)
      OneSignal.User.addTagWithKey(
          "last_cart_update", DateTime.now().millisecondsSinceEpoch.toString());
    } else {
      AppLogger.debug("OneSignal Tag: cart_status removed");
      OneSignal.User.removeTag("cart_status");
      OneSignal.User.removeTag("last_cart_update");
    }
  }
}
