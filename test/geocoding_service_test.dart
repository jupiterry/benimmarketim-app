import 'dart:convert';

import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/geocoding_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ağa gitmeden JSON döner
class _Adapter implements HttpClientAdapter {
  final Object? Function(RequestOptions options) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode(handler(options)), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Nominatim yanıtından mahalle, sokak ve bina no okunur', () {
    final place = PlaceInfo.fromNominatim({
      'address': {
        'house_number': '5',
        'road': 'Atatürk Caddesi',
        'neighbourhood': 'Cumhuriyet Mahallesi',
        'town': 'Devrek',
      },
    });
    expect(place.area, 'Cumhuriyet Mahallesi');
    expect(place.road, 'Atatürk Caddesi');
    expect(place.houseNumber, '5');
    expect(place.summary, 'Cumhuriyet Mahallesi · Atatürk Caddesi No:5');
    expect(PlaceInfo.fromNominatim({'error': 'Unable to geocode'}).isEmpty,
        isTrue);
  });

  test('köyde village alanı kullanılır', () {
    final place = PlaceInfo.fromNominatim({
      'address': {'village': 'Bostanlar', 'county': 'Devrek'},
    });
    expect(place.area, 'Bostanlar');
  });

  test('Photon arama sonucu başlık ve alt satır üretir', () {
    final street = PlaceSearchResult.fromPhoton({
      'geometry': {
        'coordinates': [31.9560, 41.2201]
      },
      'properties': {
        'name': 'Atatürk Caddesi',
        'street': 'Atatürk Caddesi',
        'district': 'Cumhuriyet Mahallesi',
        'city': 'Devrek',
      },
    })!;
    expect(street.title, 'Atatürk Caddesi');
    expect(street.subtitle, 'Cumhuriyet Mahallesi · Devrek');
    expect(street.point, const GeoPoint(41.2201, 31.956));

    final poi = PlaceSearchResult.fromPhoton({
      'geometry': {
        'coordinates': [31.95, 41.22]
      },
      'properties': {
        'name': 'Devrek Devlet Hastanesi',
        'street': 'Hastane Sokak',
        'housenumber': '3',
        'county': 'Devrek',
      },
    })!;
    expect(poi.title, 'Devrek Devlet Hastanesi');
    expect(poi.subtitle, 'Hastane Sokak No:3 · Devrek');

    // Adı olmayan sokak: sokak başlık olur
    final road = PlaceSearchResult.fromPhoton({
      'geometry': {
        'coordinates': [31.95, 41.22]
      },
      'properties': {'street': 'Gül Sokak', 'locality': 'Özbağ'},
    })!;
    expect(road.title, 'Gül Sokak');
    expect(road.subtitle, 'Özbağ');

    expect(
        PlaceSearchResult.fromPhoton({
          'properties': {'name': 'Koordinatsız'}
        }),
        isNull);
  });

  test('arama Photon\'a Devrek kutusuyla gider', () async {
    RequestOptions? sent;
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) {
        sent = options;
        return {
          'features': [
            {
              'geometry': {
                'coordinates': [31.95, 41.22]
              },
              'properties': {'name': 'Atatürk Caddesi'},
            },
          ],
        };
      });
    final results = await GeocodingService(dio: dio).search(
      'atatürk',
      southWest: const GeoPoint(41.03, 31.72),
      northEast: const GeoPoint(41.40, 32.18),
    );
    expect(results.single.title, 'Atatürk Caddesi');
    final uri = sent!.uri;
    expect(uri.host, 'photon.komoot.io');
    expect(uri.path, '/api/');
    expect(uri.queryParameters['q'], 'atatürk');
    expect(uri.queryParameters['bbox'], '31.72,41.03,32.18,41.4');
    expect(GeocodingService(dio: dio).autocomplete, isTrue);
  });

  test('arama hatası GeocodingException fırlatır, konumdan adres null döner',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter((_) => throw StateError('ağ yok'));
    final service = GeocodingService(dio: dio);
    await expectLater(
      service.search('x',
          southWest: const GeoPoint(41, 31), northEast: const GeoPoint(42, 32)),
      throwsA(isA<GeocodingException>()),
    );
    expect(await service.reverse(const GeoPoint(41.2, 31.9)), isNull);
  });

  test('teslimat alanı GeoJSON okunur, nokta içinde/dışında bulunur', () {
    final area = DeliveryArea.fromGeoJson({
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [
            [31.0, 41.0],
            [32.0, 41.0],
            [32.0, 42.0],
            [31.0, 42.0],
            [31.0, 41.0]
          ],
          // delik
          [
            [31.4, 41.4],
            [31.6, 41.4],
            [31.6, 41.6],
            [31.4, 41.6],
            [31.4, 41.4]
          ],
        ],
        [
          [
            [33.0, 41.0],
            [33.5, 41.0],
            [33.5, 41.5],
            [33.0, 41.0]
          ],
        ],
      ],
    })!;
    expect(area.contains(const GeoPoint(41.2, 31.2)), isTrue);
    expect(area.contains(const GeoPoint(41.5, 31.5)), isFalse,
        reason: 'delikte');
    expect(area.contains(const GeoPoint(41.1, 33.4)), isTrue);
    expect(area.contains(const GeoPoint(40.0, 31.5)), isFalse);
    final (sw, ne) = area.bounds;
    expect(sw, const GeoPoint(41.0, 31.0));
    expect(ne, const GeoPoint(42.0, 33.5));

    expect(DeliveryArea.fromGeoJson(null), isNull);
    expect(
        DeliveryArea.fromGeoJson({
          'type': 'Point',
          'coordinates': [1, 2]
        }),
        isNull);
    expect(
      DeliveryArea.fromGeoJson({
        'type': 'Polygon',
        'coordinates': [
          [
            [1, 2],
            [3, 4]
          ]
        ],
      }),
      isNull,
      reason: 'halka en az 4 nokta',
    );
  });
}
