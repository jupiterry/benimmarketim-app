import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'viewmodels/home_page_viewmodel.dart';
import 'viewmodels/category_products_viewmodel.dart';
import 'viewmodels/cart_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/category_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/favorites_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/flash_sale_viewmodel.dart';
import 'viewmodels/banner_viewmodel.dart';
import 'viewmodels/referral_viewmodel.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/delivery_viewmodel.dart';
import 'services/theme_service.dart';
import 'services/token_manager.dart';
import 'services/notification_service.dart';
import 'services/review_service.dart';
import 'services/meta_app_events_service.dart';
import 'router/app_router.dart';
import 'views/widgets/market_scroll.dart';
import 'views/widgets/market_system_frame.dart';
import 'views/widgets/market_ui.dart' show MarketPalette, MarketText;
import 'services/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ekranlar telefonda dikey kullanım için tasarlandı (ızgaralar, alt
  // çubuklar); yan çevrilince düzen bozulmasın.
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (e) {
    AppLogger.debug('⚠️ Ekran yönü sabitlenemedi: $e');
  }

  // Hata yakalama ile güvenli başlatma
  try {
    // OneSignal'ı başlat (izin burada istenmez; onboarding sonunda ya da ilk
    // sipariş ekranında NotificationService.requestPermissionIfNeeded sorar)
    AppLogger.debug('🔄 NotificationService initializing...');
    await NotificationService.instance.init();
    AppLogger.debug('✅ NotificationService initialized');

    // TokenManager initialization
    try {
      await TokenManager.init();
      AppLogger.debug('✅ TokenManager initialized');
    } catch (e) {
      AppLogger.debug('⚠️ TokenManager initialization failed: $e');
      // TokenManager olmadan da devam edebilir
    }
  } catch (e, stackTrace) {
    AppLogger.debug('❌ Critical initialization error: $e');
    AppLogger.debug('Stack trace: $stackTrace');
    // Kritik hata olsa bile uygulamayı başlat
  }

  // Meta uygulama olayları: kayıtlı izni okur, izin varsa SDK'yı hazırlar.
  // İzin yoksa Meta'ya olay gönderilmez. Açılışı bekletmez.
  unawaited(MetaAppEventsService.instance.init());

  // Notification Service başlat

  // Global error handler - Flutter hatalarını yakala
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.debug('❌ Flutter Error: ${details.exception}');
    AppLogger.debug('Stack: ${details.stack}');
    // Production'da crash reporting servisine gönder
    if (kReleaseMode) {
      // Crash reporting servisine gönder
    }
  };

  // Bir parçanın çizimi hata verirse: geliştirirken Flutter'ın ayrıntılı hata
  // kutusu, yayında ise yalnızca o bölümün yerine sade bir not gösterilir
  // (teknik metin yok, uygulama yeniden başlatılmaz).
  final debugErrorBuilder = ErrorWidget.builder;
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      kReleaseMode ? const _MarketErrorFallback() : debugErrorBuilder(details);

  // Bildirime dokununca ilgili ekranı aç
  NotificationService.instance.currentLocation = _currentRoutePath;
  NotificationService.instance.onOpenRoute = _openNotificationRoute;

  runApp(const MyApp());
}

String _currentRoutePath() {
  try {
    final configuration = AppRouter.router.routerDelegate.currentConfiguration;
    if (configuration.matches.isEmpty) return '/';
    return configuration.last.matchedLocation;
  } catch (_) {
    return '/';
  }
}

// Uygulama bildirimle açıldıysa açılış ekranı bitene kadar bekler; kullanıcı
// giriş yapmamışsa yönlendirme yapılmaz.
Future<void> _openNotificationRoute(String route) async {
  if (route == '/home') return;
  // "Mağazada puan ver" bildirimi: uygulamanın mağaza sayfasını aç
  if (route == '/rate-app') {
    await ReviewService.instance.openStoreListing();
    return;
  }
  const waitingScreens = {'/', '/onboarding', '/login', '/register'};
  for (var attempt = 0; attempt < 60; attempt++) {
    final path = _currentRoutePath();
    if (!waitingScreens.contains(path)) {
      if (path != route) {
        try {
          AppRouter.router.push(route);
        } catch (e) {
          AppLogger.debug('Bildirim yönlendirme hatası: $e');
        }
      }
      return;
    }
    await Future.delayed(const Duration(milliseconds: 250));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _authChecked = false;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomePageViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryProductsViewModel()),
        ChangeNotifierProvider(create: (_) => CartViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
        ChangeNotifierProvider(create: (_) => SearchViewModel()),
        ChangeNotifierProvider(create: (_) => FlashSaleViewModel()),
        ChangeNotifierProvider(create: (_) => BannerViewModel()),
        ChangeNotifierProvider(create: (_) => ReferralViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        // Adrese teslimat: oturum açılınca/kapanınca erişim ve adresler yenilenir
        ChangeNotifierProxyProvider<AuthViewModel, DeliveryViewModel>(
          create: (_) => DeliveryViewModel(),
          update: (_, auth, delivery) =>
              delivery!..onAuthChanged(auth.isLoggedIn),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Auth durumunu sadece bir kez kontrol et
          if (!_authChecked) {
            _authChecked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                if (context.mounted) {
                  context.read<AuthViewModel>().checkAuthStatus();
                  // Flash sale'ler: rozet/geri sayım ve kampanya başlayıp
                  // bitince sepetteki fiyatın güncellenmesi.
                  final flashSales = context.read<FlashSaleViewModel>();
                  flashSales.addProductRefreshListener(
                    context.read<CartViewModel>().applyFreshProducts,
                  );
                  flashSales.start();
                  // Uzun süre arka planda kalınca ana sayfa rafları tazelenir
                  context.read<HomePageViewModel>().startAutoRefresh();
                }
              } catch (e) {
                AppLogger.debug('Auth check failed: $e');
              }
            });
          }

          return MaterialApp.router(
            title: 'Benim Marketim',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            routerConfig: AppRouter.router,
            // Sayfa üstten aşağı çekilince başlığın üstünde boşluk açılmasın
            scrollBehavior: const MarketScrollBehavior(),
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              // Sistem yazı boyutu en fazla 1.3 kat büyütülür; daha büyüğünde
              // iki sütunlu ızgaralar ve alt çubuklar sığmaz.
              return MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: MarketSystemFrame(child: child!),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Yayın sürümünde çizimi hata veren bölümün yerine gösterilir. Hata bir ürün
/// kartı gibi küçük bir alanda da olabilir; bu yüzden tek satırlık, her
/// boyuta sığan sade bir nottur.
class _MarketErrorFallback extends StatelessWidget {
  const _MarketErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 20, color: MarketPalette.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Bu bölüm şu an gösterilemiyor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
