import 'package:go_router/go_router.dart';
import '../views/splash_screen.dart';
import '../views/login_page.dart';
import '../views/register_page.dart';
import '../views/home_page.dart';
import '../views/cart_page.dart';
import '../views/profile_page.dart';
import '../views/product_detail_page.dart';
import '../views/category_products_page.dart';
import '../views/order_confirmation_page.dart';
import '../views/orders_page.dart';
import '../views/order_page.dart';
import '../views/settings_page.dart';
import '../views/favorites_page.dart';
import '../views/advanced_search_page.dart';
import '../views/feedback_page.dart';
import '../views/photocopy_upload_page.dart';
import '../views/photocopy_history_page.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../views/onboarding_page.dart';
import '../services/firebase_analytics_service.dart';

class AppRouter {
  static final _analyticsService = FirebaseAnalyticsService();

  static final router = GoRouter(
    initialLocation: '/',
    observers: [
      // Analytics observer null kontrolü ile güvenli ekleme
      if (_analyticsService.observer != null) _analyticsService.observer!,
    ],
    // Hata durumunda fallback route
    errorBuilder: (context, state) => const SplashScreen(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final initialTabIndex = extra?['initialTabIndex'] as int? ?? 0;
          final openOrders = extra?['openOrders'] as bool? ?? false;
          return HomePage(
            initialTabIndex: initialTabIndex,
            openOrders: openOrders,
          );
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/product',
        builder: (context, state) {
          final product = state.extra as Product;
          return ProductDetailPage(product: product);
        },
      ),
      GoRoute(
        path: '/category',
        builder: (context, state) {
          final category = state.extra as Category;
          return CategoryProductsPage(category: category);
        },
      ),
      GoRoute(
        path: '/category-products',
        builder: (context, state) {
          final category = state.extra as Category;
          return CategoryProductsPage(category: category);
        },
      ),
      GoRoute(
        path: '/product-detail',
        builder: (context, state) {
          final product = state.extra as Product;
          return ProductDetailPage(product: product);
        },
      ),
      GoRoute(
        path: '/order-confirmation/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'];
          return OrderConfirmationPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/order-confirmation',
        builder: (context, state) {
          return const OrderConfirmationPage();
        },
      ),
      GoRoute(path: '/orders', builder: (context, state) => const OrdersPage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
          path: '/search',
          builder: (context, state) => const AdvancedSearchPage()),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackPage(),
      ),
      GoRoute(
        path: '/photocopy-upload',
        builder: (context, state) => const PhotocopyUploadPage(),
      ),
      GoRoute(
        path: '/photocopy-history',
        builder: (context, state) => const PhotocopyHistoryPage(),
      ),
      GoRoute(
        path: '/create-order',
        builder: (context, state) => const OrderPage(),
      ),
    ],
  );
}
