// Sepetin sunucudan yeniden fiyatlanması, fiyat değişince gösterilen bilgi,
// ürün kartı ve ürün detayındaki flash sale rozeti (ürünün flashSale
// özetinden).

import 'package:benimmarketim_app/models/cart_item.dart';
import 'package:benimmarketim_app/models/flash_sale.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/services/database_service.dart';
import 'package:benimmarketim_app/viewmodels/auth_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/cart_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/category_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/favorites_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/flash_sale_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/home_page_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/settings_viewmodel.dart';
import 'package:benimmarketim_app/views/product_detail_page.dart';
import 'package:benimmarketim_app/views/widgets/cart_price_notice.dart';
import 'package:benimmarketim_app/views/widgets/flash_sale_widgets.dart';
import 'package:benimmarketim_app/views/widgets/market_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_delivery_api.dart';
import 'support/orders_test_utils.dart'
    show FakeHttpAdapter, installOrdersPlatformMocks;
import 'support/test_utils.dart';

String _iso(DateTime value) => value.toUtc().toIso8601String();

Map<String, dynamic> _json(
  String id, {
  double actualPrice = 100,
  DateTime? updatedAt,
  DateTime? flashEnd,
}) {
  final now = DateTime.now();
  return {
    '_id': id,
    'name': 'Ürün $id',
    'price': 100,
    'actualPrice': actualPrice,
    'isDiscounted': actualPrice < 100,
    'discountedPrice': actualPrice < 100 ? actualPrice : null,
    'category': 'atistirma',
    'createdAt': '2026-09-01T10:00:00Z',
    'updatedAt': _iso(updatedAt ?? DateTime.utc(2026, 10, 1)),
    if (flashEnd != null)
      'flashSale': {
        '_id': 's1',
        'discountPercentage': 25,
        'price': actualPrice,
        'startDate': _iso(now.subtract(const Duration(hours: 1))),
        'endDate': _iso(flashEnd),
      },
  };
}

Product _product(
  String id, {
  double actualPrice = 100,
  DateTime? updatedAt,
  DateTime? flashEnd,
}) =>
    Product.fromJson(_json(id,
        actualPrice: actualPrice, updatedAt: updatedAt, flashEnd: flashEnd));

/// Sepet tablosu bellekte (sqflite yok).
class MemoryCartDb implements DatabaseService {
  MemoryCartDb([List<CartItem> items = const []]) : stored = List.of(items);

  final List<CartItem> stored;

  @override
  Future<List<CartItem>> getCartItems() async => List.of(stored);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class CartPriceApi extends ApiService {
  Map<String, Product>? serverCart;
  final Map<String, Product> products = {};
  final Set<String> removed = {};
  final List<String> productRequests = [];
  int cartRequests = 0;

  @override
  Future<Map<String, Product>?> getCartProducts() async {
    cartRequests++;
    return serverCart;
  }

  @override
  Future<Product> getProductById(String id) async {
    productRequests.add(id);
    if (removed.contains(id)) {
      throw const ApiException('Ürün bulunamadı.', statusCode: 404);
    }
    return products[id]!;
  }

  @override
  Future<Map<String, dynamic>> recommendCoupons(
    double orderAmount, {
    List<Map<String, dynamic>> products = const [],
    String? deliveryPoint,
    String? deliveryZone,
    String? channel,
  }) async =>
      {};

  @override
  Future<bool> syncCart(List<Map<String, dynamic>> items) async => true;
}

void _mockChannel(String name) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
}

/// Sepetin dokunduğu eklentiler (OneSignal etiketleri, Meta).
void _installCartMocks() {
  installOrdersPlatformMocks();
  for (final name in const [
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#user',
    'OneSignal#notifications',
    'OneSignal#pushsubscription',
    'OneSignal#inappmessages',
    'OneSignal#location',
    'OneSignal#session',
    'flutter.oddbit.id/facebook_app_events',
  ]) {
    _mockChannel(name);
  }
}

CartViewModel _cart(
  CartPriceApi api, {
  List<CartItem> stored = const [],
  bool loggedIn = false,
}) =>
    CartViewModel(
      apiService: api,
      databaseService: MemoryCartDb(stored),
      hasToken: () async => loggedIn,
    );

void main() {
  configureMarketTests();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _installCartMocks();
  });

  group('Sepet yeniden fiyatlama', () {
    test(
        'açılışta kayıtlı flash fiyatı sunucudaki fiyatla değişir ve bilgi '
        'yayınlanır', () async {
      final api = CartPriceApi()..products['p1'] = _product('p1');
      final cart = _cart(api, stored: [
        CartItem(product: _product('p1', actualPrice: 75), quantity: 2),
      ]);
      var notices = 0;
      cart.priceUpdates.listen((_) => notices++);

      await pumpEventQueue();

      expect(cart.items.single.product.actualPrice, 100);
      expect(cart.items.single.quantity, 2);
      expect(cart.totalPrice, 200);
      expect(notices, 1);
      cart.dispose();
    });

    test('misafir: kalem başına /products/:id; fiyat aynıysa bilgi yok',
        () async {
      final api = CartPriceApi()
        ..products['p1'] = _product('p1')
        ..products['p2'] = _product('p2', actualPrice: 80);
      final cart = _cart(api);
      await pumpEventQueue();
      cart.addQuantity(_product('p1'), 1);
      cart.addQuantity(_product('p2', actualPrice: 80), 3);
      var notices = 0;
      cart.priceUpdates.listen((_) => notices++);

      expect(await cart.refreshPrices(), isFalse);
      await pumpEventQueue();

      expect(api.cartRequests, 0);
      expect(api.productRequests, unorderedEquals(['p1', 'p2']));
      expect(notices, 0);
      cart.dispose();
    });

    test(
        'giriş yapılmışsa sunucu sepetinin fiyatları kullanılır; orada '
        'olmayan kalem tek tek alınır', () async {
      final api = CartPriceApi()
        ..serverCart = {'p1': _product('p1', actualPrice: 100)}
        ..products['p2'] = _product('p2', actualPrice: 60);
      final cart = _cart(api, loggedIn: true);
      await pumpEventQueue();
      cart.addQuantity(_product('p1', actualPrice: 75), 1);
      cart.addQuantity(_product('p2', actualPrice: 60), 1);

      expect(await cart.refreshPrices(), isTrue);

      expect(api.cartRequests, 1);
      expect(api.productRequests, ['p2']);
      expect(cart.items.firstWhere((i) => i.product.id == 'p1').product
          .actualPrice, 100);
      cart.dispose();
    });

    test('sunucu sepeti alınamazsa kalem başına fiyatlanır', () async {
      final api = CartPriceApi()
        ..serverCart = null
        ..products['p1'] = _product('p1');
      final cart = _cart(api, loggedIn: true);
      await pumpEventQueue();
      cart.addQuantity(_product('p1', actualPrice: 75), 1);

      expect(await cart.refreshPrices(), isTrue);
      expect(api.productRequests, ['p1']);
      cart.dispose();
    });

    test('kaldırılmış (404) ürün sepetten düşer', () async {
      final api = CartPriceApi()..removed.add('p1');
      final cart = _cart(api);
      await pumpEventQueue();
      cart.addQuantity(_product('p1'), 1);

      await cart.refreshPrices();

      expect(cart.isEmpty, isTrue);
      cart.dispose();
    });

    test('ön plana gelişte yeniden fiyatlanır (kısa kesintide değil)',
        () async {
      final api = CartPriceApi()..products['p1'] = _product('p1');
      final cart = _cart(api);
      await pumpEventQueue();
      cart.addQuantity(_product('p1'), 1);
      api.productRequests.clear();

      // Bildirim perdesi: inactive → resumed
      cart.didChangeAppLifecycleState(AppLifecycleState.inactive);
      cart.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(api.productRequests, isEmpty);

      cart.didChangeAppLifecycleState(AppLifecycleState.hidden);
      cart.didChangeAppLifecycleState(AppLifecycleState.paused);
      cart.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(api.productRequests, ['p1']);
      cart.dispose();
    });
  });

  testWidgets('fiyat değişince kısa bilgi çubuğu görünür', (tester) async {
    await withoutFontErrors(() async {
      final api = CartPriceApi()..products['p1'] = _product('p1');
      late CartViewModel cart;
      await pumpMarket(
        tester,
        const CartPriceNotice(child: Scaffold(body: SizedBox.expand())),
        wrap: (app) => ChangeNotifierProvider<CartViewModel>(
          create: (_) => cart = _cart(api),
          child: app,
        ),
      );
      await tester.pump();
      cart.addQuantity(_product('p1', actualPrice: 75), 1);

      await cart.refreshPrices();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Sepetindeki bazı ürünlerin fiyatı güncellendi.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Ürün kartı', () {
    Future<void> pumpCard(WidgetTester tester, Product product) async {
      await pumpMarket(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              height: 300,
              child: MarketProductCard(product: product),
            ),
          ),
        ),
        wrap: (app) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => FlashSaleViewModel(apiService: CartPriceApi()),
            ),
            ChangeNotifierProvider(create: (_) => _cart(CartPriceApi())),
            ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
          ],
          child: app,
        ),
      );
      await tester.pump();
    }

    testWidgets(
        'rozet ve geri sayım ürünün flashSale özetinden gelir (aktif liste boş)',
        (tester) async {
      await withoutFontErrors(() async {
        await pumpCard(
          tester,
          _product('p1',
              actualPrice: 75,
              flashEnd: DateTime.now().add(const Duration(hours: 2))),
        );

        expect(find.byType(FlashBadge), findsOneWidget);
        expect(find.text('%25'), findsOneWidget);
        expect(find.byType(FlashTimerChip), findsOneWidget);
      });
    });

    testWidgets('süresi dolmuş özette flash rozeti yok, indirim rozeti kalır',
        (tester) async {
      await withoutFontErrors(() async {
        await pumpCard(
          tester,
          _product('p1',
              actualPrice: 75,
              flashEnd: DateTime.now().subtract(const Duration(minutes: 1))),
        );

        expect(find.byType(FlashBadge), findsNothing);
        expect(find.byType(FlashTimerChip), findsNothing);
        expect(find.byType(MarketDiscountBadge), findsOneWidget);
      });
    });
  });

  testWidgets(
      'ürün detayı açılınca ürün yeniden alınır: disk önbelleğindeki eski '
      'fiyat yerine flash fiyatı ve rozeti görünür, sepet de güncellenir',
      (tester) async {
    await withoutFontErrors(() async {
      final fresh = _json(
        'p1',
        actualPrice: 75,
        updatedAt: DateTime.now(),
        flashEnd: DateTime.now().add(const Duration(hours: 3)),
      );
      final requested = <String>[];
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({
        'GET /products/p1': (options) {
          requested.add(options.path);
          return fresh;
        },
        'GET /products/p1/similar': (_) => <Object>[],
      }));
      final stale = _product('p1'); // 3 gün önceki liste: 100 TL, rozet yok
      final flash = FlashSaleViewModel(apiService: CartPriceApi());
      late CartViewModel cart;

      await pumpMarket(
        tester,
        ProductDetailPage(product: stale),
        size: const Size(390, 1400),
        wrap: (app) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (_) {
              cart = _cart(CartPriceApi());
              cart.addQuantity(stale, 1);
              return cart;
            }),
            ChangeNotifierProvider(create: (_) => CategoryViewModel()),
            ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
            ChangeNotifierProvider.value(value: flash),
            ChangeNotifierProvider(create: (_) => HomePageViewModel()),
            ChangeNotifierProvider(create: (_) => SettingsViewModel()),
            ChangeNotifierProvider(
              create: (_) => createTestDeliveryViewModel(FakeDeliveryApi()),
            ),
          ],
          child: app,
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(requested, isNotEmpty);
      expect(find.byType(FlashSaleBanner), findsOneWidget);
      expect(find.text('%25'), findsWidgets);
      expect(cart.items.single.product.actualPrice, 75);
      // Listelerdeki kartlar da güncel ürünü görür
      expect(flash.latest(stale).actualPrice, 75);
      expect(flash.saleOf(stale), isA<FlashSale>());

      await tester.pumpWidget(const SizedBox());
      flash.dispose();
    });
  });
}
