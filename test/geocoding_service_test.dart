import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _zones = [
  DeliveryZone(id: 'cumhuriyet', name: 'Cumhuriyet Mahallesi', type: DeliveryZoneType.mahalle),
  DeliveryZone(id: 'ozbag', name: 'Özbağ Mah.', type: DeliveryZoneType.mahalle),
  DeliveryZone(id: 'bostanlar', name: 'Bostanlar Köyü', type: DeliveryZoneType.koy),
  DeliveryZone(id: 'girlsDorm', name: 'Cumhuriyet', type: DeliveryZoneType.yurt),
];

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
    expect(place.matchZone(_zones)?.id, 'bostanlar');
  });

  test('mahalle adı ek ve Türkçe karakterden bağımsız eşleşir', () {
    expect(const PlaceInfo(area: 'Cumhuriyet Mahallesi').matchZone(_zones)?.id, 'cumhuriyet');
    expect(const PlaceInfo(area: 'CUMHURİYET MAH.').matchZone(_zones)?.id, 'cumhuriyet');
    expect(const PlaceInfo(area: 'Ozbag Mahallesi').matchZone(_zones)?.id, 'ozbag');
    expect(const PlaceInfo(area: 'Yeşilyurt').matchZone(_zones), isNull);
    expect(const PlaceInfo().matchZone(_zones), isNull);
  });

  test('yurtlar hiçbir zaman eşleşmez', () {
    final onlyDorm = [_zones.last];
    expect(const PlaceInfo(area: 'Cumhuriyet').matchZone(onlyDorm), isNull);
  });
}
