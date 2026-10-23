import 'dart:async';

import 'package:benimmarketim_app/main.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/views/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart'
    show databaseFactory, databaseFactorySqflitePlugin;

/// Ağ yerine hemen "sunucuya ulaşılamadı" döner; test gerçek API'ye gitmez.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString('{}', 503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void _mock(String channel, Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(channel), handler);
}

/// Uygulamanın açılışta dokunduğu eklentiler: hepsi boş/olumsuz yanıt verir.
void _installPlatformMocks() {
  _mock('plugins.flutter.io/path_provider', (_) async => '/tmp');
  _mock('plugins.it_nomads.com/flutter_secure_storage', (_) async => null);
  _mock('flutter.oddbit.id/facebook_app_events', (_) async => null);
  _mock('dev.britannio.in_app_review', (_) async => false);
  _mock('dev.fluttercommunity.plus/package_info', (_) async => {
        'appName': 'Benim Marketim',
        'packageName': 'com.jupi.benimapp.benimmarketim_app',
        'version': '7.0.0',
        'buildNumber': '50',
      });
  _mock('flutter.baseflow.com/permissions/methods', (call) async {
    if (call.method == 'checkPermissionStatus') return 0;
    if (call.method == 'requestPermissions') {
      return {for (final p in (call.arguments as List).cast<int>()) p: 0};
    }
    return null;
  });
  for (final name in const [
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#user',
    'OneSignal#notifications',
    'OneSignal#pushsubscription',
    'OneSignal#inappmessages',
    'OneSignal#location',
    'OneSignal#session',
  ]) {
    _mock(name, (_) async => null);
  }
  // Boş sepet ve favoriler: her sorgu boş liste döner.
  _mock('com.tekartik.sqflite', (call) async {
    switch (call.method) {
      case 'getDatabasesPath':
        return '/tmp';
      case 'openDatabase':
        return 1;
      case 'query':
        return <String, Object?>{'columns': <String>[], 'rows': <List>[]};
      case 'insert':
      case 'update':
        return 0;
      default:
        return null;
    }
  });
}

/// Fontlar testte indirilemez (google_fonts ağdan çeker); bu yüzden metinler
/// varsayılan test fontuyla çizilir. Çizim, yalnızca font yükleme hatalarını
/// yutan bir bölgede çalışır; başka her hata testi yine başarısız yapar.
Future<void> _withoutFontErrors(Future<void> Function() body) {
  final done = Completer<void>();
  runZonedGuarded(() async {
    await body();
    if (!done.isCompleted) done.complete();
  }, (error, stack) {
    if (error.toString().contains('GoogleFonts') ||
        error.toString().contains('google_fonts')) {
      return;
    }
    if (!done.isCompleted) done.completeError(error, stack);
  });
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Testte fontlar internetten indirilmez; metinler varsayılan fontla çizilir.
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactorySqflitePlugin;
    ApiService.debugUseHttpAdapter(_OfflineAdapter());
    _installPlatformMocks();
  });

  testWidgets(
      'Application starts with Turkish storefront and release banner hidden',
      (tester) async {
    await _withoutFontErrors(() => tester.pumpWidget(const MyApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Benim Marketim');
    expect(app.locale, const Locale('tr', 'TR'));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ağaç kapatılınca sağlayıcılar zamanlayıcılarını durdurur; kalan tek
    // seferlik zamanlayıcılar (ör. açılış animasyonu) da burada tamamlanır.
    await _withoutFontErrors(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
