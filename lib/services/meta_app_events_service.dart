import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import 'app_logger.dart';

/// Kullanıcının Meta reklam ölçümü kararı.
enum MetaTrackingConsent { unknown, granted, denied }

/// Meta ölçümünün çalıştığı platform.
enum MetaPlatform { android, ios, unsupported }

/// iOS App Tracking Transparency (ATT) durumu. Android'de her zaman
/// [authorized] sayılır.
enum TrackingStatus { notDetermined, authorized, denied, restricted }

/// iOS'un "Uygulamanın izlemesine izin ver" penceresi (ATT). Mevcut
/// `permission_handler` paketiyle sorulur; Podfile'da
/// `PERMISSION_APP_TRACKING_TRANSPARENCY=1` gerekir.
class TrackingAuthorization {
  const TrackingAuthorization();

  Future<TrackingStatus> status() async =>
      _map(await Permission.appTrackingTransparency.status);

  /// Durum belirsizse sistem penceresini gösterir; değilse mevcut durumu
  /// döndürür (iOS pencereyi bir kez gösterir).
  Future<TrackingStatus> request() async =>
      _map(await Permission.appTrackingTransparency.request());

  /// iPhone Ayarlar'da uygulamanın sayfasını açar.
  Future<bool> openSettings() => openAppSettings();

  static TrackingStatus _map(PermissionStatus status) {
    // permission_handler: belirsiz → denied, reddedildi → permanentlyDenied
    if (status == PermissionStatus.granted) return TrackingStatus.authorized;
    if (status == PermissionStatus.denied) return TrackingStatus.notDetermined;
    if (status == PermissionStatus.restricted) return TrackingStatus.restricted;
    return TrackingStatus.denied;
  }
}

/// Meta (Facebook) uygulama olayları: uygulama açılışı/kurulum, sepete
/// ekleme ve sipariş (Purchase).
///
/// İzin verilmeden Meta'ya hiçbir uygulama olayı gönderilmez ve reklam
/// kimliği toplanmaz. AndroidManifest ve Info.plist'te otomatik olay kaydı
/// ve reklam kimliği toplama kapalı başlar.
///
/// Android, izin verildiğinde:
/// - Kurulum ve uygulama açılışları SDK tarafından ölçülür. Otomatik kayıt
///   ayarı SDK'ya kalıcı yazıldığı için sonraki açılışlarda ölçüm uygulama
///   başlarken (Dart'tan önce) başlar; bu yüzden sonraki açılışlarda burada
///   `activateApp` çağrılmaz, açılış iki kez sayılmaz.
///
/// iOS:
/// - Info.plist'teki `FacebookAutoInitEnabled=false` SDK'yı izin gelene kadar
///   tamamen uykuda tutar (Meta'ya hiçbir bağlantı kurulmaz).
/// - Ölçüm yalnızca uygulama içi izin VE iOS izleme izni (ATT) birlikte
///   verildiyse açılır. iPhone izlemeye izin vermediyse hiçbir olay
///   gönderilmez.
/// - Otomatik kayıt iOS'ta kapalı kalır; açılış her süreçte bir kez ve
///   uygulama arka plandan her döndüğünde buradan elle bildirilir (SDK geç
///   başlatıldığı için iOS'un ilk "aktif oldu" anını kaçırır).
///
/// Sepete ekleme ve Purchase olayları her iki platformda yalnızca buradan,
/// elle gönderilir.
class MetaAppEventsService {
  MetaAppEventsService({
    FacebookAppEvents? sdk,
    bool? platformSupported,
    MetaPlatform? platform,
    TrackingAuthorization? tracking,
  })  : _sdk = sdk ?? FacebookAppEvents(),
        _platform = platform ??
            switch (platformSupported) {
              true => MetaPlatform.android,
              false => MetaPlatform.unsupported,
              null => _currentPlatform(),
            },
        _tracking = tracking ?? const TrackingAuthorization();

  static final MetaAppEventsService instance = MetaAppEventsService();

  static const String consentKey = 'meta_app_events_consent';
  static const String loggedOrdersKey = 'meta_app_events_logged_orders';
  static const bool diagnostics =
      bool.fromEnvironment('META_EVENTS_DEBUG') && !kReleaseMode;

  static const String currency = 'TRY';
  static const int _rememberedOrderLimit = 50;

  final FacebookAppEvents _sdk;
  final MetaPlatform _platform;
  final TrackingAuthorization _tracking;

  MetaTrackingConsent _consent = MetaTrackingConsent.unknown;
  Future<void>? _loading;
  bool _sdkReady = false;
  bool _activatedThisProcess = false;
  AppLifecycleListener? _lifecycle;
  final Set<String> _purchasesInFlight = {};

  static MetaPlatform _currentPlatform() {
    if (kIsWeb) return MetaPlatform.unsupported;
    if (Platform.isAndroid) return MetaPlatform.android;
    if (Platform.isIOS) return MetaPlatform.ios;
    return MetaPlatform.unsupported;
  }

  bool get isSupported => _platform != MetaPlatform.unsupported;

  bool get isIos => _platform == MetaPlatform.ios;

  MetaTrackingConsent get consent => _consent;

  bool get _canLog =>
      isSupported && _consent == MetaTrackingConsent.granted && _sdkReady;

  /// iOS izleme izni durumu (Android'de her zaman [TrackingStatus.authorized]).
  Future<TrackingStatus> trackingStatus() async {
    if (!isIos) return TrackingStatus.authorized;
    try {
      return await _tracking.status();
    } catch (_) {
      return TrackingStatus.denied;
    }
  }

  /// iPhone Ayarlar'da uygulamanın sayfasını açar (izleme izni için).
  Future<bool> openTrackingSettings() async {
    if (!isIos) return false;
    try {
      return await _tracking.openSettings();
    } catch (_) {
      return false;
    }
  }

  /// Kayıtlı kararı okur; izin daha önce verildiyse SDK'yı hazırlar.
  /// Birden çok kez çağrılabilir; uygulama açılışını bekletmez.
  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    if (!isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _consent = _parse(prefs.getString(consentKey));
      _diag('kayıtlı izin: ${_consent.name}');
      if (isIos) {
        await _loadIos(prefs);
        return;
      }
      if (_consent != MetaTrackingConsent.granted) return;

      await _sdk.initializeSdk();
      if (diagnostics) {
        await _sdk.setDebugLoggingEnabled(true);
        AppLogger.debug('Meta SDK App ID: ${await _sdk.getApplicationId()}');
      }
      // Ayarlar SDK'da zaten kalıcı; tekrar yazmak yalnızca tutarlılığı
      // korur. Takip zaten başladıysa ikinci kez başlamaz.
      await _sdk.setAdvertiserIdCollectionEnabled(true);
      await _sdk.setAutoLogAppEventsEnabled(true);
      _activatedThisProcess = true; // SDK açılışta kendisi bildirdi
      _sdkReady = true;
      await _flushDiagnostics();
    } catch (e) {
      AppLogger.debug('Meta App Events başlatılamadı: $e');
    }
  }

  Future<void> _loadIos(SharedPreferences prefs) async {
    final att = await _tracking.status();
    _diag('iOS izleme izni: ${att.name}');
    switch (att) {
      case TrackingStatus.authorized:
        // Uygulama içinden kapatıldıysa iOS izni olsa da ölçüm yok.
        if (_consent == MetaTrackingConsent.denied) return;
        if (_consent == MetaTrackingConsent.unknown) {
          // iOS penceresinde "İzin Ver" açık bir onaydır.
          await prefs.setString(consentKey, 'granted');
          _consent = MetaTrackingConsent.granted;
        }
        await _startIos();
      case TrackingStatus.denied:
      case TrackingStatus.restricted:
        // iPhone izlemeye izin vermiyor: ölçüm yok, pencere de gösterilmez.
        // Kayıtlı karar değiştirilmez; izin sonradan Ayarlar'dan açılırsa
        // bir sonraki açılışta ölçüm kendiliğinden başlar.
        _consent = MetaTrackingConsent.denied;
      case TrackingStatus.notDetermined:
        // iOS henüz sormadı (ör. yeniden kurulum): onay penceresi tekrar
        // gösterilsin.
        if (_consent == MetaTrackingConsent.granted) {
          _consent = MetaTrackingConsent.unknown;
        }
    }
  }

  /// iOS'ta SDK'yı başlatır. Yalnızca iki izin de varken çağrılır.
  Future<void> _startIos() async {
    await _sdk.initializeSdk();
    if (diagnostics) {
      await _sdk.setDebugLoggingEnabled(true);
      AppLogger.debug('Meta SDK App ID: ${await _sdk.getApplicationId()}');
    }
    // Otomatik kayıt kapalı kalır; açılış aşağıda elle, bir kez bildirilir.
    await _sdk.setAutoLogAppEventsEnabled(false);
    await _sdk.setAdvertiserIdCollectionEnabled(true);
    _sdkReady = true;
    if (!_activatedThisProcess) {
      await _sdk.activateApp();
      _activatedThisProcess = true;
    }
    _listenForReturnFromBackground();
    await _flushDiagnostics();
  }

  void _listenForReturnFromBackground() {
    if (_lifecycle != null) return;
    try {
      // onShow: arka plandan dönüş. Sistem pencereleri (ATT, bildirim)
      // kapanınca tetiklenmez; açılış fazladan sayılmaz.
      _lifecycle = AppLifecycleListener(onShow: () => unawaited(_onIosShow()));
    } catch (e) {
      AppLogger.debug('Meta yaşam döngüsü dinlenemedi: $e');
    }
  }

  Future<void> _onIosShow() async {
    if (!_canLog) return;
    try {
      final att = await _tracking.status();
      if (att != TrackingStatus.authorized) {
        // İzin iPhone Ayarlar'dan kapatıldı.
        _consent = MetaTrackingConsent.denied;
        _sdkReady = false;
        await _sdk.setAdvertiserIdCollectionEnabled(false);
        _diag('iOS izleme izni kapatıldı, ölçüm durdu');
        return;
      }
      await _sdk.activateApp();
      await _flushDiagnostics();
    } catch (e) {
      AppLogger.debug('Meta açılış bildirilemedi: $e');
    }
  }

  /// Kullanıcının kararını kaydeder ve SDK'ya uygular. Ölçüm açıldıysa
  /// `true` döner. iOS'ta izin verilince sistemin izleme penceresi (ATT)
  /// sorulur; iPhone izin vermezse `false` döner.
  Future<bool> setConsent(bool granted) async {
    if (!isSupported) return false;
    await init();
    try {
      if (isIos) return await _setConsentIos(granted);
      final prefs = await SharedPreferences.getInstance();
      if (granted) {
        await prefs.setString(consentKey, 'granted');
        final alreadyActive =
            _consent == MetaTrackingConsent.granted && _sdkReady;
        _consent = MetaTrackingConsent.granted;
        if (alreadyActive) return true;

        await _sdk.initializeSdk();
        if (diagnostics) {
          await _sdk.setDebugLoggingEnabled(true);
          AppLogger.debug('Meta SDK App ID: ${await _sdk.getApplicationId()}');
        }
        await _sdk.setAdvertiserIdCollectionEnabled(true);
        await _sdk.setAutoLogAppEventsEnabled(true);
        // Bu oturumda SDK açılışta ölçüm yapmadı (izin yoktu). Kurulum ve
        // etkinleştirme bu süreçte yalnızca bir kez bildirilir.
        if (!_activatedThisProcess) {
          await _sdk.activateApp();
          _activatedThisProcess = true;
        }
        _sdkReady = true;
        await _flushDiagnostics();
      } else {
        await prefs.setString(consentKey, 'denied');
        final wasGranted = _consent == MetaTrackingConsent.granted;
        _consent = MetaTrackingConsent.denied;
        _sdkReady = false;
        if (wasGranted) {
          await _sdk.setAutoLogAppEventsEnabled(false);
          await _sdk.setAdvertiserIdCollectionEnabled(false);
        }
      }
    } catch (e) {
      AppLogger.debug('Meta izin ayarı uygulanamadı: $e');
    }
    return _canLog;
  }

  Future<bool> _setConsentIos(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    if (!granted) {
      await prefs.setString(consentKey, 'denied');
      _consent = MetaTrackingConsent.denied;
      if (_sdkReady) {
        _sdkReady = false;
        await _sdk.setAdvertiserIdCollectionEnabled(false);
      }
      return false;
    }

    var att = await _tracking.status();
    if (att == TrackingStatus.notDetermined) att = await _tracking.request();
    _diag('iOS izleme izni: ${att.name}');
    if (att != TrackingStatus.authorized) {
      // iPhone izin vermedi: ölçüm yok. Karar kaydedilmez; izin Ayarlar'dan
      // açılırsa sonraki açılışta ölçüm kendiliğinden başlar.
      _consent = MetaTrackingConsent.denied;
      return false;
    }

    await prefs.setString(consentKey, 'granted');
    _consent = MetaTrackingConsent.granted;
    if (!_sdkReady) await _startIos();
    return _canLog;
  }

  /// Ürün sepete gerçekten eklendikten sonra çağrılır.
  Future<void> logAddToCart(Product product, {int quantity = 1}) async {
    if (!isSupported || quantity < 1 || product.id.isEmpty) return;
    await init();
    if (!_canLog) {
      _diag('AddToCart gönderilmedi (izin: ${_consent.name}, sdk: $_sdkReady)');
      return;
    }
    final price = product.actualPrice;
    try {
      await _sdk.logEvent(
        name: FacebookAppEvents.eventNameAddedToCart,
        valueToSum: _money(price * quantity),
        parameters: {
          FacebookAppEvents.paramNameContentId: product.id,
          FacebookAppEvents.paramNameContentType: 'product',
          FacebookAppEvents.paramNameContent: jsonEncode([
            {
              'id': product.id,
              'quantity': quantity,
              'item_price': _money(price)
            },
          ]),
          FacebookAppEvents.paramNameNumItems: quantity,
          FacebookAppEvents.paramNameCurrency: currency,
        },
      );
      await _flushDiagnostics();
    } catch (e) {
      AppLogger.debug('Meta AddToCart gönderilemedi: $e');
    }
  }

  /// Sunucu siparişi başarıyla kaydettikten sonra çağrılır. Aynı sipariş
  /// numarası için yalnızca bir kez gönderilir.
  Future<void> logPurchase({
    required String orderId,
    required List<CartItem> items,
    required double amount,
  }) async {
    if (!isSupported || orderId.isEmpty || items.isEmpty || amount <= 0) {
      return;
    }
    await init();
    if (!_canLog) {
      _diag('Purchase gönderilmedi (izin: ${_consent.name}, sdk: $_sdkReady)');
      return;
    }
    if (!_purchasesInFlight.add(orderId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final logged = prefs.getStringList(loggedOrdersKey) ?? <String>[];
      if (logged.contains(orderId)) return;

      final contents = [
        for (final item in items)
          {
            'id': item.product.id,
            'quantity': item.quantity,
            'item_price': _money(item.product.actualPrice),
          },
      ];
      await _sdk.logPurchase(
        amount: _money(amount),
        currency: currency,
        parameters: {
          FacebookAppEvents.paramNameOrderId: orderId,
          FacebookAppEvents.paramNameContentType: 'product',
          FacebookAppEvents.paramNameContentId:
              jsonEncode([for (final item in items) item.product.id]),
          FacebookAppEvents.paramNameContent: jsonEncode(contents),
          FacebookAppEvents.paramNameNumItems:
              items.fold<int>(0, (sum, item) => sum + item.quantity),
        },
      );

      await _flushDiagnostics();

      logged.add(orderId);
      final keep = logged.length > _rememberedOrderLimit
          ? logged.sublist(logged.length - _rememberedOrderLimit)
          : logged;
      await prefs.setStringList(loggedOrdersKey, keep);
    } catch (e) {
      AppLogger.debug('Meta Purchase gönderilemedi: $e');
    } finally {
      _purchasesInFlight.remove(orderId);
    }
  }

  // Flush only requests delivery; the native log confirms Meta's response.
  // Diagnostic failures must never affect purchase deduplication.
  Future<void> _flushDiagnostics() async {
    if (!diagnostics || !_canLog) return;
    try {
      await _sdk.flush();
    } catch (e) {
      AppLogger.debug('Meta debug flush başarısız: $e');
    }
  }

  static void _diag(String message) {
    if (diagnostics) AppLogger.debug('Meta: $message');
  }

  static MetaTrackingConsent _parse(String? value) {
    switch (value) {
      case 'granted':
        return MetaTrackingConsent.granted;
      case 'denied':
        return MetaTrackingConsent.denied;
      default:
        return MetaTrackingConsent.unknown;
    }
  }

  static double _money(double value) => (value * 100).roundToDouble() / 100;
}
