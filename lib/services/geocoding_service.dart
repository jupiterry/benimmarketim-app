import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show protected;

import '../models/delivery.dart';
import 'app_logger.dart';

/// Haritadaki bir noktanın adres bilgisi (OpenStreetMap verisi).
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

  /// Photon (komoot) GeoJSON özelliği: `geometry.coordinates` [boylam,
  /// enlem], `properties`: name, street, housenumber, district/locality
  /// (mahalle), city/county.
  static PlaceSearchResult? fromPhoton(Object? json) {
    if (json is! Map) return null;
    final geometry = json['geometry'];
    final coords = geometry is Map ? geometry['coordinates'] : null;
    if (coords is! List || coords.length < 2) return null;
    final lng = coords[0];
    final lat = coords[1];
    if (lat is! num || lng is! num) return null;
    final props = json['properties'];
    if (props is! Map) return null;
    String prop(String key) {
      final v = props[key];
      return v is String ? v.trim() : '';
    }

    final name = prop('name');
    final street = [
      prop('street'),
      if (prop('housenumber').isNotEmpty) 'No:${prop('housenumber')}',
    ].where((s) => s.isNotEmpty).join(' ');
    final area =
        prop('district').isNotEmpty ? prop('district') : prop('locality');
    final town = prop('city').isNotEmpty ? prop('city') : prop('county');
    final title = name.isNotEmpty ? name : (street.isNotEmpty ? street : area);
    if (title.isEmpty) return null;
    final subtitle = [
      if (street.isNotEmpty && street != title) street,
      if (area.isNotEmpty && area != title) area,
      if (town.isNotEmpty && town != title) town,
    ].join(' · ');
    return PlaceSearchResult(
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      title: title,
      subtitle: subtitle,
    );
  }
}

/// Konumdan adres bulma ve adres arama; ikisi de OpenStreetMap verisiyle,
/// anahtarsız. Konumdan adres: Nominatim (istek saniyede en fazla bir;
/// iğne durunca sorulur). Arama: Photon (komoot), yazarken öneri verir.
/// Hata olursa konumdan adres null döner, arama [GeocodingException]
/// fırlatır; adres akışı elle girilen bilgiyle devam eder.
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

  static const _photon = 'https://photon.komoot.io/api/';

  /// Aynı noktaya ikinci kez sorulmaz (harita → form geçişinde).
  final Map<String, PlaceInfo?> _cache = {};

  static String _key(GeoPoint p) =>
      '${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}';

  /// Yazarken öneri getirilebilir mi? Photon'da evet.
  bool get autocomplete => true;

  /// Noktanın adresi (önbellekli). Bulunamazsa ya da hata olursa null.
  Future<PlaceInfo?> reverse(GeoPoint point) async {
    final key = _key(point);
    if (_cache.containsKey(key)) return _cache[key];
    final result = await lookup(point);
    _cache[key] = result;
    return result;
  }

  /// Sağlayıcıya sorar; hata fırlatmaz.
  @protected
  Future<PlaceInfo?> lookup(GeoPoint point) async {
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
      final response = await _dio.get(_photon, queryParameters: {
        'q': text,
        'limit': limit,
        'lang': 'default',
        // bbox: minLon,minLat,maxLon,maxLat
        'bbox':
            '${southWest.lng},${southWest.lat},${northEast.lng},${northEast.lat}',
        // Devrek merkezine yakın sonuçlar önce
        'lat': (southWest.lat + northEast.lat) / 2,
        'lon': (southWest.lng + northEast.lng) / 2,
      });
      final data = response.data;
      final features = data is Map ? data['features'] : null;
      if (features is! List) return const [];
      return features
          .map(PlaceSearchResult.fromPhoton)
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
