import 'package:flutter/widgets.dart';
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
import '../views/referral_page.dart';
import '../views/chat_list_page.dart';
import '../views/chat_detail_page.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/order.dart' show PaymentMethod;
import '../views/onboarding_page.dart';
import '../views/cart_assistant_page.dart';
import '../views/saved_carts_page.dart';
import '../views/widgets/market_system_frame.dart';


class AppRouter {
  /// Kök Navigator'ın gözlemcileri. Durum çubuğu şeridi alt sayfa ve
  /// diyaloglarla birlikte kararır (MarketSystemFrame).
  static final List<NavigatorObserver> observers = [MarketChromeObserver.instance];

  static final router = GoRouter(
    initialLocation: '/',
    observers: observers,
    // Hata durumunda fallback route
    errorBuilder: (context, state) => const SplashScreen(),
    // TODO(deep-link): AndroidManifest'te https://devrekbenimmarketim.com
    // için /signup, /referral ve /ref yolları uygulamaya bağlandı (App Links).
    // Sunucuda /.well-known/assetlinks.json yayınlandıktan sonra burada
    // `/signup?ref=KOD`, `/referral` ve `/ref/KOD` gelen bağlantıları
    // RegisterPage'e (davet kodu dolu) yönlendiren bir `redirect` eklenmeli;
    // şimdilik bilinmeyen yollar errorBuilder ile açılışa düşer.
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
            navigationRequest: extra,
          );
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(
        path: '/cart-assistant',
        builder: (context, state) {
          final extra = state.extra;
          return CartAssistantPage(
            initialPrompt: extra is String ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/saved-carts',
        builder: (context, state) => const SavedCartsPage(),
      ),
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
          final query = state.uri.queryParameters;
          final point = query['point']?.trim();
          return OrderConfirmationPage(
            orderId: orderId,
            paymentMethod: PaymentMethod.fromKey(query['payment']),
            amount: double.tryParse(query['total'] ?? ''),
            deliveryPointName: point == null || point.isEmpty ? null : point,
          );
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
        builder: (context, state) {
          final extra = state.extra;
          return AdvancedSearchPage(initialQuery: extra is String ? extra : null);
        },
      ),
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
      GoRoute(
        path: '/referral',
        builder: (context, state) => const ReferralPage(),
      ),
      // Chat routes
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListPage(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatDetailPage(chatId: chatId);
        },
      ),
    ],
  );
}

