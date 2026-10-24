// Google Maps yolu: Places API (New) arama + ayrıntı, Geocoding API ile
// konumdan adres ve anahtar varken haritada yazarken öneri.

import 'dart:convert';

import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/geocoding_service.dart';
import 'package:benimmarketim_app/services/maps_config.dart';
import 'package:benimmarketim_app/views/widgets/address_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_utils.dart';

/// Google uç noktalarına giden istekleri kaydeder, sabit yanıt döner.
class _GoogleAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object? autocomplete = {
    'suggestions': [
      {
        'placePrediction': {
          'placeId': 'p1',
          'text': {'text': 'Atatürk Caddesi, Devrek/Zonguldak, Türkiye'},
          'structuredFormat': {
            'mainText': {'text': 'Atatürk Caddesi'},
            'secondaryText': {'text': 'Devrek/Zonguldak, Türkiye'},
          },
        },
      },
      {
        'queryPrediction': {
          'text': {'text': 'atatürk'}
        }
      },
    ],
  };
  Object? details = {
    'location': {'latitude': 41.2231, 'longitude': 31.958},
    'addressComponents': [
      {
        'longText': '12',
        'types': ['street_number']
      },
      {
        'longText': 'Atatürk Caddesi',
        'types': ['route']
      },
      {
        'longText': 'Cumhuriyet',
        'types': ['administrative_area_level_4', 'political']
      },
      {
        'longText': 'Devrek',
        'types': ['administrative_area_level_2', 'political']
      },
    ],
  };
  Object? geocode = {
    'status': 'OK',
    'results': [
      {
        'address_components': [
          {
            'long_name': '5',
            'types': ['street_number']
          },
          {
            'long_name': 'Gül Sokak',
            'types': ['route']
          },
          {
            'long_name': 'Devrek',
            'types': ['administrative_area_level_2']
          },
        ],
      },
      {
        'address_components': [
          {
            'long_name': 'Özbağ',
            'types': ['administrative_area_level_4']
          },
        ],
      },
    ],
  };
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final path = options.uri.path;
    final body = path.endsWith('places:autocomplete')
        ? autocomplete
        : path.contains('/v1/places/')
            ? details
            : geocode;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

GoogleGeocodingService _service(_GoogleAdapter adapter) =>
    GoogleGeocodingService(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: 'test-key',
    );

const _sw = GeoPoint(41.03, 31.72);
const _ne = GeoPoint(41.40, 32.18);

void main() {
  tearDown(() => MapsConfig.debugApiKey = null);

  group('GoogleGeocodingService', () {
    test('arama: Devrek kutusuyla sınırlı öneri, oturum anahtarlı', () async {
      final adapter = _GoogleAdapter();
      final results = await _service(adapter)
          .search('atatürk', southWest: _sw, northEast: _ne);

      expect(results, hasLength(1));
      expect(results.single.placeId, 'p1');
      expect(results.single.point, isNull);
      expect(results.single.title, 'Atatürk Caddesi');
      expect(results.single.subtitle, 'Devrek/Zonguldak');

      final request = adapter.requests.single;
      expect(request.uri.toString(),
          'https://places.googleapis.com/v1/places:autocomplete');
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      final body = request.data as Map;
      expect(body['input'], 'atatürk');
      expect(body['includedRegionCodes'], ['tr']);
      expect(body['locationRestriction']['rectangle']['low'],
          {'latitude': 41.03, 'longitude': 31.72});
      expect(body['sessionToken'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('seçilen yerin konumu aynı oturumla sorulur, adresi önbelleğe girer',
        () async {
      final adapter = _GoogleAdapter();
      final service = _service(adapter);
      final result =
          (await service.search('atatürk', southWest: _sw, northEast: _ne))
              .single;
      final session = (adapter.requests.first.data as Map)['sessionToken'];

      final point = await service.resolve(result);
      expect(point, const GeoPoint(41.2231, 31.958));
      final details = adapter.requests[1];
      expect(details.uri.path, '/v1/places/p1');
      expect(details.uri.queryParameters['sessionToken'], session);
      expect(details.headers['X-Goog-FieldMask'], 'location,addressComponents');

      // Adres ayrıntıdan geldi: ayrıca Geocoding'e sorulmaz
      final place = await service.reverse(point!);
      expect(place?.area, 'Cumhuriyet');
      expect(place?.road, 'Atatürk Caddesi');
      expect(place?.houseNumber, '12');
      expect(adapter.requests, hasLength(2));

      // Oturum seçimle biter
      await service.search('gül', southWest: _sw, northEast: _ne);
      expect(
          (adapter.requests.last.data as Map)['sessionToken'], isNot(session));
    });

    test('konumdan adres: mahalle eksikse sonraki sonuçtan tamamlanır',
        () async {
      final adapter = _GoogleAdapter();
      final place =
          await _service(adapter).reverse(const GeoPoint(41.22, 31.95));
      expect(place?.road, 'Gül Sokak');
      expect(place?.houseNumber, '5');
      expect(place?.area, 'Özbağ');
      expect(place?.town, 'Devrek');
      final uri = adapter.requests.single.uri;
      expect(uri.path, '/maps/api/geocode/json');
      expect(uri.queryParameters['latlng'], '41.22,31.95');
      expect(uri.queryParameters['language'], 'tr');
      expect(uri.queryParameters['key'], 'test-key');
    });

    test('Google hata verirse: adres null, arama GeocodingException', () async {
      final adapter = _GoogleAdapter()
        ..geocode = {'status': 'REQUEST_DENIED', 'results': []}
        ..status = 403
        ..autocomplete = {
          'error': {'code': 403}
        };
      final service = _service(adapter);
      expect(await service.reverse(const GeoPoint(41.22, 31.95)), isNull);
      await expectLater(
        service.search('atatürk', southWest: _sw, northEast: _ne),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('anahtar varsa uygulama Google servisini kullanır', () {
      expect(GeocodingService.forApp(), isNot(isA<GoogleGeocodingService>()));
      MapsConfig.debugApiKey = 'test-key';
      expect(MapsConfig.useGoogle, isTrue);
      expect(GeocodingService.forApp(), isA<GoogleGeocodingService>());
    });
  });

  group('Google haritasında arama', () {
    configureMarketTests();
    setUpAll(() => AddressMap.debugShowTiles = false);

    testWidgets('yazarken öneri gelir, seçilince konumu sorulur',
        (tester) async {
      await withoutFontErrors(() async {
        MapsConfig.debugApiKey = 'test-key';
        final adapter = _GoogleAdapter();
        GeoPoint? picked;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => picked = await showAddressMapPicker(
                  context,
                  initial: const GeoPoint(41.2194, 31.9558),
                  geocoding: _service(adapter),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        // İki harf: istek yok
        final field =
            find.widgetWithText(TextField, 'Sokak, cadde ya da yer ara');
        await tester.enterText(field, 'at');
        await tester.pump(const Duration(milliseconds: 500));
        expect(
            adapter.requests.where((r) => r.uri.path.contains('autocomplete')),
            isEmpty);

        // Üç harf: "Ara"ya basmadan öneri gelir
        await tester.enterText(field, 'ata');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Atatürk Caddesi'), findsOneWidget);
        expect(find.text('Devrek/Zonguldak'), findsOneWidget);

        await tester.tap(find.text('Atatürk Caddesi'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text('Atatürk Caddesi'), findsNothing);
        // OSM kaynak yazısı Google haritasında yok
        expect(find.text('© OpenStreetMap katkıcıları'), findsNothing);

        await tester.tap(find.text('Bu konumu kullan'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(picked, const GeoPoint(41.2231, 31.958));
      });
    });
  });
}
