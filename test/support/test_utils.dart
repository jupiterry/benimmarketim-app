// Widget testleri için ortak yardımcılar: font hatalarını yutan bölge ve
// sayfaları uygulamanın teması, Türkçe yerel ayarı ve go_router ile çizen
// [pumpMarket].

import 'dart:async';

import 'package:benimmarketim_app/services/theme_service.dart';
import 'package:benimmarketim_app/views/widgets/market_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Testte fontlar internetten indirilmez; metinler varsayılan test fontuyla
/// çizilir. `main()` başında bir kez çağrılır.
void configureMarketTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Fontlar testte indirilemez (google_fonts ağdan çeker). [body], yalnızca
/// font yükleme hatalarını yutan bir bölgede çalışır; başka her hata (başarısız
/// `expect` dahil) testi yine başarısız yapar. Genellikle test gövdesinin
/// tamamı bununla sarılır.
Future<void> withoutFontErrors(Future<void> Function() body) {
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

/// [home]'u '/' yolunda, uygulamanın teması ve Türkçe yerel ayarıyla çizer.
/// [routes] ek go_router yollarıdır (ör. '/addresses/new'). [wrap] uygulamayı
/// sağlayıcılarla sarmak içindir:
///
/// ```dart
/// await pumpMarket(tester, const AddressesPage(),
///     wrap: (app) => ChangeNotifierProvider.value(value: vm, child: app));
/// ```
///
/// Dönen [GoRouter] ile test içinde gezinilebilir (`router.push(...)`).
Future<GoRouter> pumpMarket(
  WidgetTester tester,
  Widget home, {
  List<RouteBase> routes = const [],
  Widget Function(Widget app)? wrap,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      ...routes,
    ],
  );
  addTearDown(router.dispose);

  final Widget app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppThemes.lightTheme,
    routerConfig: router,
    scrollBehavior: const MarketScrollBehavior(),
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await tester.pump();
  return router;
}
