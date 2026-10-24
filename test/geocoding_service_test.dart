import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(PlaceInfo.fromNominatim({'error': 'Unable to geocode'}).isEmpty, isTrue);
  });

  test('köyde village alanı kullanılır', () {
    final place = PlaceInfo.fromNominatim({
      'address': {'village': 'Bostanlar', 'county': 'Devrek'},
    });
    expect(place.area, 'Bostanlar');
  });

  test('arama sonucu başlık ve alt satır üretir', () {
    final street = PlaceSearchResult.fromNominatim({
      'lat': '41.2201',
      'lon': '31.9560',
      'name': 'Atatürk Caddesi',
      'address': {
        'road': 'Atatürk Caddesi',
        'suburb': 'Cumhuriyet Mahallesi',
        'town': 'Devrek',
      },
    })!;
    expect(street.title, 'Atatürk Caddesi');
    expect(street.subtitle, 'Cumhuriyet Mahallesi · Devrek');
    expect(street.point, const GeoPoint(41.2201, 31.956));

    final poi = PlaceSearchResult.fromNominatim({
      'lat': '41.22',
      'lon': '31.95',
      'name': 'Devrek Devlet Hastanesi',
      'address': {'road': 'Hastane Sokak', 'house_number': '3'},
    })!;
    expect(poi.title, 'Devrek Devlet Hastanesi');
    expect(poi.subtitle, 'Hastane Sokak No:3');

    expect(PlaceSearchResult.fromNominatim({'name': 'Koordinatsız'}), isNull);
  });

  test('teslimat alanı GeoJSON okunur, nokta içinde/dışında bulunur', () {
    final area = DeliveryArea.fromGeoJson({
      'type': 'MultiPolygon',
      'coordinates': [
        [
          [[31.0, 41.0], [32.0, 41.0], [32.0, 42.0], [31.0, 42.0], [31.0, 41.0]],
          // delik
          [[31.4, 41.4], [31.6, 41.4], [31.6, 41.6], [31.4, 41.6], [31.4, 41.4]],
        ],
        [
          [[33.0, 41.0], [33.5, 41.0], [33.5, 41.5], [33.0, 41.0]],
        ],
      ],
    })!;
    expect(area.contains(const GeoPoint(41.2, 31.2)), isTrue);
    expect(area.contains(const GeoPoint(41.5, 31.5)), isFalse, reason: 'delikte');
    expect(area.contains(const GeoPoint(41.1, 33.4)), isTrue);
    expect(area.contains(const GeoPoint(40.0, 31.5)), isFalse);
    final (sw, ne) = area.bounds;
    expect(sw, const GeoPoint(41.0, 31.0));
    expect(ne, const GeoPoint(42.0, 33.5));

    expect(DeliveryArea.fromGeoJson(null), isNull);
    expect(DeliveryArea.fromGeoJson({'type': 'Point', 'coordinates': [1, 2]}), isNull);
    expect(
      DeliveryArea.fromGeoJson({
        'type': 'Polygon',
        'coordinates': [[[1, 2], [3, 4]]],
      }),
      isNull,
      reason: 'halka en az 4 nokta',
    );
  });
}
