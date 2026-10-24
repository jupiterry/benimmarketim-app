import 'package:dio/dio.dart';

import '../models/delivery.dart';
import 'app_logger.dart';

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
}

/// Haritada adres aramasının bir sonucu.
class PlaceSearchResult {
  final GeoPoint point;

  /// "Atatürk Caddesi" ya da yer adı ("Devrek Devlet Hastanesi")
  final String title;

  /// "Cumhuriyet Mahallesi · Devrek"
  final String subtitle;

  const PlaceSearchResult({
    required this.point,
    required this.title,
    this.subtitle = '',
  });

  static PlaceSearchResult? fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lng = double.tryParse('${json['lon']}');
    if (lat == null || lng == null) return null;
    final place = PlaceInfo.fromNominatim(json);
    final name = '${json['name'] ?? ''}'.trim();
    final road = [
      place.road,
      if (place.houseNumber.isNotEmpty) 'No:${place.houseNumber}',
    ].where((s) => s.isNotEmpty).join(' ');
    final title =
        name.isNotEmpty ? name : (road.isNotEmpty ? road : place.area);
    if (title.isEmpty) return null;
    final subtitle = [
      if (road.isNotEmpty && road != title) road,
      if (place.area != title) place.area,
      place.town,
    ].where((s) => s.isNotEmpty).join(' · ');
    return PlaceSearchResult(
      point: GeoPoint(lat, lng),
      title: title,
      subtitle: subtitle,
    );
  }
}

/// Konumdan adres bulma (ters geocoding) ve adres arama. OSM Nominatim
/// kullanılır; kural gereği istekler saniyede en fazla bir tanedir, arama
/// yazarken değil yalnızca "Ara"ya basınca yapılır ve uygulama kendini
/// User-Agent ile tanıtır. Hata olursa ters geocoding null döner; adres
/// akışı elle girilen bilgiyle devam eder.
class GeocodingService {
  GeocodingService({Dio? dio}) : _dio = dio ?? _createDio();

  /// Ekran görüntüsü / test düzeneği: istekler ağa gitmez.
  static HttpClientAdapter? debugHttpAdapter;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'BenimMarketim/7.1 (https://devrekbenimmarketim.com)',
        'Accept-Language': 'tr',
      },
    ));
    final adapter = debugHttpAdapter;
    if (adapter != null) dio.httpClientAdapter = adapter;
    return dio;
  }

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

  /// Devrek içinde adres/yer arar (en fazla [limit] sonuç). Bağlantı hatası
  /// [GeocodingException] fırlatır; sonuç yoksa boş liste döner.
  Future<List<PlaceSearchResult>> search(
    String query, {
    required GeoPoint southWest,
    required GeoPoint northEast,
    int limit = 8,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': text,
        'format': 'jsonv2',
        'addressdetails': 1,
        'limit': limit,
        'countrycodes': 'tr',
        // viewbox: sol,üst,sağ,alt; bounded=1 yalnızca bu kutudaki sonuçlar
        'viewbox':
            '${southWest.lng},${northEast.lat},${northEast.lng},${southWest.lat}',
        'bounded': 1,
      });
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) =>
              PlaceSearchResult.fromNominatim(Map<String, dynamic>.from(e)))
          .whereType<PlaceSearchResult>()
          .toList();
    } catch (e) {
      AppLogger.debug('Adres araması yapılamadı: $e');
      throw const GeocodingException();
    }
  }
}

/// Adres araması yapılamadı (bağlantı ya da servis hatası).
class GeocodingException implements Exception {
  const GeocodingException();
}
