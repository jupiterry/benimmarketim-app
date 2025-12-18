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
import 'services/theme_service.dart';
import 'services/token_manager.dart';
import 'services/notification_service.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hata yakalama ile güvenli başlatma
  try {
    // Notification Service'i en başta başlat (await ile bekle ki izin istesin)
    debugPrint('🔄 NotificationService initializing...');
    await NotificationService.instance.init();
    debugPrint('✅ NotificationService initialized');

    // TokenManager initialization
    try {
      await TokenManager.init();
      debugPrint('✅ TokenManager initialized');
    } catch (e) {
      debugPrint('⚠️ TokenManager initialization failed: $e');
      // TokenManager olmadan da devam edebilir
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Critical initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // Kritik hata olsa bile uygulamayı başlat
  }

  // Notification Service başlat


  // Global error handler - Flutter hatalarını yakala
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      ],
      child: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
          // Auth durumunu kontrol et - güvenli şekilde
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              if (context.mounted) {
                authViewModel.checkAuthStatus();
              }
            } catch (e) {
              debugPrint('Auth check failed: $e');
            }
          });

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
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
