import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/services/geocoding_service.dart';
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

  /// Telefonun bildiği son konum (null: yok)
  final GeoPoint? lastKnown;

  _FakeLocation(this.outcome, {this.lastKnown});

  @override
  Future<GeoPoint?> lastKnownPoint() async => lastKnown;

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

/// Ağ yerine sabit yer bilgisi ve arama sonucu döner (null: bulunamadı).
class _FakeGeocoding extends GeocodingService {
  PlaceInfo? place;
  List<PlaceSearchResult> results;
  bool searchFails = false;
  int calls = 0;
  final List<String> queries = [];

  _FakeGeocoding([this.place, this.results = const []]);

  @override
  Future<PlaceInfo?> reverse(GeoPoint point) async {
    calls++;
    return place;
  }

  @override
  Future<List<PlaceSearchResult>> search(
    String query, {
    required GeoPoint southWest,
    required GeoPoint northEast,
    int limit = 8,
  }) async {
    queries.add(query);
    if (searchFails) throw const GeocodingException();
    return results;
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
    GeocodingService? geocoding,
    bool confirmMap = true,
  }) async {
    location ??= _FakeLocation(LocationOutcome.found);
    geocoding ??= _FakeGeocoding();
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
            geocoding: geocoding,
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
      expect(find.text('İğneyi kapına getir'), findsOneWidget);
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

Future<void> _tapSave(WidgetTester tester,
    [String text = 'Adresi kaydet']) async {
  await tester.tap(find.text(text));
  await settle(tester);
}

FakeDeliveryApi _devrekApi({
  List<DeliveryZone> zones = devrekZones,
  List<DeliveryAddress> addresses = const [],
  bool withArea = true,
}) =>
    FakeDeliveryApi(
      zones: zones,
      addresses: addresses,
      area: withArea ? testDevrekArea : null,
    );

/// Devrek'te kayıtlı adres
DeliveryAddress _devrekAddress({
  String id = 'a1',
  String label = 'Ev',
  bool isDefault = false,
}) =>
    testAddress(
      id: id,
      label: label,
      zone: testZoneDevrek,
      isDefault: isDefault,
      fields: const AddressFields(
        neighborhood: 'Cumhuriyet Mahallesi',
        street: 'Atatürk Cd.',
        buildingNo: '5',
        buildingName: 'Gül Apt.',
        directions: 'Eczanenin karşısı',
        location: GeoPoint(41.22, 31.95),
      ),
    );

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(_field('Mahalle'), 'Cumhuriyet');
  await tester.enterText(_field('Sokak / cadde'), 'Atatürk Cd.');
  await tester.enterText(_field('Bina no'), '5');
  await tester.pump();
}

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

void main() {
  configureMarketTests();
  // Testte harita karoları ağdan indirilmez
  setUpAll(() => AddressMap.debugShowTiles = false);

  group('Devrek adresi', () {
    testWidgets('anlamsız bina no, kat ve daire kabul edilmez', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester);
        await tester.enterText(_field('Mahalle'), 'Cumhuriyet');
        await tester.enterText(_field('Sokak / cadde'), 'Atatürk Cd.');
        await tester.enterText(_field('Bina no'), 'test');
        await tester.enterText(_field('Kat'), 'abc');
        await tester.enterText(_field('Daire'), 'xyz');
        await _tapSave(tester);
        expect(find.text('Rakamla yaz (örn. 5, 12A, 15/2)'), findsOneWidget);
        expect(find.text('Örn. 2, Zemin, Bodrum'), findsOneWidget);
        expect(find.text('Örn. 4, 4B'), findsOneWidget);
        expect(h.api.calls, isNot(contains('POST /addresses')));

        await tester.enterText(_field('Bina no'), '12A');
        await tester.enterText(_field('Kat'), 'Zemin');
        await tester.enterText(_field('Daire'), '4');
        await tester.pump();
        await _tapSave(tester);
        expect(h.api.lastCreateBody!['buildingNo'], '12A');
        expect(h.api.lastCreateBody!['floor'], 'Zemin');
        expect(h.popped, isTrue);
      });
    });

    testWidgets(
        'telefonun bildiği son konum Devrek\'teyse harita oradan açılır',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        // GPS sonuç vermiyor; son bilinen konum yine de kullanılır
        await h.open(tester,
            location: _FakeLocation(LocationOutcome.failed,
                lastKnown: const GeoPoint(41.2301, 31.9512)));
        await _fillRequired(tester);
        await _tapSave(tester);
        final sent = h.api.lastCreateBody!['location'] as Map;
        expect(sent['lat'], closeTo(41.2301, 1e-6));
        expect(sent['lng'], closeTo(31.9512, 1e-6));
      });
    });

    testWidgets('bölge kendiliğinden Devrek; mahalle, sokak, bina no zorunlu',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester);

        // Tek adres bölgesi: seçici yok, bilgi olarak görünür
        expect(find.text('Devrek'), findsOneWidget);
        expect(find.text('Teslimat ₺40 · 45-60 dk'), findsOneWidget);
        expect(find.text('Değiştir'), findsNothing);
        expect(h.api.calls, contains('GET /delivery/zones/devrek/area'));

        await _tapSave(tester);
        expect(find.text('Mahalleni yaz'), findsOneWidget);
        expect(find.text('Sokak / cadde yaz'), findsOneWidget);
        expect(find.text('Bina no yaz'), findsOneWidget);
        expect(h.api.calls, isNot(contains('POST /addresses')));

        await _fillRequired(tester);
        expect(find.text('Mahalleni yaz'), findsNothing);

        await _tapSave(tester);
        final body = h.api.lastCreateBody!;
        expect(body['zoneId'], 'devrek');
        expect(body['neighborhood'], 'Cumhuriyet');
        expect(body['street'], 'Atatürk Cd.');
        expect(body['buildingNo'], '5');
        expect(body['location'], _foundLocation);
        // İlk adres: varsayılan olarak gönderilir
        expect(body['isDefault'], isTrue);
        expect(h.popped, isTrue);
        expect(h.result?.id, 'new1');
        expect(h.result?.summary, 'Cumhuriyet Mah. · Atatürk Cd. No:5');
      });
    });

    testWidgets('haritadaki konumdan mahalle, sokak ve bina no dolar',
        (tester) async {
      await withoutFontErrors(() async {
        final geocoding = _FakeGeocoding(const PlaceInfo(
          area: 'Cumhuriyet Mahallesi',
          road: 'Atatürk Caddesi',
          houseNumber: '5',
        ));
        final h = _FormHarness(_devrekApi());
        await h.open(tester, geocoding: geocoding, confirmMap: false);
        await settle(tester);
        // Haritada yer adı canlı görünür
        expect(find.text('Cumhuriyet Mahallesi · Atatürk Caddesi No:5'),
            findsOneWidget);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);

        expect(_text(tester, 'Mahalle'), 'Cumhuriyet Mahallesi');
        expect(_text(tester, 'Sokak / cadde'), 'Atatürk Caddesi');
        expect(_text(tester, 'Bina no'), '5');

        // Kullanıcının yazdığı alan korunur; otomatik dolanlar yeni konuma
        // göre yenilenir.
        await tester.enterText(_field('Sokak / cadde'), 'Kendi Sokağım');
        geocoding.place =
            const PlaceInfo(area: 'Özbağ Mahallesi', road: 'Gül Sk.');
        await tester.tap(find.text('Konumu değiştir'));
        await settle(tester);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);
        expect(_text(tester, 'Mahalle'), 'Özbağ Mahallesi');
        expect(_text(tester, 'Sokak / cadde'), 'Kendi Sokağım');
        expect(_text(tester, 'Bina no'), '');
      });
    });

    testWidgets('ilk adreste "Varsayılan yap" açık ve kilitli', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester);
        final toggle = tester.widget<Switch>(find.byType(Switch));
        expect(toggle.value, isTrue);
        expect(toggle.onChanged, isNull);
        expect(find.text('İlk adresin otomatik olarak varsayılan olur.'),
            findsOneWidget);
      });
    });

    testWidgets('uzunluk sınırları alanlara uygulanır', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester);
        final limits = {
          'Mahalle': AddressFields.neighborhoodMax,
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
        expect(_text(tester, 'Kat').length, AddressFields.floorMax);
      });
    });

    testWidgets('adrese teslimat kapalıysa açıklama, harita açılmaz',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi(zones: const [testZoneYurt]));
        await h.open(tester, confirmMap: false);
        expect(find.text('İğneyi kapına getir'), findsNothing);
        expect(find.text('Şu an adrese teslimat yapılmıyor'), findsOneWidget);
        expect(find.text('Adresi kaydet'), findsNothing);

        // Panelde Devrek açılınca "Yenile" ile harita adımı gelir
        h.api.zones = List.of(devrekZones);
        await tester.tap(find.text('Yenile'));
        await settle(tester);
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
      });
    });

    testWidgets('bölgeler alınamazsa hata ve yeniden dene', (tester) async {
      await withoutFontErrors(() async {
        final api = _devrekApi()
          ..zonesError = const ApiException('Bağlantı yok');
        final h = _FormHarness(api);
        await h.open(tester, confirmMap: false);
        expect(find.text('Teslimat bölgeleri yüklenemedi'), findsOneWidget);

        api.zonesError = null;
        await tester.tap(find.text('Tekrar dene'));
        await settle(tester);
        // Bölge gelince harita adımı açılır
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
      });
    });
  });

  group('Teslimat alanı', () {
    testWidgets('sınır dışındaki nokta seçilemez', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        // Devrek kutusunda ama teslimat alanının dışında
        await h.open(tester,
            location: _PointLocation(const GeoPoint(41.30, 32.10)),
            confirmMap: false);
        expect(
            find.textContaining('teslimat alanımızın dışında'), findsOneWidget);
        final confirm = find.widgetWithText(FilledButton, 'Bu konumu kullan');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      });
    });

    testWidgets('sınır içindeki nokta seçilir', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester, confirmMap: false);
        expect(
            find.textContaining('teslimat alanımızın dışında'), findsNothing);
        final confirm = find.widgetWithText(FilledButton, 'Bu konumu kullan');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      });
    });

    testWidgets('sınır yüklü değilse denetim yapılmaz', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi(withArea: false));
        await h.open(tester,
            location: _PointLocation(const GeoPoint(41.30, 32.10)),
            confirmMap: false);
        expect(
            find.textContaining('teslimat alanımızın dışında'), findsNothing);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);
        expect(find.text('Teslimat konumu'), findsOneWidget);
      });
    });

    testWidgets('sunucu OUT_OF_AREA derse harita yeniden açılır',
        (tester) async {
      await withoutFontErrors(() async {
        final api = _devrekApi()
          ..saveError = const ApiException(
            'Bu adres teslimat alanımızın dışında. Haritada Devrek sınırı içinde bir nokta seç.',
            statusCode: 400,
            code: 'OUT_OF_AREA',
          );
        final h = _FormHarness(api);
        await h.open(tester);
        await _fillRequired(tester);
        await _tapSave(tester);
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
        expect(h.popped, isFalse);
      });
    });
  });

  group('Haritada arama', () {
    const results = [
      PlaceSearchResult(
        point: GeoPoint(41.2301, 31.9512),
        title: 'Atatürk Caddesi',
        subtitle: 'Cumhuriyet Mahallesi · Devrek',
      ),
      PlaceSearchResult(
        point: GeoPoint(41.21, 31.96),
        title: 'Devrek Devlet Hastanesi',
      ),
    ];

    /// Yazarken öneri gelir ("Ara"ya basmadan)
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(
          find.widgetWithText(TextField, 'Sokak, cadde ya da yer ara'), query);
      await settle(tester);
    }

    testWidgets('sonuç seçilince iğne oraya gider', (tester) async {
      await withoutFontErrors(() async {
        final geocoding = _FakeGeocoding(null, results);
        final h = _FormHarness(_devrekApi());
        await h.open(tester, geocoding: geocoding, confirmMap: false);

        await search(tester, 'atatürk');
        expect(geocoding.queries, ['atatürk']);
        expect(find.text('Atatürk Caddesi'), findsOneWidget);
        expect(find.text('Devrek Devlet Hastanesi'), findsOneWidget);

        await tester.tap(find.text('Atatürk Caddesi'));
        await settle(tester);
        expect(find.text('Devrek Devlet Hastanesi'), findsNothing);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);

        await _fillRequired(tester);
        await _tapSave(tester);
        final sent = h.api.lastCreateBody!['location'] as Map;
        expect(sent['lat'], closeTo(41.2301, 1e-6));
        expect(sent['lng'], closeTo(31.9512, 1e-6));
      });
    });

    testWidgets('sonuç yoksa ve hata olursa açıklama', (tester) async {
      await withoutFontErrors(() async {
        final geocoding = _FakeGeocoding();
        final h = _FormHarness(_devrekApi());
        await h.open(tester, geocoding: geocoding, confirmMap: false);

        await search(tester, 'xyz');
        expect(
            find.textContaining("Devrek'te sonuç bulamadık"), findsOneWidget);

        geocoding.searchFails = true;
        await search(tester, 'gül');
        expect(find.textContaining('Arama yapılamadı'), findsOneWidget);
        geocoding
          ..searchFails = false
          ..results = results;
        await tester.tap(find.text('Tekrar dene'));
        await settle(tester);
        expect(find.text('Atatürk Caddesi'), findsOneWidget);
        expect(geocoding.queries, ['xyz', 'gül', 'gül']);
      });
    });
  });

  group('Yurt', () {
    testWidgets('eski yurt adresinde yalnızca blok/oda alanı, harita yok',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi(addresses: [
          testAddress(
            zone: testZoneYurt,
            isDefault: true,
            fields: const AddressFields(),
          ),
        ]));
        await h.open(tester, initial: h.api.addresses.single);

        expect(_field('Blok / oda (isteğe bağlı)'), findsOneWidget);
        expect(find.textContaining('Sokak / cadde'), findsNothing);
        expect(_field('Mahalle'), findsNothing);
        expect(find.text('Teslimat konumu'), findsNothing);
      });
    });
  });

  group('Bölge seçimi', () {
    testWidgets('birden çok adres bölgesinde seçiciden seçilir',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi(
          zones: const [testZoneMahalle, testZoneDevrek, testZoneYurt],
        ));
        await h.open(tester, confirmMap: false);
        // Bölge belli değil: harita bölge seçilince açılır
        expect(find.text('İğneyi kapına getir'), findsNothing);
        expect(find.text('Bölgeni seç'), findsOneWidget);
        expect(_field('Sokak / cadde'), findsNothing);
        await _tapSave(tester);
        expect(find.text('Teslimat bölgeni seç'), findsWidgets);

        await tester.tap(find.text('Bölgeni seç'));
        await settle(tester);
        expect(find.text('İLÇE MERKEZİ'), findsOneWidget);
        expect(find.text('MAHALLELER'), findsOneWidget);
        // Yurtlar adres değil; ödemede teslimat noktası olarak seçilir
        expect(find.text('YURTLAR'), findsNothing);

        await tester.enterText(find.byType(TextField).last, 'xyz');
        await tester.pump();
        expect(find.text('Aramana uyan bölge yok'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'devr');
        await tester.pump();
        await tester.tap(find.text('Devrek'));
        await settle(tester);
        // Devrek konum ister: harita açılır
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);
        expect(_field('Mahalle'), findsOneWidget);
      });
    });

    testWidgets('kampanyada ücret üstü çizili ve kampanya notu görünür',
        (tester) async {
      await withoutFontErrors(() async {
        final api = FakeDeliveryApi(
          freeDeliveryEverywhere: true,
          zones: const [
            DeliveryZone(
              id: 'devrek',
              name: 'Devrek',
              type: DeliveryZoneType.ilce,
              deliveryFee: 40,
              isFree: true,
            ),
            DeliveryZone(
              id: 'cumhuriyet',
              name: 'Cumhuriyet Mahallesi',
              type: DeliveryZoneType.mahalle,
              deliveryFee: 30,
              isFree: true,
            ),
          ],
        );
        final h = _FormHarness(api);
        await h.open(tester, confirmMap: false);
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
        final address = _devrekAddress();
        final h = _FormHarness(_devrekApi(addresses: [address]));
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

    testWidgets('kapanmış eski mahalle adresi Devrek\'e taşınır',
        (tester) async {
      await withoutFontErrors(() async {
        final address = testAddress(
          zoneEnabled: false,
          fields: const AddressFields(
            street: 'Atatürk Cd.',
            buildingNo: '5',
            location: GeoPoint(41.22, 31.95),
          ),
        );
        final h = _FormHarness(_devrekApi(addresses: [address]));
        await h.open(tester, initial: address);
        expect(find.textContaining('Bu bölgeye şu an teslimat yok'),
            findsOneWidget);

        await tester.tap(find.text('Değiştir'));
        await settle(tester);
        await tester.tap(find.text('Devrek'));
        await settle(tester);
        // Konum zaten var: harita açılmaz, mahalle istenir
        expect(find.text('İğneyi kapına getir'), findsNothing);
        await _tapSave(tester, 'Değişiklikleri kaydet');
        expect(find.text('Mahalleni yaz'), findsOneWidget);

        await tester.enterText(_field('Mahalle'), 'Cumhuriyet');
        await _tapSave(tester, 'Değişiklikleri kaydet');
        expect(h.api.lastUpdateChanges,
            {'zoneId': 'devrek', 'neighborhood': 'Cumhuriyet'});
        expect(h.result?.zoneName, 'Devrek');
      });
    });

    testWidgets('varsayılan yapma PATCH ile ayrıca gönderilir', (tester) async {
      await withoutFontErrors(() async {
        final first = _devrekAddress(id: 'a1', isDefault: true);
        final second = _devrekAddress(id: 'a2', label: 'İş');
        final h = _FormHarness(_devrekApi(addresses: [first, second]));
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
        final h = _FormHarness(_devrekApi());
        await h.open(tester);

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
        final address = _devrekAddress(isDefault: true);
        final h = _FormHarness(_devrekApi(addresses: [address]));
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
        final api = _devrekApi()
          ..saveError = const ApiException(
            'En fazla 5 adres kaydedebilirsin.',
            statusCode: 400,
            code: 'ADDRESS_LIMIT',
          );
        final h = _FormHarness(api);
        await h.open(tester);
        await _fillRequired(tester);
        await _tapSave(tester);
        expect(find.text('En fazla 5 adres kaydedebilirsin.'), findsOneWidget);
        expect(h.popped, isFalse);
      });
    });

    testWidgets('5 adres doluyken yeni adres kaydedilemez', (tester) async {
      await withoutFontErrors(() async {
        final api = _devrekApi(addresses: [
          for (var i = 0; i < 5; i++) _devrekAddress(id: 'a$i'),
        ]);
        final h = _FormHarness(api);
        await h.open(tester);
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
        final h = _FormHarness(_devrekApi());
        await h.open(tester, location: location, confirmMap: false);
        expect(find.text('İğneyi kapına getir'), findsOneWidget);
        expect(find.textContaining('Yeşil çizgi teslimat alanımız'),
            findsOneWidget);
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
        final h = _FormHarness(_devrekApi());
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
        final h = _FormHarness(_devrekApi(withArea: false));
        await h.open(tester,
            location: _FakeLocation(LocationOutcome.denied), confirmMap: false);
        expect(find.textContaining('Konum izni verilmedi'), findsOneWidget);
        await tester.tap(find.text('Bu konumu kullan'));
        await settle(tester);

        await _fillRequired(tester);
        await _tapSave(tester);
        final sent = h.api.lastCreateBody!['location'] as Map;
        expect(sent['lat'], closeTo(AddressMap.devrekCenter.latitude, 1e-6));
        expect(sent['lng'], closeTo(AddressMap.devrekCenter.longitude, 1e-6));
      });
    });

    testWidgets('kalıcı redde "Ayarları aç" gösterilir', (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
        await h.open(tester,
            location: _FakeLocation(LocationOutcome.deniedForever),
            confirmMap: false);
        expect(find.text('Ayarları aç'), findsOneWidget);
      });
    });

    testWidgets('konum servisi kapalıysa "Konum ayarlarını aç" gösterilir',
        (tester) async {
      await withoutFontErrors(() async {
        final h = _FormHarness(_devrekApi());
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
        final h = _FormHarness(_devrekApi());
        // Ankara
        await h.open(tester,
            location: _PointLocation(const GeoPoint(39.92, 32.85)),
            confirmMap: false);
        expect(
            find.textContaining('Devrek dışında görünüyorsun'), findsOneWidget);
      });
    });
  });
}

/// Sabit bir noktayı konum olarak döner
class _PointLocation extends LocationService {
  final GeoPoint point;
  _PointLocation(this.point);

  @override
  Future<({LocationOutcome outcome, GeoPoint? point})> currentPoint() async =>
      (outcome: LocationOutcome.found, point: point);
}
