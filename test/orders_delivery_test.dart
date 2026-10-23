import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/models/order.dart';
import 'package:benimmarketim_app/models/user.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/auth_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/chat_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/favorites_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/settings_viewmodel.dart';
import 'package:benimmarketim_app/views/order_confirmation_page.dart';
import 'package:benimmarketim_app/views/orders_page.dart';
import 'package:benimmarketim_app/views/profile_page.dart';
import 'package:benimmarketim_app/views/widgets/delivery_zones_info.dart';
import 'package:benimmarketim_app/views/widgets/order_delivery_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/orders_test_utils.dart';
import 'support/test_utils.dart';

// ---------------------------------------------------------------------------
// Örnek siparişler (GET /orders-analytics/user-orders biçiminde)
// ---------------------------------------------------------------------------

final _created = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

Map<String, dynamic> _addressOrderJson({
  String id = 'addr00000001',
  String status = 'Hazırlanıyor',
  double fee = 40,
  bool needsCallback = true,
  String? callbackConfirmedAt,
  String outcome = '',
}) =>
    {
      '_id': id,
      'userId': 'u1',
      'products': [
        {'productId': 'p1', 'name': 'Süt 1 L', 'quantity': 2, 'price': 50},
      ],
      'totalAmount': 100 - 10 + fee,
      'subtotalAmount': 100,
      'couponCode': 'HOSGELDIN',
      'couponDiscount': 10,
      'productTotal': 90,
      'status': status,
      'note': '',
      'city': 'Zonguldak',
      'deliveryPoint': '',
      'deliveryPointName': 'Cumhuriyet Mah. · Atatürk Cd. No:5',
      'phone': '05551112233',
      'createdAt': _created,
      'paymentMethod': 'cash',
      'deliveryType': 'address',
      'deliveryZone': {'id': 'cumhuriyet', 'name': 'Cumhuriyet Mahallesi', 'type': 'mahalle'},
      'deliveryAddress': {
        'street': 'Atatürk Cd.',
        'buildingNo': '5',
        'buildingName': 'Gül Apt.',
        'floor': '2',
        'apartment': '4',
        'directions': 'Eczanenin üstü, mavi kapı',
      },
      'deliveryFee': fee,
      'needsCallback': needsCallback,
      'callbackConfirmedAt': callbackConfirmedAt,
      'deliveryOutcomeLabel': outcome,
      'cancelReasonLabel': '',
      'cancelReasonNote': '',
    };

Map<String, dynamic> _dormOrderJson({String status = 'Teslim Edildi'}) => {
      '_id': 'dorm00000001',
      'userId': 'u1',
      'products': [
        {'productId': 'p2', 'name': 'Ekmek', 'quantity': 1, 'price': 15},
      ],
      'totalAmount': 15,
      'status': status,
      'note': '',
      'city': 'Zonguldak',
      'deliveryPoint': 'girlsDorm',
      'deliveryPointName': 'Kız KYK Yurdu',
      'phone': '05551112233',
      'createdAt': _created,
    };

const _zones = [
  DeliveryZone(
    id: 'girlsDorm',
    name: 'Kız KYK Yurdu',
    type: DeliveryZoneType.yurt,
    isFree: true,
    etaText: '15-30 dk',
  ),
  DeliveryZone(
    id: 'cumhuriyet',
    name: 'Cumhuriyet Mahallesi',
    type: DeliveryZoneType.mahalle,
    deliveryFee: 40,
    etaText: '30-45 dk',
  ),
];

/// Giriş yapmış sahte kullanıcı
class _LoggedInAuth extends AuthViewModel {
  @override
  bool get isLoggedIn => true;

  @override
  User? get user => User(
        id: 'u1',
        name: 'Ayşe Yılmaz',
        email: 'ayse@example.com',
        phone: '05551112233',
        role: 'customer',
        createdAt: DateTime(2025),
      );
}

/// Sahte sunucunun yanıtı gerçek zamanda gelir; [finder] görünene kadar
/// bekleyip çizer.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  configureMarketTests();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installOrdersPlatformMocks();
    ApiService.debugUseHttpAdapter(FakeHttpAdapter({}));
  });

  // -------------------------------------------------------------------------
  group('Order.fromJson teslimat alanları', () {
    test('adresli sipariş', () {
      final order = Order.fromJson(_addressOrderJson());
      expect(order.isAddressDelivery, isTrue);
      expect(order.deliveryZone?.id, 'cumhuriyet');
      expect(order.deliveryZone?.type, DeliveryZoneType.mahalle);
      expect(order.deliveryAddress?.summary,
          'Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4');
      expect(order.deliveryAddress?.directions, 'Eczanenin üstü, mavi kapı');
      expect(order.deliveryFee, 40);
      expect(order.productTotal, 90);
      expect(order.totalAmount, 130);
      expect(order.awaitingCallback, isTrue);
      expect(order.deliveryOutcomeLabel, '');
    });

    test('teyit edilmiş arama artık beklenmez', () {
      final order = Order.fromJson(_addressOrderJson(
          callbackConfirmedAt: DateTime(2026, 10, 23).toIso8601String()));
      expect(order.needsCallback, isTrue);
      expect(order.callbackConfirmedAt, isNotNull);
      expect(order.awaitingCallback, isFalse);
    });

    test('eski yurt siparişi: varsayılanlar', () {
      final order = Order.fromJson(_dormOrderJson());
      expect(order.deliveryType, 'point');
      expect(order.isAddressDelivery, isFalse);
      expect(order.deliveryZone, isNull);
      expect(order.deliveryAddress, isNull);
      expect(order.deliveryFee, 0);
      expect(order.productTotal, isNull);
      expect(order.productTotalOrDerived, 15);
      expect(order.needsCallback, isFalse);
      expect(order.awaitingCallback, isFalse);
      expect(order.cancelReasonLabel, '');
    });

    test('alanlar eksik ya da bozuk: güvenli varsayılanlar', () {
      final order = Order.fromJson({
        '_id': 'x',
        'totalAmount': 50,
        'createdAt': _created,
        'deliveryType': 'unknown',
        'deliveryZone': 'bozuk',
        'deliveryAddress': 'bozuk',
        'callbackConfirmedAt': 12,
      });
      expect(order.deliveryType, 'point');
      expect(order.deliveryZone, isNull);
      expect(order.deliveryAddress, isNull);
      expect(order.deliveryFee, 0);
      expect(order.callbackConfirmedAt, isNull);
      expect(order.deliveryOutcomeLabel, '');
    });
  });

  // -------------------------------------------------------------------------
  group('Sipariş teslimat yardımcıları', () {
    test('ücret satırı ve tutar dökümü', () {
      final paid = Order.fromJson(_addressOrderJson());
      expect(orderShowsDeliveryFee(paid), isTrue);
      expect(orderDeliveryFeeText(paid), '₺40,00');
      // Ürünler − kupon + teslimat = toplam
      expect(orderProductsBeforeCoupon(paid) - paid.couponDiscount + paid.deliveryFee,
          paid.totalAmount);

      final free = Order.fromJson(_addressOrderJson(fee: 0));
      expect(orderShowsDeliveryFee(free), isTrue);
      expect(orderDeliveryFeeText(free), 'Ücretsiz teslimat');

      final dorm = Order.fromJson(_dormOrderJson());
      expect(orderShowsDeliveryFee(dorm), isFalse);
      expect(orderProductsBeforeCoupon(dorm), 15);
    });

    test('teslimat yeri', () {
      final address = OrderPlace.of(Order.fromJson(_addressOrderJson()))!;
      expect(address.title, 'Cumhuriyet Mahallesi');
      expect(address.detail, 'Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4');
      expect(address.directions, 'Eczanenin üstü, mavi kapı');

      final dorm = OrderPlace.of(Order.fromJson(_dormOrderJson()))!;
      expect(dorm.title, 'Kız KYK Yurdu');
      expect(dorm.detail, isNull);

      // Adres alanları gelmediyse sunucunun kısa özeti
      final json = _addressOrderJson()..remove('deliveryAddress');
      expect(OrderPlace.of(Order.fromJson(json))!.title,
          'Cumhuriyet Mah. · Atatürk Cd. No:5');
    });

    test('iptal nedenleri: yeni kodlar var, Diğer en sonda', () {
      final ids = orderCancelReasons.map((r) => r.id).toList();
      expect(ids, containsAll(['bolge_disi', 'ucret_yuksek']));
      expect(ids.last, 'diger');
      expect(ids.toSet().length, ids.length);
      final labels = {for (final r in orderCancelReasons) r.id: r.label};
      expect(labels['bolge_disi'], 'Adresime teslimat yok');
      expect(labels['ucret_yuksek'], 'Teslimat ücreti yüksek');
    });

    test('bölge özetleri', () {
      expect(zoneCountsSummary(_zones), '1 yurt · 1 mahalle');
      expect(zoneFeeRangeSummary(_zones), 'Teslimat bölgeye göre ücretsiz – ₺40');
      expect(zoneFeeRangeSummary([_zones.first]), 'Tüm bölgelerde ücretsiz teslimat');
      expect(zoneFeeRangeSummary([_zones.last]), 'Teslimat ₺40');
    });
  });

  // -------------------------------------------------------------------------
  group('OrderDeliveryNotes', () {
    Future<void> pumpNotes(WidgetTester tester, Order order) => pumpMarket(
        tester, Scaffold(body: OrderDeliveryNotes(order: order)));

    testWidgets('süren siparişte teyit notu', (tester) async {
      await withoutFontErrors(() async {
        await pumpNotes(tester, Order.fromJson(_addressOrderJson()));
        expect(find.text('Siparişini teyit etmek için seni arayacağız.'),
            findsOneWidget);
      });
    });

    testWidgets('iptal edilen siparişte teslim edilemedi nedeni', (tester) async {
      await withoutFontErrors(() async {
        final order = Order.fromJson(_addressOrderJson(
          status: 'İptal Edildi',
          outcome: 'Teslim edilemedi: Adres bulunamadı',
        ));
        await pumpNotes(tester, order);
        expect(find.text('Teslim edilemedi: Adres bulunamadı'), findsOneWidget);
        // İptal edilmiş siparişte teyit notu çıkmaz
        expect(find.text('Siparişini teyit etmek için seni arayacağız.'),
            findsNothing);
      });
    });

    testWidgets('müşterinin iptal nedeni ve notu', (tester) async {
      await withoutFontErrors(() async {
        final json = _dormOrderJson(status: 'İptal Edildi')
          ..['cancelReasonLabel'] = 'Teslimat ücreti yüksek'
          ..['cancelReasonNote'] = 'Bir dahaki sefere';
        await pumpNotes(tester, Order.fromJson(json));
        expect(
            find.text('İptal nedeni: Teslimat ücreti yüksek · “Bir dahaki sefere”'),
            findsOneWidget);
      });
    });
  });

  // -------------------------------------------------------------------------
  group('Siparişlerim', () {
    void serveOrders(List<Map<String, dynamic>> orders) {
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({
        'GET /orders-analytics/user-orders': (_) => {'orders': orders},
      }));
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    for (final (name, size, scale) in [
      ('normal', const Size(390, 4000), 1.0),
      ('320 px + yazı 1.3', const Size(320, 5000), 1.3),
    ]) {
      testWidgets('adres, ücret, teyit ve teslim edilemedi ($name)',
          (tester) async {
        await withoutFontErrors(() async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          serveOrders([
            _addressOrderJson(),
            _addressOrderJson(id: 'free00000001', fee: 0, needsCallback: false,
                status: 'Teslim Edildi'),
            _addressOrderJson(
              id: 'fail00000001',
              status: 'İptal Edildi',
              needsCallback: false,
              outcome: 'Teslim edilemedi: Adres bulunamadı',
            ),
            _dormOrderJson(),
          ]);
          await pumpMarket(tester, const OrdersPage(), size: size);
          await pumpUntil(tester, find.textContaining('Sipariş #'));

          expect(find.text('Siparişini teyit etmek için seni arayacağız.'),
              findsOneWidget);
          expect(find.text('Teslim edilemedi: Adres bulunamadı'), findsOneWidget);
          // Ücretli adres siparişi: dökümde teslimat ücreti
          expect(find.text('₺40,00'), findsWidgets);
          expect(find.text('Ücretsiz teslimat', skipOffstage: false),
              findsWidgets);
          // Eski yurt siparişinde ücret satırı yok: 3 adresli sipariş = 3 satır
          expect(find.text('Teslimat', skipOffstage: false), findsNWidgets(3));

          // Detaylar açılınca tam adres
          await tester.tap(find.textContaining('Sipariş detayları').first);
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Cumhuriyet Mahallesi'), findsOneWidget);
          expect(find.text('Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4'),
              findsOneWidget);
          expect(find.text('Eczanenin üstü, mavi kapı'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await dispose(tester);
        });
      });
    }

    testWidgets('iptal sayfasında yeni nedenler', (tester) async {
      await withoutFontErrors(() async {
        serveOrders([_addressOrderJson()]);
        await pumpMarket(tester, const OrdersPage());
        await pumpUntil(tester, find.text('İptal et'));
        await tester.tap(find.text('İptal et'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Adresime teslimat yok'), findsOneWidget);
        expect(find.text('Teslimat ücreti yüksek'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    });
  });

  // -------------------------------------------------------------------------
  group('Sipariş onayı', () {
    Future<DeliveryViewModel> pumpConfirmation(
      WidgetTester tester, {
      required Future<Order?> Function(String id) loader,
      double amount = 130,
      String point = 'Cumhuriyet Mah. · Atatürk Cd. No:5',
    }) async {
      final delivery = DeliveryViewModel(
          api: FakeDeliveryApi(zones: _zones), listenLifecycle: false);
      await pumpMarket(
        tester,
        OrderConfirmationPage(
          orderId: 'addr00000001',
          paymentMethod: PaymentMethod.cash,
          amount: amount,
          deliveryPointName: point,
          orderLoader: loader,
        ),
        size: const Size(390, 1400),
        wrap: (app) => MultiProvider(providers: [
          ChangeNotifierProvider.value(value: delivery),
          ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ], child: app),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return delivery;
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('adres, ücret, tahmini süre ve teyit notu', (tester) async {
      await withoutFontErrors(() async {
        await pumpConfirmation(tester,
            loader: (_) async => Order.fromJson(_addressOrderJson()));
        expect(find.text('Teslimat adresi'), findsOneWidget);
        expect(find.text('Cumhuriyet Mahallesi'), findsOneWidget);
        expect(find.text('Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4'),
            findsOneWidget);
        expect(find.text('Eczanenin üstü, mavi kapı'), findsOneWidget);
        expect(find.text('Tahmini teslimat'), findsOneWidget);
        expect(find.text('30-45 dk'), findsOneWidget);
        expect(find.text('Ürünler'), findsOneWidget);
        expect(find.text('₺100,00'), findsOneWidget);
        expect(find.text('Teslimat'), findsOneWidget);
        expect(find.text('₺40,00'), findsOneWidget);
        expect(find.text('Kapıda ödeyeceğin tutar'), findsOneWidget);
        expect(find.text('₺130,00'), findsOneWidget);
        expect(find.text('Siparişini teyit etmek için seni arayacağız.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    });

    testWidgets('ücretsiz teslimat', (tester) async {
      await withoutFontErrors(() async {
        await pumpConfirmation(tester,
            amount: 90,
            loader: (_) async =>
                Order.fromJson(_addressOrderJson(fee: 0, needsCallback: false)));
        expect(find.text('Ücretsiz teslimat'), findsOneWidget);
        expect(find.text('Siparişini teyit etmek için seni arayacağız.'),
            findsNothing);
        await dispose(tester);
      });
    });

    testWidgets('sipariş alınamazsa rota bilgileriyle çalışır', (tester) async {
      await withoutFontErrors(() async {
        await pumpConfirmation(tester,
            loader: (_) async => throw const ApiException('Ağ yok'));
        expect(find.text('Cumhuriyet Mah. · Atatürk Cd. No:5'), findsOneWidget);
        expect(find.text('₺130,00'), findsOneWidget);
        expect(find.text('Teslimat adresi'), findsNothing);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    });
  });

  // -------------------------------------------------------------------------
  group('Profil', () {
    Future<(DeliveryViewModel, FakeDeliveryApi)> pumpProfile(
        WidgetTester tester, {required bool canOrderToAddress}) async {
      final api = FakeDeliveryApi(
          canOrderToAddress: canOrderToAddress, zones: _zones);
      final delivery = DeliveryViewModel(api: api, listenLifecycle: false)
        ..onAuthChanged(true);
      await pumpMarket(
        tester,
        const ProfilePage(),
        size: const Size(390, 2600),
        wrap: (app) => MultiProvider(providers: [
          ChangeNotifierProvider<AuthViewModel>(create: (_) => _LoggedInAuth()),
          ChangeNotifierProvider(create: (_) => FavoritesViewModel()),
          ChangeNotifierProvider(create: (_) => ChatViewModel()),
          ChangeNotifierProvider(create: (_) => SettingsViewModel()),
          ChangeNotifierProvider.value(value: delivery),
        ], child: app),
      );
      await pumpUntil(tester, find.text('Kız KYK Yurdu'));
      return (delivery, api);
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Adreslerim yalnızca adrese teslimat açıkken', (tester) async {
      await withoutFontErrors(() async {
        final (delivery, api) =
            await pumpProfile(tester, canOrderToAddress: false);
        expect(find.text('Adreslerim'), findsNothing);
        // Kapalıyken yalnızca yurtlar listelenir
        expect(find.text('Kız KYK Yurdu'), findsOneWidget);
        expect(find.text('Cumhuriyet Mahallesi'), findsNothing);

        api.canOrderToAddress = true;
        await tester.runAsync(delivery.refreshAccess);
        await tester.pump();
        expect(find.text('Adreslerim'), findsOneWidget);
        expect(find.text('Teslimat adreslerini yönet'), findsOneWidget);
        expect(find.text('Cumhuriyet Mahallesi'), findsOneWidget);
        expect(find.text('Teslimat ₺40 · 30-45\u00A0dk'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    });

    testWidgets('bölgeler alınamazsa yurt adları ve yeniden dene',
        (tester) async {
      await withoutFontErrors(() async {
        ApiService.debugUseHttpAdapter(FakeHttpAdapter({
          'GET /settings': (_) => {
                'deliveryPoints': {
                  'girlsDorm': {'enabled': true, 'name': 'Kız KYK Yurdu'},
                  'boysDorm': {'enabled': false, 'name': 'Erkek KYK Yurdu'},
                },
              },
        }));
        final api = FakeDeliveryApi(zonesFail: true);
        final delivery = DeliveryViewModel(api: api, listenLifecycle: false);
        await pumpMarket(
          tester,
          const ProfilePage(),
          size: const Size(390, 2000),
          wrap: (app) => MultiProvider(providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (_) => SettingsViewModel()),
            ChangeNotifierProvider.value(value: delivery),
          ], child: app),
        );
        await pumpUntil(tester, find.text('Kız KYK Yurdu'));
        expect(find.text('Teslimat noktaları'), findsOneWidget);
        expect(find.text('Kız KYK Yurdu'), findsOneWidget);
        expect(find.byTooltip('Teslimat bölgelerini yeniden yükle'),
            findsOneWidget);

        api
          ..zonesFail = false
          ..zones = [
            for (var i = 0; i < 6; i++)
              DeliveryZone(
                id: 'z$i',
                name: 'Bölge $i',
                type: i < 4 ? DeliveryZoneType.mahalle : DeliveryZoneType.koy,
                deliveryFee: 20.0 + i * 5,
              ),
          ];
        await tester.tap(find.byTooltip('Teslimat bölgelerini yeniden yükle'));
        await pumpUntil(tester, find.text('Tüm teslimat bölgeleri'));
        // Çok bölge: özet + tüm bölgeler alt sayfası (misafir hepsini görür)
        expect(find.text('4 mahalle · 2 köy\nTeslimat bölgeye göre ₺20 – ₺45'),
            findsOneWidget);
        await tester.tap(find.text('Tüm teslimat bölgeleri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(DeliveryZonesSheet), findsOneWidget);
        expect(find.text('Bölge 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    });
  });
}
