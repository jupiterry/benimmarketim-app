// Teslimat ücreti görünürlüğü: ücretsiz / ücretli / eşik / kampanya.

import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/viewmodels/cart_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:benimmarketim_app/views/widgets/delivery_offer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_delivery_api.dart';
import 'support/orders_test_utils.dart' show installOrdersPlatformMocks;
import 'support/test_utils.dart';

const _devrekFree = DeliveryZone(
  id: 'devrek',
  name: 'Devrek',
  type: DeliveryZoneType.ilce,
  deliveryFee: 0,
  isFree: true,
);

Future<DeliveryViewModel> _delivery(
    WidgetTester tester, List<DeliveryZone> zones,
    {bool open = true, bool campaign = false}) async {
  final api = FakeDeliveryApi(
    zones: zones,
    freeDeliveryEverywhere: campaign,
    access: DeliveryAccess(
      addressOrdering: open ? 'public' : 'off',
      canOrderToAddress: open,
    ),
  );
  final delivery = createTestDeliveryViewModel(api);
  await tester.pump();
  await tester.pump();
  return delivery;
}

void main() {
  configureMarketTests();
  // Sepet sqflite kullanır
  setUp(installOrdersPlatformMocks);

  testWidgets('adrese teslimat kapalı: yurt akışı ücretsiz', (tester) async {
    final delivery = await _delivery(tester, devrekZones, open: false);
    final offer = DeliveryOffer.of(delivery, 0);
    expect(offer.free, isTrue);
    expect(offer.title, 'Ücretsiz teslimat');
    expect(offer.chipLabel, 'Ücretsiz teslimat');
    expect(DeliveryOffer.of(null, 0).free, isTrue);
  });

  testWidgets('Devrek ücretli: tutar, eşik, kalan ve yurt notu',
      (tester) async {
    final delivery = await _delivery(tester, devrekZones);
    var offer = DeliveryOffer.of(delivery, 0);
    expect(offer.free, isFalse);
    expect(offer.title, 'Teslimat ₺40');
    expect(offer.chipLabel, 'Teslimat ₺40 · ₺500 üstü ücretsiz');
    expect(offer.detail, '₺500 üstü siparişte ücretsiz · yurtlara ücretsiz');
    expect(offer.progress, isNull);

    offer = DeliveryOffer.of(delivery, 380);
    expect(
        offer.detail, '₺120 daha ekle, teslimat ücretsiz · yurtlara ücretsiz');
    expect(offer.progress, closeTo(.76, 1e-9));

    // Eşik geçildi: ücretsiz
    offer = DeliveryOffer.of(delivery, 520);
    expect(offer.free, isTrue);
    expect(offer.title, 'Ücretsiz teslimat');
    expect(offer.detail, '₺500 üstü siparişte teslimat ücretsiz');
  });

  testWidgets('Devrek ücretsiz ya da kampanya: ücretsiz', (tester) async {
    var delivery = await _delivery(tester, const [testZoneYurt, _devrekFree]);
    expect(DeliveryOffer.of(delivery, 0).free, isTrue);
    expect(DeliveryOffer.of(delivery, 0).detail, isNull);

    delivery = await _delivery(tester, devrekZones, campaign: true);
    final offer = DeliveryOffer.of(delivery, 0);
    expect(offer.free, isTrue);
    expect(offer.campaign, isTrue);
    expect(offer.detail, 'Kampanya: tüm bölgelerde teslimat ücretsiz');
  });

  testWidgets('bant: ücretsiz yeşil, ücretli tutar ve ilerleme',
      (tester) async {
    await withoutFontErrors(() async {
      Future<void> pump(DeliveryViewModel delivery) => tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<DeliveryViewModel?>.value(
                    value: delivery),
                ChangeNotifierProvider(create: (_) => CartViewModel()),
              ],
              child: const MaterialApp(
                home: Scaffold(body: DeliveryOfferBanner()),
              ),
            ),
          );

      await pump(await _delivery(tester, const [testZoneYurt, _devrekFree]));
      expect(find.text('Ücretsiz teslimat'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await pump(await _delivery(tester, devrekZones));
      expect(find.text('Teslimat ₺40'), findsOneWidget);
      expect(find.text('₺500 üstü siparişte ücretsiz · yurtlara ücretsiz'),
          findsOneWidget);
    });
  });
}
