// Ödeme ve sepette adrese teslimat: ücret satırı, toplam, engeller, sipariş
// gövdesi ve anahtar kapalıyken bugünkü yurt akışı.

import 'package:benimmarketim_app/models/coupon.dart';
import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/models/order.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/auth_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/cart_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/referral_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/settings_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/home_page_viewmodel.dart';
import 'package:benimmarketim_app/views/cart_page.dart';
import 'package:benimmarketim_app/views/order_page.dart';
import 'package:benimmarketim_app/views/widgets/delivery_fee_summary.dart';
import 'package:benimmarketim_app/views/widgets/delivery_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_delivery_api.dart';
import 'support/orders_test_utils.dart'
    show FakeHttpAdapter, installOrdersPlatformMocks;
import 'support/test_utils.dart';

DeliveryQuote _quote({
  String zoneId = 'cumhuriyet',
  double subtotal = 100,
  double fee = 40,
  bool isFree = false,
  String? freeReason,
  double? remaining,
  double minimum = 0,
  bool meetsMinimum = true,
}) =>
    DeliveryQuote(
      zoneId: zoneId,
      subtotal: subtotal,
      deliveryFee: fee,
      isFree: isFree,
      freeReason: freeReason,
      remainingForFree: remaining,
      minimumOrderAmount: minimum,
      meetsMinimum: meetsMinimum,
      total: subtotal + (isFree ? 0 : fee),
    );

Product _product({String id = 'p1', double price = 100}) => Product(
      id: id,
      name: 'Ürün $id',
      description: '',
      price: price,
      originalPrice: price,
      actualPrice: price,
      image: '',
      category: '',
      categoryId: '',
      isDiscounted: false,
      isOutOfStock: false,
      isFeatured: false,
      isHidden: false,
      order: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Bölgeler ve adresler bellekte; teklif [quoteFor] ile üretilir.
class _QuoteApi extends FakeDeliveryApi {
  _QuoteApi({
    super.access,
    super.zones,
    super.addresses,
    this.quoteFor,
  });

  DeliveryQuote Function(String zoneId)? quoteFor;
  ApiException? quoteError;
  final List<String> quotedZones = [];

  @override
  Future<DeliveryQuote> getDeliveryQuote({
    required String zoneId,
    required List<Map<String, dynamic>> products,
  }) async {
    quotedZones.add(zoneId);
    if (quoteError != null) throw quoteError!;
    return quoteFor?.call(zoneId) ?? _quote(zoneId: zoneId);
  }
}

void _mockChannel(
    String channel, Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(channel), handler);
}

/// Ödeme ekranının dokunduğu eklentiler (bildirim, ölçüm, izinler).
void _installCheckoutMocks() {
  installOrdersPlatformMocks();
  _mockChannel('flutter.oddbit.id/facebook_app_events', (_) async => null);
  _mockChannel('dev.britannio.in_app_review', (_) async => false);
  _mockChannel('flutter.baseflow.com/permissions/methods', (call) async {
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
    _mockChannel(name, (_) async => null);
  }
}

/// Ödeme ekranını gerçek view model'lerle çizer; sepete [items] eklenir.
Future<({CartViewModel cart, DeliveryViewModel delivery})> _pumpCheckout(
  WidgetTester tester,
  _QuoteApi api, {
  List<(Product, int)> items = const [],
}) async {
  final delivery = createTestDeliveryViewModel(api);
  late CartViewModel cart;
  await pumpMarket(
    tester,
    const OrderPage(),
    // Uzun ekran: özet ve not alanı da çizilsin (liste tembel kurulur)
    size: const Size(390, 3200),
    wrap: (app) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) {
          cart = CartViewModel();
          return cart;
        }),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => ReferralViewModel()),
        ChangeNotifierProvider.value(value: delivery),
      ],
      child: app,
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 50))); // sepet veritabanı okuması
  for (final (product, quantity) in items) {
    cart.addQuantity(product, quantity);
  }
  await _settle(tester);
  return (cart: cart, delivery: delivery);
}

/// Mikro görevler, teklif zamanlayıcısı ve sahte API yanıtları tamamlanır.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Sepet ekranını çizer; sepete [items] eklenir.
Future<void> _pumpCart(
  WidgetTester tester,
  _QuoteApi api, {
  List<(Product, int)> items = const [],
}) async {
  final delivery = createTestDeliveryViewModel(api);
  late CartViewModel cart;
  await pumpMarket(
    tester,
    const CartPage(),
    size: const Size(390, 2400),
    wrap: (app) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) {
          cart = CartViewModel();
          return cart;
        }),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => ReferralViewModel()),
        ChangeNotifierProvider(create: (_) => HomePageViewModel()),
        ChangeNotifierProvider.value(value: delivery),
      ],
      child: app,
    ),
  );
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  for (final (product, quantity) in items) {
    cart.addQuantity(product, quantity);
  }
  await _settle(tester);
}

/// Ağaç kapatılır; sağlayıcılar zamanlayıcılarını durdurur.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 1));
}

FilledButton _orderButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
        of: find.text('Siparişi ver'), matching: find.byType(FilledButton)));

void main() {
  configureMarketTests();

  group('Teslimat ücreti gösterimi', () {
    test('kampanya: ücretsiz, etiket ve üstü çizili normal ücret', () {
      final display = DeliveryFeeDisplay.fromQuote(
          _quote(fee: 40, isFree: true, freeReason: 'campaign'));
      expect(display.kind, DeliveryFeeKind.campaign);
      expect(display.value, 'Ücretsiz teslimat');
      expect(display.struckFee, 40);
      expect(display.hint, isNull);
    });

    test('ücretsiz bölge ve eşik: yalnızca "Ücretsiz teslimat"', () {
      for (final reason in ['zone', 'threshold']) {
        final display = DeliveryFeeDisplay.fromQuote(
            _quote(fee: 40, isFree: true, freeReason: reason));
        expect(display.kind, DeliveryFeeKind.free);
        expect(display.value, 'Ücretsiz teslimat');
        expect(display.struckFee, isNull);
      }
    });

    test('ücretli: tutar ve eşik ipucu', () {
      final display =
          DeliveryFeeDisplay.fromQuote(_quote(fee: 40, remaining: 360));
      expect(display.kind, DeliveryFeeKind.paid);
      expect(display.label, 'Teslimat ücreti');
      expect(display.value, '₺40,00');
      expect(display.hint, '₺360 daha ekle, teslimat ücretsiz');
      expect(DeliveryFeeDisplay.fromQuote(_quote(fee: 40)).hint, isNull);
    });

    testWidgets('satır: kampanyada normal ücret üstü çizili', (tester) async {
      await withoutFontErrors(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: DeliveryFeeLine(
                quote: _quote(fee: 40, isFree: true, freeReason: 'campaign')),
          ),
        ));
        expect(find.text('Ücretsiz teslimat'), findsOneWidget);
        expect(find.text('Kampanya'), findsOneWidget);
        final struck = tester.widget<Text>(find.text('₺40,00'));
        expect(struck.style?.decoration, TextDecoration.lineThrough);
      });
    });

    testWidgets('satır: ücretli bölgede ipucu, ücretsizde ipucu yok',
        (tester) async {
      await withoutFontErrors(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(children: [
              DeliveryFeeLine(quote: _quote(fee: 40, remaining: 60)),
              DeliveryFeeLine(
                  quote: _quote(isFree: true, freeReason: 'threshold')),
            ]),
          ),
        ));
        expect(find.text('Teslimat ücreti'), findsOneWidget);
        expect(find.text('₺40,00'), findsOneWidget);
        expect(find.text(freeDeliveryHint(60)), findsOneWidget);
        expect(find.text('Ücretsiz teslimat'), findsOneWidget);
        expect(find.text('Kampanya'), findsNothing);
      });
    });

    test('adres yokken sepetteki tahmin', () {
      expect(DeliveryFeeEstimateLine.valueText(40), 'En düşük ₺40');
      expect(DeliveryFeeEstimateLine.valueText(0), 'Bölgeye göre');
      expect(DeliveryFeeEstimateLine.valueText(40, freeEverywhere: true),
          'Ücretsiz');
      expect(DeliveryFeeEstimateLine.valueText(null), 'Bölgeye göre');
    });
  });

  group('Ödenecek tutar', () {
    test('ürünler − kupon + teslimat; kupon ücreti düşürmez', () {
      expect(
        checkoutPayable(
            productsTotal: 300, couponDiscount: 50, quote: _quote(fee: 40)),
        290,
      );
      // Kupon ürün tutarından büyükse ürün kısmı 0'da kalır, ücret yine eklenir
      expect(
        checkoutPayable(
            productsTotal: 30, couponDiscount: 50, quote: _quote(fee: 40)),
        40,
      );
      expect(
        checkoutPayable(
            productsTotal: 300,
            couponDiscount: 50,
            quote: _quote(isFree: true, freeReason: 'campaign')),
        250,
      );
      expect(checkoutPayable(productsTotal: 300, couponDiscount: 50), 250);
    });
  });

  group('Siparişi engelleyen durumlar', () {
    test('minimumun altı', () {
      final quote = _quote(subtotal: 100, minimum: 250, meetsMinimum: false);
      final block = addressOrderBlock(
          hasSelection: true, selectionUsable: true, quote: quote);
      expect(block?.message,
          'Bu bölge için en az ₺250 tutarında sipariş gerekiyor (₺150 daha ekle).');
      expect(block?.message, minimumOrderMessage(quote));
    });

    test('adres yok, kapalı bölge, ZONE_CLOSED, hesaplanıyor', () {
      expect(
          addressOrderBlock(hasSelection: false, selectionUsable: false)
              ?.message,
          contains('teslimat adresi seç'));
      final closed =
          addressOrderBlock(hasSelection: true, selectionUsable: false);
      expect(closed?.pickAnother, isTrue);
      expect(closed?.message, startsWith(zoneClosedNote));

      final zoneClosed = addressOrderBlock(
        hasSelection: true,
        selectionUsable: true,
        quoteError: const ApiException('Bölge bugün kapalı.',
            statusCode: 400, code: 'ZONE_CLOSED'),
      );
      expect(zoneClosed?.pickAnother, isTrue);
      expect(zoneClosed?.message, startsWith('Bölge bugün kapalı.'));

      final pending = addressOrderBlock(
          hasSelection: true, selectionUsable: true, quoteLoading: true);
      expect(pending?.pending, isTrue);

      final failed = addressOrderBlock(
        hasSelection: true,
        selectionUsable: true,
        quoteError: const ApiException('Teslimat ücreti hesaplanamadı.'),
      );
      expect(failed?.retry, isTrue);

      expect(
          addressOrderBlock(
              hasSelection: true, selectionUsable: true, quote: _quote()),
          isNull);
    });
  });

  group('Sipariş gövdesi', () {
    CreateOrderRequest request({
      String deliveryPoint = '',
      String deliveryPointName = '',
      String? addressId,
      String? zoneId,
    }) =>
        CreateOrderRequest(
          products: const [
            {'product': 'p1', 'quantity': 2, 'price': 50.0},
          ],
          totalAmount: 100,
          city: 'Zonguldak',
          phone: '5321234567',
          deliveryPoint: deliveryPoint,
          deliveryPointName: deliveryPointName,
          note: 'Zil bozuk',
          paymentMethod: PaymentMethod.cash,
          couponCode: 'HOS10',
          discountAmount: 10,
          device: const {'platform': 'android'},
          addressId: addressId,
          zoneId: zoneId,
        );

    test('kayıtlı adres: addressId, yurt alanları yok', () {
      final json = request(addressId: 'a1', deliveryPointName: 'Ev').toJson();
      expect(json['addressId'], 'a1');
      expect(json['paymentMethod'], 'cash');
      expect(json['couponCode'], 'HOS10');
      expect(json['note'], 'Zil bozuk');
      expect(json['phone'], '5321234567');
      expect(json.containsKey('deliveryPoint'), isFalse);
      expect(json.containsKey('deliveryPointName'), isFalse);
      expect(json.containsKey('totalAmount'), isFalse);
      expect(json.containsKey('zoneId'), isFalse);
    });

    test('adres akışında yurt: bugünkü gövde + zoneId', () {
      final json = request(
        deliveryPoint: 'girlsDorm',
        deliveryPointName: 'Kız KYK Yurdu',
        zoneId: 'girlsDorm',
      ).toJson();
      expect(json['zoneId'], 'girlsDorm');
      expect(json['deliveryPoint'], 'girlsDorm');
      expect(json['deliveryPointName'], 'Kız KYK Yurdu');
      expect(json['city'], 'Zonguldak');
      expect(json.containsKey('addressId'), isFalse);
    });

    test('yurt akışı (anahtar kapalı): gövde bugünküyle aynı', () {
      final json = request(
        deliveryPoint: 'boysDorm',
        deliveryPointName: 'Erkek KYK Yurdu',
      ).toJson();
      expect(json.keys.toSet(), {
        'paymentMethod',
        'products',
        'totalAmount',
        'city',
        'phone',
        'deliveryPoint',
        'deliveryPointName',
        'note',
        'couponCode',
        'couponDiscount',
        'subtotalAmount',
        'device',
      });
    });
  });

  group('Kuponlar', () {
    test('bölgeye özel kupon: deliveryZones kuponda ya da couponPublicData içinde',
        () {
      final expiry =
          DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final direct = Coupon.fromJson({
        'code': 'MAH10',
        'expirationDate': expiry,
        'deliveryZones': ['cumhuriyet'],
      });
      expect(direct.isZoneRestricted, isTrue);
      expect(direct.deliveryZones, ['cumhuriyet']);

      final nested = Coupon.fromJson({
        'code': 'KOY',
        'expirationDate': expiry,
        'couponPublicData': {
          'deliveryZones': [
            {'id': 'bostanlar', 'name': 'Bostanlar Köyü'},
          ],
        },
      });
      expect(nested.deliveryZones, ['bostanlar']);

      final everywhere =
          Coupon.fromJson({'code': 'HER', 'expirationDate': expiry});
      expect(everywhere.isZoneRestricted, isFalse);
      expect(Coupon.zoneRestrictedLabel, 'Belirli bölgelerde geçerli');
    });

    test('cüzdan seçili bölgeyle istenir ve bölge değişince yenilenir',
        () async {
      final api = _CouponZoneApi();
      final referral = ReferralViewModel(apiService: api);
      await referral.loadCoupons();
      expect(api.zones, [null]);
      referral.setDeliveryZone('cumhuriyet');
      await Future<void>.delayed(Duration.zero);
      expect(api.zones, [null, 'cumhuriyet']);
      referral.setDeliveryZone('cumhuriyet'); // değişmedi: istek yok
      expect(api.zones, hasLength(2));
      referral.dispose();
    });
  });

  group('Ödeme ekranı', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({
        'GET /orders-analytics/user-orders': (_) => {'orders': []},
      }));
      _installCheckoutMocks();
    });

    testWidgets('anahtar kapalı: yurt seçimi, ücret satırı yok',
        (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(
          access: const DeliveryAccess(),
          addresses: [testAddress(isDefault: true)],
        );
        await _pumpCheckout(tester, api, items: [(_product(), 1)]);

        expect(find.text('Teslimat noktası'), findsOneWidget);
        expect(find.text('Teslimat adresi'), findsNothing);
        expect(find.text('Teslimat ücreti'), findsNothing);
        expect(find.text(addressNoteHint), findsNothing);
        expect(find.text('Ücretsiz'), findsOneWidget); // bugünkü satır
        expect(find.text('Girişte teslim'), findsWidgets); // yurt seçenekleri
        expect(api.quotedZones, isEmpty);
        expect(find.text('₺100,00'), findsWidgets);
        await _teardown(tester);
      });
    });

    testWidgets('anahtar açık: adres, ücret, eşik ipucu ve toplam',
        (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(
          addresses: [testAddress(isDefault: true)],
          quoteFor: (zone) => _quote(zoneId: zone, fee: 40, remaining: 150),
        );
        await _pumpCheckout(tester, api, items: [(_product(), 1)]);

        expect(find.text('Teslimat adresi'), findsOneWidget);
        expect(find.text('Teslimat noktası'), findsNothing);
        expect(find.text('Ev'), findsOneWidget);
        expect(find.text('Tahmini teslimat: 30-45 dk'), findsOneWidget);
        expect(find.text('Adres değiştir'), findsOneWidget);
        expect(api.quotedZones, contains('cumhuriyet'));
        expect(find.text('Teslimat ücreti'), findsOneWidget);
        expect(find.text('₺40,00'), findsOneWidget);
        expect(find.text(freeDeliveryHint(150)), findsOneWidget);
        // Ürünler ₺100 + teslimat ₺40 (özet ve alt çubuk)
        expect(find.text('₺140,00'), findsNWidgets(2));
        expect(find.text(addressNoteHint), findsOneWidget);
        expect(_orderButton(tester).onPressed, isNotNull);
        await _teardown(tester);
      });
    });

    testWidgets('minimumun altında sipariş düğmesi pasif ve nedeni yazılı',
        (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(
          addresses: [testAddress(isDefault: true, zone: testZoneKoy)],
          quoteFor: (zone) => _quote(
              zoneId: zone,
              fee: 60,
              subtotal: 100,
              minimum: 150,
              meetsMinimum: false),
        );
        await _pumpCheckout(tester, api, items: [(_product(), 1)]);

        expect(
            find.text(minimumOrderMessage(_quote(
                subtotal: 100, minimum: 150, meetsMinimum: false))),
            findsOneWidget);
        expect(_orderButton(tester).onPressed, isNull);
        await _teardown(tester);
      });
    });

    testWidgets('kapalı bölgedeki adres seçilemez; ilk siparişte teyit notu',
        (tester) async {
      await withoutFontErrors(() async {
        const callbackZone = DeliveryZone(
          id: 'yenimahalle',
          name: 'Yeni Mahalle',
          type: DeliveryZoneType.mahalle,
          deliveryFee: 30,
          etaText: '30-60 dk',
          requiresFirstOrderCallback: true,
        );
        final api = _QuoteApi(
          zones: [...testZones, callbackZone],
          addresses: [
            testAddress(isDefault: true, zoneEnabled: false),
            testAddress(id: 'a2', label: 'İş', zone: callbackZone),
          ],
        );
        final models =
            await _pumpCheckout(tester, api, items: [(_product(), 1)]);

        // Varsayılan adresin bölgesi kapalı: sipariş engellenir
        expect(find.textContaining(zoneClosedNote), findsWidgets);
        expect(_orderButton(tester).onPressed, isNull);
        expect(find.text(firstOrderCallbackNote), findsNothing);

        models.delivery.selectAddress('a2');
        await _settle(tester);
        expect(find.text(firstOrderCallbackNote), findsOneWidget);
        expect(_orderButton(tester).onPressed, isNotNull);
        await _teardown(tester);
      });
    });

    testWidgets('anahtar çalışırken kapanınca yurt akışına döner',
        (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(addresses: [testAddress(isDefault: true)]);
        final models =
            await _pumpCheckout(tester, api, items: [(_product(), 1)]);
        expect(find.text('Teslimat adresi'), findsOneWidget);

        api.access = const DeliveryAccess();
        await models.delivery.handleAddressOrderingDisabled();
        await _settle(tester);
        expect(find.text('Teslimat noktası'), findsOneWidget);
        expect(find.text('Teslimat ücreti'), findsNothing);
        expect(find.text('₺100,00'), findsWidgets);
        expect(tester.takeException(), isNull);
        await _teardown(tester);
      });
    });
  });

  group('Sepette minimum tutar', () {
    // Genel ayardaki minimum ₺250 (ayar alınamayınca kullanılan değer);
    // sepet ₺100.
    testWidgets('adres akışında bölgenin minimumu geçerli', (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(
          addresses: [testAddress(isDefault: true)],
          quoteFor: (zone) => _quote(zoneId: zone, minimum: 0),
        );
        await _pumpCart(tester, api, items: [(_product(), 1)]);
        expect(find.text('Siparişi tamamla'), findsOneWidget);
        expect(find.textContaining('daha ekle'), findsNothing);
        await _teardown(tester);
      });
    });

    testWidgets('yurt akışında genel minimum geçerli', (tester) async {
      await withoutFontErrors(() async {
        final api = _QuoteApi(access: DeliveryAccess.disabled);
        await _pumpCart(tester, api, items: [(_product(), 1)]);
        expect(find.text('Siparişi tamamla'), findsNothing);
        expect(find.text('₺150,00 daha ekle'), findsOneWidget);
        await _teardown(tester);
      });
    });
  });
}

class _CouponZoneApi extends ApiService {
  final List<String?> zones = [];

  @override
  Future<List<Coupon>> getUserCoupons({String? deliveryZone}) async {
    zones.add(deliveryZone);
    return const [];
  }
}
