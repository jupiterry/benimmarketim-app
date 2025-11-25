import 'package:flutter/material.dart';
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
import 'services/version_check_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/firebase_performance_service.dart';
import 'router/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await TokenManager.init();

  // Initialize Firebase Analytics and Performance
  await FirebaseAnalyticsService().initialize();
  await FirebasePerformanceService().initialize();

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
          // Auth durumunu kontrol et
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            authViewModel.checkAuthStatus();

            // Versiyon kontrolü
            try {
              final versionService = VersionCheckService();
              final needsUpdate = await versionService.checkVersion();

              if (needsUpdate == true && context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false, // Kullanıcı kapatamaz
                  builder: (BuildContext context) {
                    // Geri tuşunu da engellemek için WillPopScope (veya PopScope)
                    return PopScope(
                      canPop: false,
                      child: AlertDialog(
                        title: const Text('Güncelleme Gerekli'),
                        content: const Text(
                          'Uygulamanın yeni bir sürümü mevcut. Devam etmek için lütfen güncelleyin.',
                        ),
                        actions: <Widget>[
                          FilledButton(
                            child: const Text('Güncelle'),
                            onPressed: () async {
                              final url = versionService.getStoreUrl();
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            } catch (e) {
              debugPrint('Version check failed in main: $e');
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
