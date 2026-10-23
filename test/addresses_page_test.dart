import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:benimmarketim_app/views/address_form_page.dart';
import 'package:benimmarketim_app/views/addresses_page.dart';
import 'package:benimmarketim_app/views/widgets/delivery_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'support/fake_delivery_api.dart';
import 'support/test_utils.dart';
import 'package:benimmarketim_app/views/widgets/address_map.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<DeliveryViewModel> _open(WidgetTester tester, FakeDeliveryApi api,
    {Size size = const Size(390, 1600)}) async {
  final delivery = createTestDeliveryViewModel(api);
  addTearDown(delivery.dispose);
  await pumpMarket(
    tester,
    const AddressesPage(),
    routes: [
      GoRoute(
        path: '/addresses/new',
        builder: (context, state) => const AddressFormPage(),
      ),
      GoRoute(
        path: '/addresses/edit',
        builder: (context, state) =>
            AddressFormPage(initial: state.extra as DeliveryAddress),
      ),
    ],
    wrap: (app) => ChangeNotifierProvider<DeliveryViewModel>.value(
      value: delivery,
      child: app,
    ),
    size: size,
  );
  await settle(tester);
  return delivery;
}

FilledButton _addButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Adres ekle'), matching: find.byType(FilledButton)));

void main() {
  configureMarketTests();
  setUpAll(() => AddressMap.debugShowTiles = false);

  testWidgets('adresler kartlarda listelenir; varsayılan rozeti görünür',
      (tester) async {
    await withoutFontErrors(() async {
      await _open(
        tester,
        FakeDeliveryApi(addresses: [
          testAddress(id: 'a1', label: 'Ev', isDefault: true),
          testAddress(
            id: 'a2',
            label: '',
            zone: testZoneKoy,
            fields: const AddressFields(
                directions: 'Cami yanındaki yeşil kapılı ev'),
          ),
        ]),
      );
      expect(find.text('Ev'), findsOneWidget);
      expect(find.text('Varsayılan'), findsOneWidget);
      expect(find.text('Cumhuriyet Mahallesi'), findsOneWidget);
      expect(find.text('Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4'),
          findsOneWidget);
      expect(find.text('Eczanenin karşısı'), findsOneWidget);
      // Etiketsiz adresin başlığı bölge adıdır
      expect(find.text('Bostanlar Köyü'), findsOneWidget);
      expect(find.text('Varsayılan yap'), findsOneWidget);
      expect(find.text('2/5 adres kayıtlı'), findsOneWidget);
      expect(_addButton(tester).onPressed, isNotNull);
    });
  });

  testWidgets('5 adres doluyken "Adres ekle" pasif ve açıklamalı',
      (tester) async {
    await withoutFontErrors(() async {
      await _open(
        tester,
        FakeDeliveryApi(addresses: [
          for (var i = 0; i < 5; i++)
            testAddress(id: 'a$i', label: 'Adres $i', isDefault: i == 0),
        ]),
      );
      expect(_addButton(tester).onPressed, isNull);
      expect(
        find.text(
            'En fazla 5 adres kaydedebilirsin; yenisini eklemek için birini sil.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('kapalı bölgedeki adres soluk ve uyarılı', (tester) async {
    await withoutFontErrors(() async {
      await _open(
        tester,
        FakeDeliveryApi(addresses: [
          testAddress(id: 'a1', isDefault: true),
          testAddress(id: 'a2', label: 'İş', zoneEnabled: false),
        ]),
      );
      expect(find.textContaining(zoneClosedNote), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
      // Kapalı bölgedeki adres varsayılan yapılamaz
      expect(find.text('Varsayılan yap'), findsNothing);
    });
  });

  testWidgets('bölge listede yoksa (sonradan kapandı) adres kapalı sayılır',
      (tester) async {
    await withoutFontErrors(() async {
      final api = FakeDeliveryApi(
        zones: const [testZoneFree],
        addresses: [testAddress(id: 'a1', isDefault: true)],
      );
      await _open(tester, api);
      expect(find.textContaining(zoneClosedNote), findsOneWidget);
    });
  });

  testWidgets('adres yoksa boş durum ve "Adres ekle" formu açar',
      (tester) async {
    await withoutFontErrors(() async {
      await _open(tester, FakeDeliveryApi());
      expect(find.text('Henüz kayıtlı adresin yok'), findsOneWidget);
      await tester.tap(find.text('Adres ekle'));
      await settle(tester);
      // Yeni adres haritayla başlar
      expect(find.text('Teslimat konumunu seç'), findsOneWidget);
    });
  });

  testWidgets('yükleme hatasında "Tekrar dene" yeniden yükler', (tester) async {
    await withoutFontErrors(() async {
      final api = FakeDeliveryApi(addresses: [testAddress(isDefault: true)])
        ..addressesError = const ApiException('Adreslerin alınamadı.');
      await _open(tester, api);
      expect(find.text('Adreslerin yüklenemedi'), findsOneWidget);
      expect(find.text('Adreslerin alınamadı.'), findsOneWidget);

      api.addressesError = null;
      await tester.tap(find.text('Tekrar dene'));
      await settle(tester);
      expect(find.text('Ev'), findsOneWidget);
    });
  });

  testWidgets('adrese teslimat kapanınca liste yerine bilgi gösterilir',
      (tester) async {
    await withoutFontErrors(() async {
      final api = FakeDeliveryApi(addresses: [testAddress(isDefault: true)]);
      final delivery = await _open(tester, api);
      expect(find.text('Ev'), findsOneWidget);

      api.access = DeliveryAccess.disabled;
      await delivery.refreshAccess();
      await settle(tester);
      expect(find.text('Adrese teslimat şu an kapalı'), findsOneWidget);
      expect(find.text('Ev'), findsNothing);
      expect(find.text('Adres ekle'), findsNothing);
    });
  });

  testWidgets('silme onay ister; onaylanınca adres silinir', (tester) async {
    await withoutFontErrors(() async {
      final api = FakeDeliveryApi(addresses: [
        testAddress(id: 'a1', isDefault: true),
        testAddress(id: 'a2', label: 'İş'),
      ]);
      final delivery = await _open(tester, api);

      await tester.tap(find.byTooltip('Adresi sil').last);
      await settle(tester);
      expect(find.text('Adres silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);
      expect(api.calls, isNot(contains('DELETE /addresses/a2')));

      await tester.tap(find.byTooltip('Adresi sil').last);
      await settle(tester);
      await tester.tap(find.text('Sil'));
      await settle(tester);
      expect(api.calls, contains('DELETE /addresses/a2'));
      expect(delivery.addresses.map((a) => a.id), ['a1']);
      expect(find.text('İş'), findsNothing);
    });
  });

  testWidgets('"Varsayılan yap" adresi varsayılan yapar', (tester) async {
    await withoutFontErrors(() async {
      final api = FakeDeliveryApi(addresses: [
        testAddress(id: 'a1', isDefault: true),
        testAddress(id: 'a2', label: 'İş'),
      ]);
      final delivery = await _open(tester, api);
      await tester.tap(find.text('Varsayılan yap'));
      await settle(tester);
      expect(api.calls, contains('PATCH /addresses/a2/default'));
      expect(delivery.defaultAddress?.id, 'a2');
    });
  });
}
