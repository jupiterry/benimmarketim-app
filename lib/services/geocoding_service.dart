import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/delivery.dart';
import 'app_logger.dart';
import 'maps_config.dart';

/// Haritadaki bir noktanın adres bilgisi (Google ya da OpenStreetMap).
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

  /// Google `address_components` (Geocoding API: long_name/types; Places API
  /// (New): longText/types). Türkiye'de mahalle çoğunlukla
  /// administrative_area_level_4'tür.
  factory PlaceInfo.fromGoogleComponents(Object? components) {
    if (components is! List) return const PlaceInfo();
    String pick(List<String> types) {
      for (final type in types) {
        for (final c in components) {
          if (c is! Map) continue;
          final kinds = c['types'];
          if (kinds is! List || !kinds.contains(type)) continue;
          final value = c['long_name'] ?? c['longText'];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
      return '';
    }

    return PlaceInfo(
      area: pick([
        'administrative_area_level_4',
        'neighborhood',
        'sublocality_level_1',
        'sublocality',
      ]),
      road: pick(['route']),
      houseNumber: pick(['street_number']),
      town: pick(['administrative_area_level_2', 'locality']),
    );
  }
}

/// Haritada adres aramasının bir sonucu. Google önerisinde konum yoktur
/// ([placeId] ile [GeocodingService.resolve] sorar).
class PlaceSearchResult {
  final GeoPoint? point;
  final String? placeId;

  /// "Atatürk Caddesi" ya da yer adı ("Devrek Devlet Hastanesi")
  final String title;

  /// "Cumhuriyet Mahallesi · Devrek"
  final String subtitle;

  const PlaceSearchResult({
    this.point,
    this.placeId,
    required this.title,
    this.subtitle = '',
  });

  /// Places API (New) autocomplete önerisi (`suggestions[].placePrediction`)
  static PlaceSearchResult? fromGooglePrediction(Object? json) {
    if (json is! Map) return null;
    final id = json['placeId'];
    if (id is! String || id.isEmpty) return null;
    String text(Object? node) => node is Map && node['text'] is String
        ? (node['text'] as String).trim()
        : '';
    final format = json['structuredFormat'];
    var title = format is Map ? text(format['mainText']) : '';
    var subtitle = format is Map ? text(format['secondaryText']) : '';
    if (title.isEmpty) title = text(json['text']);
    if (title.isEmpty) return null;
    // "Cumhuriyet, Devrek/Zonguldak, Türkiye" → ülke gereksiz
    subtitle = subtitle.replaceAll(RegExp(r',\s*Türkiye$'), '');
    return PlaceSearchResult(placeId: id, title: title, subtitle: subtitle);
  }

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

  /// Uygulamanın servisi: Google anahtarı varsa Google, yoksa Nominatim.
  factory GeocodingService.forApp() =>
      MapsConfig.useGoogle ? GoogleGeocodingService() : GeocodingService();

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

  /// Yazarken öneri getirilebilir mi? Nominatim'de hayır (kural gereği
  /// yalnızca "Ara"ya basınca), Google'da evet.
  bool get autocomplete => false;

  /// Noktanın adresi (önbellekli). Bulunamazsa ya da hata olursa null.
  Future<PlaceInfo?> reverse(GeoPoint point) async {
    final key = _key(point);
    if (_cache.containsKey(key)) return _cache[key];
    final result = await lookup(point);
    _cache[key] = result;
    return result;
  }

  /// Önbelleğe yazar (ör. arama sonucunun adresi biliniyorsa).
  @protected
  void remember(GeoPoint point, PlaceInfo? place) =>
      _cache[_key(point)] = place;

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

  /// Arama sonucunun konumu (Google önerisinde ayrıca sorulur). Bulunamazsa
  /// null.
  Future<GeoPoint?> resolve(PlaceSearchResult result) async => result.point;

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

/// Google ile adres: arama Places API (New) Autocomplete + Place Details,
/// konumdan adres Geocoding API. Yazarken öneri gelir; öneriler ve seçilen
/// yerin ayrıntısı aynı oturum anahtarıyla (session token) sorulur, Google
/// bunu tek arama olarak ücretlendirir. Hata olursa arama
/// [GeocodingException] fırlatır, konumdan adres null döner.
class GoogleGeocodingService extends GeocodingService {
  GoogleGeocodingService({Dio? dio, String? apiKey})
      : _apiKey = apiKey ?? MapsConfig.apiKey,
        _google = dio ?? _createGoogleDio();

  final String _apiKey;
  final Dio _google;
  String? _session;

  static Dio _createGoogleDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    final adapter = GeocodingService.debugHttpAdapter;
    if (adapter != null) dio.httpClientAdapter = adapter;
    return dio;
  }

  static const _places = 'https://places.googleapis.com/v1';
  static const _geocode = 'https://maps.googleapis.com/maps/api/geocode/json';

  @override
  bool get autocomplete => true;

  /// Arama oturumu: öneriler ve sonunda seçilen yerin ayrıntısı. UUID v4.
  String get _sessionToken => _session ??= _uuid();

  static String _uuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Options _placesOptions({String? fieldMask}) => Options(headers: {
        'X-Goog-Api-Key': _apiKey,
        if (fieldMask != null) 'X-Goog-FieldMask': fieldMask,
      });

  @override
  Future<PlaceInfo?> lookup(GeoPoint point) async {
    try {
      final response = await _google.get(_geocode, queryParameters: {
        'latlng': '${point.lat},${point.lng}',
        'language': 'tr',
        'key': _apiKey,
      });
      final data = response.data;
      if (data is! Map || data['status'] != 'OK') {
        if (data is Map && data['status'] != 'ZERO_RESULTS') {
          AppLogger.debug(
              'Google adres: ${data['status']} ${data['error_message'] ?? ''}');
        }
        return null;
      }
      final results = data['results'];
      if (results is! List) return null;
      // İlk sonuç en ayrıntılısıdır; mahalle eksikse sonrakilerden tamamlanır
      PlaceInfo? best;
      for (final r in results) {
        if (r is! Map) continue;
        final place = PlaceInfo.fromGoogleComponents(r['address_components']);
        if (best == null) {
          best = place;
        } else if (best.area.isEmpty && place.area.isNotEmpty) {
          best = PlaceInfo(
            area: place.area,
            road: best.road,
            houseNumber: best.houseNumber,
            town: best.town.isNotEmpty ? best.town : place.town,
          );
        }
        if (best.area.isNotEmpty) break;
      }
      return best == null || best.isEmpty ? null : best;
    } catch (e) {
      AppLogger.debug('Google adres bulunamadı: $e');
      return null;
    }
  }

  @override
  Future<List<PlaceSearchResult>> search(
    String query, {
    required GeoPoint southWest,
    required GeoPoint northEast,
    int limit = 8,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final response = await _google.post(
        '$_places/places:autocomplete',
        options: _placesOptions(),
        data: {
          'input': text,
          'languageCode': 'tr',
          'regionCode': 'tr',
          'includedRegionCodes': ['tr'],
          'locationRestriction': {
            'rectangle': {
              'low': {'latitude': southWest.lat, 'longitude': southWest.lng},
              'high': {'latitude': northEast.lat, 'longitude': northEast.lng},
            },
          },
          'sessionToken': _sessionToken,
        },
      );
      final data = response.data;
      final suggestions = data is Map ? data['suggestions'] : null;
      if (suggestions is! List) return const [];
      return suggestions
          .whereType<Map>()
          .map((s) =>
              PlaceSearchResult.fromGooglePrediction(s['placePrediction']))
          .whereType<PlaceSearchResult>()
          .take(limit)
          .toList();
    } catch (e) {
      AppLogger.debug('Google adres araması yapılamadı: $e');
      throw const GeocodingException();
    }
  }

  @override
  Future<GeoPoint?> resolve(PlaceSearchResult result) async {
    if (result.point != null) return result.point;
    final id = result.placeId;
    if (id == null) return null;
    try {
      final response = await _google.get(
        '$_places/places/${Uri.encodeComponent(id)}',
        queryParameters: {
          'languageCode': 'tr',
          'regionCode': 'tr',
          'sessionToken': _sessionToken,
        },
        options: _placesOptions(fieldMask: 'location,addressComponents'),
      );
      final data = response.data;
      if (data is! Map) return null;
      final location = data['location'];
      if (location is! Map) return null;
      final lat = location['latitude'];
      final lng = location['longitude'];
      if (lat is! num || lng is! num) return null;
      final point = GeoPoint(lat.toDouble(), lng.toDouble());
      final place = PlaceInfo.fromGoogleComponents(data['addressComponents']);
      if (!place.isEmpty) remember(point, place);
      return point;
    } catch (e) {
      AppLogger.debug('Google yer ayrıntısı alınamadı: $e');
      return null;
    } finally {
      // Oturum seçimle biter; sonraki arama yeni oturumdur
      _session = null;
    }
  }
}
