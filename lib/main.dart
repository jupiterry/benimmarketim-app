import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'services/theme_service.dart';
import 'services/token_manager.dart';
import 'services/notification_service.dart';
import 'router/app_router.dart';
import 'views/widgets/market_system_frame.dart';
import 'services/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hata yakalama ile güvenli başlatma
  try {
    // Notification Service'i en başta başlat (await ile bekle ki izin istesin)
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

  // Error widget builder - hata durumunda gösterilecek ekran
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Uygulamayı yeniden başlat
                    runApp(const MyApp());
                  },
                  child: const Text('Yeniden Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

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
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child: MarketSystemFrame(child: child!),
              );
            },
          );
        },
      ),
    );
  }
}
