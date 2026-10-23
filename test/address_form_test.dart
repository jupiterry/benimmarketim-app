import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/services/location_service.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:benimmarketim_app/views/address_form_page.dart';
import 'package:benimmarketim_app/views/widgets/address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'support/fake_delivery_api.dart';
import 'support/test_utils.dart';

/// Konum servisi yerine sabit sonuç döner.
class _FakeLocation extends LocationService {
  final LocationOutcome outcome;
  int calls = 0;

  _FakeLocation(this.outcome);

  @override
  Future<({LocationOutcome outcome, GeoPoint? point})> currentPoint() async {
    calls++;
    return (
      outcome: outcome,
      point: outcome == LocationOutcome.found
          ? const GeoPoint(41.2215, 31.9561)
          : null,
    );
  }
}

/// Formu '/' üstüne açar; kapanınca dönen sonucu [_FormHarness.result]'a yazar.
class _FormHarness {
  final FakeDeliveryApi api;
  final DeliveryViewModel delivery;
  DeliveryAddress? result;
  bool popped = false;

  _FormHarness(this.api) : delivery = createTestDeliveryViewModel(api);

  /// Yeni adreste form önce haritayı açar; [confirmMap] ise haritada
  /// "Bu konumu kullan"a basılıp forma geçilir.
  Future<void> open(
    WidgetTester tester, {
    DeliveryAddress? initial,
    String? initialZoneId,
    LocationService? location,
    bool confirmMap = true,
  }) async {
    location ??= _FakeLocation(LocationOutcome.found);
    await pumpMarket(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await context.push<DeliveryAddress>('/form');
                popped = true;
              },
              child: const Text('Formu aç'),
            ),
          ),
        ),
      ),
      routes: [
        GoRoute(
          path: '/form',
          builder: (context, state) => AddressFormPage(
            initial: initial,
            initialZoneId: initialZoneId,
            locationService: location!,
          ),
        ),
      ],
      wrap: (app) => ChangeNotifierProvider<DeliveryViewModel>.value(
        value: delivery,
        child: app,
      ),
      // Uzun form tek ekrana sığsın; alanlar kaydırmadan bulunur.
      size: const Size(390, 2400),
    );
    await settle(tester);
    await tester.tap(find.text('Formu aç'));
    await settle(tester);
    if (initial == null && confirmMap) {
      expect(find.text('Teslimat konumunu seç'), findsOneWidget);
      await tester.tap(find.text('Bu konumu kullan'));
      await settle(tester);
    }
  }
}

/// Haritada bulunan sahte konum
const _foundLocation = {'lat': 41.2215, 'lng': 31.9561};

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _tapSave(WidgetTester tester, [String text = 'Adresi kaydet']) async {
  await tester.tap(find.text(text));
  await settle(tester);
}

void main() {
  configureMarketTests();
  // Testte harita karoları ağdan indirilmez
  setUpAll(() => AddressMap.debugShowTiles = false);

  group('Mahalle', () {
    testWidgets('sokak ve bina no zorunlu; dolunca kaydedip adresle kapanır',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, initialZoneId: testZoneMahalle.id);

        expect(find.text('Cumhuriyet Mahallesi'), findsOneWidget);
        expect(find.text('Teslimat ₺40 · 30-45 dk'), findsOneWidget);

        await _tapSave(tester);
        expect(find.text('Sokak / cadde yaz'), findsOneWidget);
        expect(find.text('Bina no yaz'), findsOneWidget);
        expect(h.api.calls, isNot(contains('POST /addresses')));

        await tester.enterText(_field('Sokak / cadde'), 'Atatürk Cd.');
        await tester.enterText(_field('Bina no'), '5');
        await tester.pump();
        expect(find.text('Sokak / cadde yaz'), findsNothing);
        expect(find.text('Bina no yaz'), findsNothing);

        await _tapSave(tester);
        expect(h.api.lastCreateBody, isNotNull);
        expect(h.api.lastCreateBody!['zoneId'], 'cumhuriyet');
        expect(h.api.lastCreateBody!['street'], 'Atatürk Cd.');
        expect(h.api.lastCreateBody!['buildingNo'], '5');
        expect(h.api.lastCreateBody!['location'], _foundLocation);
        // İlk adres: varsayılan olarak gönderilir
        expect(h.api.lastCreateBody!['isDefault'], isTrue);
        expect(h.popped, isTrue);
        expect(h.result?.id, 'new1');
        expect(h.delivery.addresses, hasLength(1));
      });
    });

    testWidgets('ilk adreste "Varsayılan yap" açık ve kilitli', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, initialZoneId: testZoneMahalle.id);
        final toggle = tester.widget<Switch>(find.byType(Switch));
        expect(toggle.value, isTrue);
        expect(toggle.onChanged, isNull);
        expect(find.text('İlk adresin otomatik olarak varsayılan olur.'),
            findsOneWidget);
      });
    });

    testWidgets('uzunluk sınırları alanlara uygulanır', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, initialZoneId: testZoneMahalle.id);
        final limits = {
          'Sokak / cadde': AddressFields.streetMax,
          'Bina no': AddressFields.buildingNoMax,
          'Bina / site adı': AddressFields.buildingNameMax,
          'Kat': AddressFields.floorMax,
          'Daire': AddressFields.apartmentMax,
          'Adres tarifi (isteğe bağlı)': AddressFields.directionsMax,
        };
        for (final entry in limits.entries) {
          final field = tester.widget<TextField>(_field(entry.key));
          expect(field.maxLength, entry.value, reason: entry.key);
        }
        await tester.enterText(_field('Kat'), '12345678901234');
        await tester.pump();
        expect(
          tester.widget<TextField>(_field('Kat')).controller!.text.length,
          AddressFields.floorMax,
        );
      });
    });
  });

  group('Köy', () {
    testWidgets('sokak isteğe bağlı, tarif en az 10 karakter zorunlu',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, initialZoneId: testZoneKoy.id);

        expect(_field('Sokak / cadde (isteğe bağlı)'), findsOneWidget);
        await _tapSave(tester);
        expect(find.text('Sokak / cadde yaz'), findsNothing);
        expect(find.text('Bina no yaz'), findsNothing);
        expect(find.textContaining('kısa bir tarif yaz'), findsOneWidget);

        await tester.enterText(_field('Adres tarifi'), 'Cami yanı');
        await tester.pump();
        expect(find.textContaining('kısa bir tarif yaz'), findsOneWidget);
        expect(h.api.calls, isNot(contains('POST /addresses')));

        await tester.enterText(
            _field('Adres tarifi'), 'Cami yanındaki yeşil kapılı ev');
        await settle(tester); // hata → yardım metni geçişi
        expect(find.textContaining('kısa bir tarif yaz'), findsNothing);
        await _tapSave(tester);
        expect(h.api.lastCreateBody!['zoneId'], 'bostanlar');
        expect(h.api.lastCreateBody!['street'], '');
        expect(h.api.lastCreateBody!['directions'],
            'Cami yanındaki yeşil kapılı ev');
        expect(h.result?.zoneType, DeliveryZoneType.koy);
      });
    });
  });

  group('Yurt', () {
    testWidgets('eski yurt adresinde yalnızca blok/oda alanı, harita yok',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi(addresses: [
          testAddress(
            zone: testZoneYurt,
            isDefault: true,
            fields: const AddressFields(),
          ),
        ]));
        await h.open(
          tester,
          initial: h.api.addresses.single,
        );

        expect(_field('Blok / oda (isteğe bağlı)'), findsOneWidget);
        expect(find.textContaining('Sokak / cadde'), findsNothing);
        expect(_field('Bina no'), findsNothing);
        expect(find.text('Teslimat konumu'), findsNothing);
      });
    });
  });

  group('Bölge seçimi', () {
    testWidgets('bölge seçilmeden alanlar gösterilmez; seçiciden seçilir',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester);

        expect(find.text('Bölgeni seç'), findsOneWidget);
        expect(_field('Sokak / cadde'), findsNothing);
        await _tapSave(tester);
        expect(find.text('Mahalleni ya da köyünü seç'), findsOneWidget);

        await tester.tap(find.text('Bölgeni seç'));
        await settle(tester);
        expect(find.text('MAHALLELER'), findsOneWidget);
        expect(find.text('KÖYLER'), findsOneWidget);
        // Yurtlar adres değil; ödemede teslimat noktası olarak seçilir
        expect(find.text('YURTLAR'), findsNothing);
        expect(find.text('Kız KYK Yurdu'), findsNothing);

        // Türkçe duyarsız arama: "ozbag" → "Özbağ Mahallesi"
        await tester.enterText(find.byType(TextField).last, 'ozbag');
        await tester.pump();
        expect(find.text('Cumhuriyet Mahallesi'), findsNothing);
        expect(find.text('Özbağ Mahallesi'), findsOneWidget);

        await tester.enterText(find.byType(TextField).last, 'xyz');
        await tester.pump();
        expect(find.text('Aramana uyan bölge yok'), findsOneWidget);

        await tester.enterText(find.byType(TextField).last, 'bostan');
        await tester.pump();
        await tester.tap(find.text('Bostanlar Köyü'));
        await settle(tester);
        expect(find.text('Bostanlar Köyü'), findsOneWidget);
        expect(_field('Adres tarifi'), findsOneWidget);
      });
    });

    testWidgets('kampanyada ücret üstü çizili ve kampanya notu görünür',
        (tester) async {
      await withoutFontErrors(() async {
        final api = FakeDeliveryApi(
          freeDeliveryEverywhere: true,
          zones: const [
            DeliveryZone(
              id: 'cumhuriyet',
              name: 'Cumhuriyet Mahallesi',
              type: DeliveryZoneType.mahalle,
              deliveryFee: 40,
              isFree: true,
            ),
          ],
        );
        final h = _FormHarness(api);
        await h.open(tester);
        await tester.tap(find.text('Bölgeni seç'));
        await settle(tester);
        expect(find.text('Kampanya: tüm bölgelerde teslimat ücretsiz'),
            findsOneWidget);
        expect(find.textContaining('Ücretsiz teslimat ₺40', findRichText: true),
            findsOneWidget);
      });
    });
  });

  group('Düzenleme', () {
    testWidgets('yalnızca değişen alanlar gönderilir', (tester) async {
      await withoutFontErrors(() async {
        final address = testAddress(
          fields: const AddressFields(
            street: 'Atatürk Cd.',
            buildingNo: '5',
            buildingName: 'Gül Apt.',
            directions: 'Eczanenin karşısı',
            location: GeoPoint(41.2, 31.9),
          ),
        );
        final h = _FormHarness(FakeDeliveryApi(addresses: [address]));
        await h.open(tester, initial: address);

        // Değişiklik yokken kaydet pasif
        final save = find.widgetWithText(FilledButton, 'Değişiklikleri kaydet');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);

        await tester.enterText(_field('Bina / site adı'), 'Lale Sitesi');
        // Konum haritadan değiştirilir: kayıtlı noktada açılır, "Konumuma
        // git" ile kullanıcının konumuna gidilir
        await tester.tap(find.text('Konumu değiştir'));
        await settle(tester);
        await tester.tap(find.byTooltip('Konumuma git'));
        await settle(tester);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

        await _tapSave(tester, 'Değişiklikleri kaydet');
        expect(h.api.lastUpdateChanges, {
          'buildingName': 'Lale Sitesi',
          'location': _foundLocation,
        });
        expect(h.result?.fields.buildingName, 'Lale Sitesi');
        expect(h.result?.fields.location?.lat, 41.2215);
      });
    });

    testWidgets('bölge değişince zoneId de gönderilir', (tester) async {
      await withoutFontErrors(() async {
        final address = testAddress();
        final h = _FormHarness(FakeDeliveryApi(addresses: [address]));
        await h.open(tester, initial: address);

        await tester.tap(find.text('Değiştir'));
        await settle(tester);
        await tester.tap(find.text('Özbağ Mahallesi'));
        await settle(tester);
        await _tapSave(tester, 'Değişiklikleri kaydet');
        expect(h.api.lastUpdateChanges, {'zoneId': 'ozbag'});
        expect(h.result?.zoneName, 'Özbağ Mahallesi');
      });
    });

    testWidgets('varsayılan yapma PATCH ile ayrıca gönderilir', (tester) async {
      await withoutFontErrors(() async {
        final first = testAddress(id: 'a1', isDefault: true);
        final second = testAddress(id: 'a2', label: 'İş');
        final h = _FormHarness(FakeDeliveryApi(addresses: [first, second]));
        await h.open(tester, initial: second);

        await tester.tap(find.byType(Switch));
        await tester.pump();
        await _tapSave(tester, 'Değişiklikleri kaydet');
        expect(h.api.calls, contains('PATCH /addresses/a2/default'));
        expect(h.api.calls, isNot(contains('PUT /addresses/a2')));
        expect(h.result?.isDefault, isTrue);
      });
    });
  });

  group('Geri', () {
    testWidgets('kaydedilmemiş değişiklikte onay ister', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, initialZoneId: testZoneMahalle.id);

        await tester.enterText(_field('Sokak / cadde'), 'Atatürk Cd.');
        await tester.tap(find.byTooltip('Geri'));
        await settle(tester);
        expect(find.text('Değişiklikler kaydedilmesin mi?'), findsOneWidget);
        await tester.tap(find.text('Düzenlemeye devam et'));
        await settle(tester);
        expect(h.popped, isFalse);

        await tester.tap(find.byTooltip('Geri'));
        await settle(tester);
        await tester.tap(find.text('Kaydetmeden çık'));
        await settle(tester);
        expect(h.popped, isTrue);
        expect(h.result, isNull);
        expect(h.api.calls, isNot(contains('POST /addresses')));
      });
    });

    testWidgets('değişiklik yoksa onaysız kapanır', (tester) async {
      await withoutFontErrors(() async {
        final address = testAddress(isDefault: true);
        final h = _FormHarness(FakeDeliveryApi(addresses: [address]));
        await h.open(tester, initial: address);
        await tester.tap(find.byTooltip('Geri'));
        await settle(tester);
        expect(find.text('Değişiklikler kaydedilmesin mi?'), findsNothing);
        expect(h.popped, isTrue);
      });
    });
  });

  group('Sunucu hataları', () {
    testWidgets('ADDRESS_LIMIT mesajı kaydet butonunun yanında gösterilir',
        (tester) async {
      await withoutFontErrors(() async {
        final api = FakeDeliveryApi()
          ..saveError = const ApiException(
            'En fazla 5 adres kaydedebilirsin.',
            statusCode: 400,
            code: 'ADDRESS_LIMIT',
          );
        final h = _FormHarness(api);
        await h.open(tester, initialZoneId: testZoneKoy.id);
        await tester.enterText(
            _field('Adres tarifi'), 'Cami yanındaki yeşil kapılı ev');
        await _tapSave(tester);
        expect(find.text('En fazla 5 adres kaydedebilirsin.'), findsOneWidget);
        expect(h.popped, isFalse);
      });
    });

    testWidgets('5 adres doluyken yeni adres kaydedilemez', (tester) async {
      await withoutFontErrors(() async {
        final api = FakeDeliveryApi(addresses: [
          for (var i = 0; i < 5; i++) testAddress(id: 'a$i'),
        ]);
        final h = _FormHarness(api);
        await h.open(tester, initialZoneId: testZoneKoy.id);
        expect(find.textContaining('En fazla 5 adres kaydedebilirsin'),
            findsOneWidget);
        final save = find.widgetWithText(FilledButton, 'Adresi kaydet');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
      });
    });
  });

  group('Harita', () {
    testWidgets('yeni adreste önce harita açılır ve konum gösterilir',
        (tester) async {
      await withoutFontErrors(() async {
        final location = _FakeLocation(LocationOutcome.found);
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester,
            initialZoneId: testZoneMahalle.id,
            location: location,
            confirmMap: false);
        expect(find.text('Teslimat konumunu seç'), findsOneWidget);
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
        expect(location.calls, 1); // açılır açılmaz konum istenir

        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);
        expect(find.text('Teslimat konumu'), findsOneWidget);
        expect(find.byType(AddressMapPreview), findsOneWidget);
        expect(find.text('Konumu değiştir'), findsOneWidget);
      });
    });

    testWidgets('haritadan seçmeden çıkılırsa form da kapanır', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester, confirmMap: false);
        await tester.tap(find.byTooltip('Geri'));
        await settle(tester);
        expect(h.popped, isTrue);
        expect(h.result, isNull);
        expect(h.api.calls, isNot(contains('POST /addresses')));
      });
    });

    testWidgets('izin verilmezse harita Devrek merkezinde açılır',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester,
            initialZoneId: testZoneMahalle.id,
            location: _FakeLocation(LocationOutcome.denied),
            confirmMap: false);
        expect(find.textContaining('Konum izni verilmedi'), findsOneWidget);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);

        await tester.enterText(_field('Sokak / cadde'), 'Atatürk Cd.');
        await tester.enterText(_field('Bina no'), '5');
        await _tapSave(tester);
        final sent = h.api.lastCreateBody!['location'] as Map;
        expect(sent['lat'], closeTo(AddressMap.devrekCenter.latitude, 1e-6));
        expect(sent['lng'], closeTo(AddressMap.devrekCenter.longitude, 1e-6));
      });
    });

    testWidgets('kalıcı redde "Ayarları aç" gösterilir', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester,
            location: _FakeLocation(LocationOutcome.deniedForever),
            confirmMap: false);
        expect(find.text('Ayarları aç'), findsOneWidget);
      });
    });

    testWidgets('konum servisi kapalıysa "Konum ayarlarını aç" gösterilir',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester,
            location: _FakeLocation(LocationOutcome.serviceOff),
            confirmMap: false);
        expect(find.text('Konum ayarlarını aç'), findsOneWidget);
        expect(find.text('Bu konumu kullan'), findsOneWidget);
      });
    });

    testWidgets('Devrek dışındaysa uyarı gösterilir, harita Devrek\'te kalır',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(FakeDeliveryApi());
        await h.open(tester,
            location: _OutsideLocation(), confirmMap: false);
        expect(find.textContaining('Devrek dışında görünüyorsun'),
            findsOneWidget);
      });
    });
  });
}

/// Devrek dışında (Ankara) bir konum
class _OutsideLocation extends LocationService {
  @override
  Future<({LocationOutcome outcome, GeoPoint? point})> currentPoint() async =>
      (outcome: LocationOutcome.found, point: const GeoPoint(39.92, 32.85));
}
