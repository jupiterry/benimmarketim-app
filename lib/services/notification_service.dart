import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'app_logger.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _oneSignalReady = false;
  String? _pendingUserId;

  // Bildirime dokununca açılabilecek ekranlar (sunucudaki listeyle aynı)
  static final RegExp _allowedRoute = RegExp(
      r'^/(home|cart|orders|referral|photocopy-history|chat(/[a-fA-F0-9]{24})?)$');
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

    // Bildirim izni iste (OneSignal) - UI hazır olana kadar bekle
    await Future.delayed(const Duration(seconds: 1));
    var accepted = await OneSignal.Notifications.requestPermission(true);
    AppLogger.debug("OneSignal Permission accepted: $accepted");

    // İzin iste (Local) - Kaldırıldı, OneSignal halletmeli
    // await _requestPermissions();

    // Local notifications ayarla
    await _initLocalNotifications();
  }



  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında yapılacak işlemler
    AppLogger.debug('Notification tapped');
  }

  // Local notification göster
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benimmarketim_channel',
      'Benim Marketim Bildirimleri',
      channelDescription: 'Benim Marketim uygulaması bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Sipariş bildirimi göster
  Future<void> showOrderNotification({
    required String orderId,
    required String status,
    required String message,
  }) async {
    await showLocalNotification(
      title: 'Sipariş Güncellemesi',
      body: message,
      payload: 'order:$orderId',
    );
  }

  // Promosyon bildirimi göster
  Future<void> showPromotionNotification({
    required String title,
    required String message,
  }) async {
    await showLocalNotification(
      title: title,
      body: message,
      payload: 'promotion',
    );
  }

  // Bildirimleri temizle
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Belirli bildirimi iptal et
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
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
