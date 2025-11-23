import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> init() async {
    // İzin iste
    await _requestPermissions();

    // Local notifications ayarla
    await _initLocalNotifications();

    // Firebase messaging ayarla
    await _initFirebaseMessaging();
  }

  Future<void> _requestPermissions() async {
    // Bildirim izni
    await Permission.notification.request();
    
    // Android 13+ için özel izin
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
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

  Future<void> _initFirebaseMessaging() async {
    // FCM token al
    final token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Foreground mesajları dinle
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background mesajları dinle
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Notification tap'leri dinle
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında yapılacak işlemler
    print('Notification tapped: ${response.payload}');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.notification?.title}');
    
    // Local notification göster
    await showLocalNotification(
      title: message.notification?.title ?? 'Yeni Bildirim',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Background message: ${message.notification?.title}');
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.data}');
    // Uygulama açıkken bildirime tıklandığında yapılacak işlemler
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
}
