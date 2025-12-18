import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> init() async {
    // OneSignal Başlat
    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize("6469a309-0cce-496c-bc0c-e993566e421d");

    // Bildirim izni iste (OneSignal) - UI hazır olana kadar bekle
    await Future.delayed(const Duration(seconds: 1));
    var accepted = await OneSignal.Notifications.requestPermission(true);
    print("OneSignal Permission accepted: $accepted");

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
    print('Notification tapped: ${response.payload}');
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

  // --- OneSignal Tag Yönetimi (Sepet Takibi) ---
  Future<void> updateCartTag(bool hasItems) async {
    if (hasItems) {
      print("OneSignal Tag: cart_status = dolu");
      OneSignal.User.addTagWithKey("cart_status", "dolu");
      // Son güncelleme zamanını ekle (timestamp)
      OneSignal.User.addTagWithKey(
          "last_cart_update", DateTime.now().millisecondsSinceEpoch.toString());
    } else {
      print("OneSignal Tag: cart_status removed");
      OneSignal.User.removeTag("cart_status");
      OneSignal.User.removeTag("last_cart_update");
    }
  }
}
