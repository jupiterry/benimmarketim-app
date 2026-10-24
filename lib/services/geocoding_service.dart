import 'package:dio/dio.dart';

import '../models/delivery.dart';
import 'app_logger.dart';
import 'turkish_text.dart';

/// Haritadaki bir noktanın adres bilgisi (OpenStreetMap / Nominatim).
class PlaceInfo {
  /// Mahalle ya da köy adı ("Cumhuriyet Mahallesi", "Bostanlar")
  final String area;
  final String road;
  final String houseNumber;
  final String town;

  const PlaceInfo({
    this.area = '',
    this.road = '',
    this.houseNumber = '',
    this.town = '',
  });

  bool get isEmpty => area.isEmpty && road.isEmpty;

  /// "Cumhuriyet Mahallesi · Atatürk Caddesi No:5"
  String get summary => [
        area,
        [
          road,
          if (houseNumber.isNotEmpty) 'No:$houseNumber',
        ].where((s) => s.isNotEmpty).join(' '),
      ].where((s) => s.isNotEmpty).join(' · ');

  /// Nominatim `address` nesnesinden. Mahalle için sırayla neighbourhood,
  /// quarter, suburb, village, hamlet denenir.
  factory PlaceInfo.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! Map) return const PlaceInfo();
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    return PlaceInfo(
      area: pick(['neighbourhood', 'quarter', 'suburb', 'village', 'hamlet']),
      road: pick(['road', 'pedestrian', 'residential', 'footway']),
      houseNumber: pick(['house_number']),
      town: pick(['town', 'city', 'county']),
    );
  }

  /// Mahalle/köy adını listedeki bölgelerle eşler. "Cumhuriyet Mahallesi",
  /// "Cumhuriyet Mah." ve "Cumhuriyet" aynı bölgeyi bulur; Türkçe karakter
  /// ve büyük/küçük harf farkı önemsenmez.
  DeliveryZone? matchZone(Iterable<DeliveryZone> zones) {
    final key = _zoneKey(area);
    if (key.isEmpty) return null;
    for (final zone in zones) {
      if (zone.isDorm) continue;
      if (_zoneKey(zone.name) == key) return zone;
    }
    return null;
  }

  static final _suffix = RegExp(
    r'\s+(mahallesi|mahalle|mah\.?|koyu|koy|köyü|köy)\.?$',
  );

  static String _zoneKey(String name) {
    var key = TurkishText.normalize(name.trim());
    key = key.replaceAll(_suffix, '');
    return key.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

/// Konumdan adres bulma (ters geocoding). OSM Nominatim kullanılır; kural
/// gereği istekler saniyede en fazla bir tanedir ve uygulama kendini
/// User-Agent ile tanıtır. Hata olursa null döner; adres akışı konumsuz
/// bilgiyle devam eder.
class GeocodingService {
  GeocodingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'User-Agent':
                    'BenimMarketim/7.1 (https://devrekbenimmarketim.com)',
                'Accept-Language': 'tr',
              },
            ));

  final Dio _dio;

  /// Aynı noktaya ikinci kez sorulmaz (harita → form geçişinde).
  final Map<String, PlaceInfo?> _cache = {};

  static String _key(GeoPoint p) =>
      '${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}';

  Future<PlaceInfo?> reverse(GeoPoint point) async {
    final key = _key(point);
    if (_cache.containsKey(key)) return _cache[key];
    PlaceInfo? result;
    try {
      final response = await _dio.get('/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': point.lat,
        'lon': point.lng,
        'zoom': 18,
        'addressdetails': 1,
      });
      final data = response.data;
      if (data is Map) {
        result = PlaceInfo.fromNominatim(Map<String, dynamic>.from(data));
        if (result.isEmpty) result = null;
      }
    } catch (e) {
      AppLogger.debug('Adres bulunamadı: $e');
    }
    _cache[key] = result;
    return result;
  }
}
