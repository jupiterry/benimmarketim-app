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
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TokenManager.init();

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authViewModel.checkAuthStatus();
          });

          return GestureDetector(
            onTap: () {
              // Herhangi bir yere tıklandığında klavyeyi ve snackbar'ı kapat
              FocusManager.instance.primaryFocus?.unfocus();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: MaterialApp.router(
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
            ),
          );
        },
      ),
    );
  }
}
