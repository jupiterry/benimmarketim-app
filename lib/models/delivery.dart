/// Adrese teslimat modelleri. Sunucu sözleşmesi: GET /delivery/me,
/// GET /delivery/zones, GET /delivery/zones/:id/area, /addresses,
/// POST /delivery/quote.
library;

double _toDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

String _toStr(Object? value) => value == null ? '' : value.toString();

/// Bölge tipi. Sunucuda üç sabit bölge vardır: iki yurt ve Devrek (ilçe
/// merkezi, haritadaki sınırıyla). Mahalle ve köy eski sürümden kalan
/// (kapatılmış) bölgelerdir; kayıtlı eski adreslerde görünebilir.
enum DeliveryZoneType {
  yurt,
  ilce,
  mahalle,
  koy;

  static DeliveryZoneType parse(Object? value) {
    switch (value) {
      case 'yurt':
        return DeliveryZoneType.yurt;
      case 'ilce':
        return DeliveryZoneType.ilce;
      case 'koy':
        return DeliveryZoneType.koy;
      default:
        return DeliveryZoneType.mahalle;
    }
  }

  String get key => name;

  /// Bölge seçicideki grup başlığı
  String get groupLabel => switch (this) {
        DeliveryZoneType.yurt => 'Yurtlar',
        DeliveryZoneType.ilce => 'İlçe merkezi',
        DeliveryZoneType.mahalle => 'Mahalleler',
        DeliveryZoneType.koy => 'Köyler',
      };
}

/// Adrese teslimatın açık olup olmadığı (`GET /delivery/me`).
class DeliveryAccess {
  /// "off" | "pilot" | "public"
  final String addressOrdering;
  final bool canOrderToAddress;

  const DeliveryAccess({
    this.addressOrdering = 'off',
    this.canOrderToAddress = false,
  });

  /// Hata ya da yanıt yoksa güvenli taraf: yalnızca yurt akışı.
  static const disabled = DeliveryAccess();

  factory DeliveryAccess.fromJson(Map<String, dynamic> json) => DeliveryAccess(
        addressOrdering: _toStr(json['addressOrdering']).isEmpty
            ? 'off'
            : _toStr(json['addressOrdering']),
        canOrderToAddress: json['canOrderToAddress'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is DeliveryAccess &&
      other.addressOrdering == addressOrdering &&
      other.canOrderToAddress == canOrderToAddress;

  @override
  int get hashCode => Object.hash(addressOrdering, canOrderToAddress);
}

/// Teslimat bölgesi (`GET /delivery/zones` → zones[]).
class DeliveryZone {
  final String id;
  final String name;
  final DeliveryZoneType type;

  /// Bölgenin normal teslimat ücreti (TL). Kampanyada üstü çizili gösterilir.
  final double deliveryFee;
  final bool isFree;

  /// Bu tutar ve üstünde teslimat ücretsiz (0/null = eşik yok)
  final double? freeDeliveryThreshold;

  /// Bu bölgede geçerli minimum sipariş tutarı (her zaman uygulanır)
  final double minimumOrderAmount;
  final String etaText;
  final bool requiresFirstOrderCallback;

  /// Adres eklerken haritada konum (ve mahalle) zorunlu (Devrek)
  final bool requiresLocation;

  /// Bölgenin haritada çizilecek sınırı yüklü
  /// (`GET /delivery/zones/:id/area`)
  final bool hasArea;

  const DeliveryZone({
    required this.id,
    required this.name,
    required this.type,
    this.deliveryFee = 0,
    this.isFree = false,
    this.freeDeliveryThreshold,
    this.minimumOrderAmount = 0,
    this.etaText = '',
    this.requiresFirstOrderCallback = false,
    this.requiresLocation = false,
    this.hasArea = false,
  });

  bool get isDorm => type == DeliveryZoneType.yurt;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    final threshold = json['freeDeliveryThreshold'];
    return DeliveryZone(
      id: _toStr(json['id'] ?? json['_id']),
      name: _toStr(json['name']),
      type: DeliveryZoneType.parse(json['type']),
      deliveryFee: _toDouble(json['deliveryFee']),
      isFree: json['isFree'] == true,
      freeDeliveryThreshold:
          threshold is num && threshold > 0 ? threshold.toDouble() : null,
      minimumOrderAmount: _toDouble(json['minimumOrderAmount']),
      etaText: _toStr(json['etaText']),
      requiresFirstOrderCallback: json['requiresFirstOrderCallback'] == true,
      requiresLocation:
          json['requiresLocation'] == true || json['type'] == 'ilce',
      hasArea: json['hasArea'] == true,
    );
  }
}

/// Bölge listesi ve genel kampanya bayrağı.
class DeliveryZonesResult {
  final List<DeliveryZone> zones;

  /// Kampanya: her bölgede teslimat ücretsiz (zones[].isFree = true gelir)
  final bool freeDeliveryEverywhere;

  const DeliveryZonesResult({
    this.zones = const [],
    this.freeDeliveryEverywhere = false,
  });

  factory DeliveryZonesResult.fromJson(Map<String, dynamic> json) {
    final raw = json['zones'];
    return DeliveryZonesResult(
      zones: raw is List
          ? raw
              .whereType<Map>()
              .map((z) => DeliveryZone.fromJson(Map<String, dynamic>.from(z)))
              .where((z) => z.id.isNotEmpty)
              .toList()
          : const [],
      freeDeliveryEverywhere: json['freeDeliveryEverywhere'] == true,
    );
  }
}

/// Adres konumu (Devrek adresinde zorunlu).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  static GeoPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Teslimat alanı (GeoJSON Polygon / MultiPolygon). Her çokgen halkalardan
/// oluşur: ilki dış sınır, kalanlar delik. Sunucu kesin denetimi yapar;
/// uygulama haritada sınırı çizer ve iğneyi önceden denetler.
class DeliveryArea {
  /// polygons[çokgen][halka][nokta]
  final List<List<List<GeoPoint>>> polygons;

  const DeliveryArea(this.polygons);

  /// `{ type, coordinates }` ([boylam, enlem]). Geçersizse null.
  static DeliveryArea? fromGeoJson(Object? json) {
    if (json is! Map) return null;
    final type = json['type'];
    final coordinates = json['coordinates'];
    if (coordinates is! List) return null;

    List<GeoPoint>? ring(Object? raw) {
      if (raw is! List) return null;
      final points = <GeoPoint>[];
      for (final p in raw) {
        if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) {
          return null;
        }
        points
            .add(GeoPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()));
      }
      return points.length >= 4 ? points : null;
    }

    List<List<GeoPoint>>? polygon(Object? raw) {
      if (raw is! List || raw.isEmpty) return null;
      final rings = raw.map(ring).toList();
      if (rings.any((r) => r == null)) return null;
      return rings.cast<List<GeoPoint>>();
    }

    final List<List<List<GeoPoint>>> polygons;
    if (type == 'Polygon') {
      final single = polygon(coordinates);
      if (single == null) return null;
      polygons = [single];
    } else if (type == 'MultiPolygon') {
      final all = coordinates.map(polygon).toList();
      if (all.isEmpty || all.any((p) => p == null)) return null;
      polygons = all.cast<List<List<GeoPoint>>>();
    } else {
      return null;
    }
    return DeliveryArea(polygons);
  }

  /// Nokta alanın içinde mi? Delikler dışarı sayılır (ışın atma).
  bool contains(GeoPoint point) {
    for (final rings in polygons) {
      if (rings.isEmpty || !_inRing(point, rings.first)) continue;
      if (rings.skip(1).any((hole) => _inRing(point, hole))) continue;
      return true;
    }
    return false;
  }

  static bool _inRing(GeoPoint point, List<GeoPoint> ring) {
    final x = point.lng;
    final y = point.lat;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].lng, yi = ring[i].lat;
      final xj = ring[j].lng, yj = ring[j].lat;
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Dış sınırların kapsadığı dikdörtgen: (güneybatı, kuzeydoğu)
  (GeoPoint, GeoPoint) get bounds {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final rings in polygons) {
      for (final p in rings.first) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
      }
    }
    return (GeoPoint(minLat, minLng), GeoPoint(maxLat, maxLng));
  }
}

/// Adresin yazılı alanları. Kayıtlı adres, sipariş içi adres ve form ortak
/// kullanır. Uzunluk sınırları sunucuyla aynıdır.
class AddressFields {
  static const int labelMax = 30;
  static const int neighborhoodMax = 60;
  static const int streetMax = 120;
  static const int buildingNoMax = 20;
  static const int buildingNameMax = 60;
  static const int floorMax = 10;
  static const int apartmentMax = 10;
  static const int directionsMax = 300;

  /// Mahalle (Devrek adresinde zorunlu)
  final String neighborhood;
  final String street;
  final String buildingNo;
  final String buildingName;
  final String floor;
  final String apartment;
  final String directions;
  final GeoPoint? location;

  const AddressFields({
    this.neighborhood = '',
    this.street = '',
    this.buildingNo = '',
    this.buildingName = '',
    this.floor = '',
    this.apartment = '',
    this.directions = '',
    this.location,
  });

  factory AddressFields.fromJson(Map<String, dynamic> json) => AddressFields(
        neighborhood: _toStr(json['neighborhood']),
        street: _toStr(json['street']),
        buildingNo: _toStr(json['buildingNo']),
        buildingName: _toStr(json['buildingName']),
        floor: _toStr(json['floor']),
        apartment: _toStr(json['apartment']),
        directions: _toStr(json['directions']),
        location: GeoPoint.fromJson(json['location']),
      );

  Map<String, dynamic> toJson() => {
        'neighborhood': neighborhood.trim(),
        'street': street.trim(),
        'buildingNo': buildingNo.trim(),
        'buildingName': buildingName.trim(),
        'floor': floor.trim(),
        'apartment': apartment.trim(),
        'directions': directions.trim(),
        'location': location?.toJson(),
      };

  static final _neighborhoodSuffix =
      RegExp(r'\s+(mahallesi|mahalle|mah\.?)$', caseSensitive: false);

  /// "Cumhuriyet" / "Cumhuriyet Mahallesi" → "Cumhuriyet Mah." (sunucuyla aynı)
  static String neighborhoodLabel(String value) {
    final name = value.trim().replaceAll(_neighborhoodSuffix, '').trim();
    return name.isEmpty ? '' : '$name Mah.';
  }

  /// "Cumhuriyet Mah. · Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4"
  String get summary {
    final first = [
      street.trim(),
      if (buildingNo.trim().isNotEmpty) 'No:${buildingNo.trim()}',
    ].where((s) => s.isNotEmpty).join(' ');
    return [
      neighborhoodLabel(neighborhood),
      first,
      buildingName.trim(),
      if (floor.trim().isNotEmpty) 'Kat ${floor.trim()}',
      if (apartment.trim().isNotEmpty) 'Daire ${apartment.trim()}',
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  // Biçim kuralları (Türkiye adres düzeni)
  static const _harf = 'A-Za-zÇĞİÖŞÜçğıöşüÂâÎîÛû';

  /// Bina no: rakamla başlar; sonda harf ve "/" ya da "-" ile ikinci numara
  /// olabilir. "5", "12A", "12 B", "15/2", "23-25", "7/A".
  static final _buildingNoPattern = RegExp(
      '^\\d{1,4}\\s?[$_harf]?(\\s?[/-]\\s?(\\d{1,4}\\s?[$_harf]?|[$_harf]))?\$');

  /// Daire: numara, isteğe bağlı tek harf. "4", "4B", "B4", "12".
  static final _apartmentPattern =
      RegExp('^([$_harf]\\s?)?\\d{1,4}\\s?[$_harf]?\$');

  /// Kat: sayı (eksi = bodrum) ya da bilinen kat adı. "2", "-1", "2.",
  /// "Zemin", "Bodrum", "Yüksek giriş", "B1".
  static final _floorNumber = RegExp(r'^-?\d{1,2}\.?$');
  static final _floorCode = RegExp(r'^[bk]\s?-?\d$');
  static const _floorWords = {
    'zemin',
    'bodrum',
    'bahce',
    'giris',
    'yuksek giris',
    'duz giris',
    'cati',
    'asma',
    'kot',
    'teras',
    'catı',
  };

  static String _fold(String value) {
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    final lower = value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    return lower.split('').map((c) => map[c] ?? c).join();
  }

  static bool isValidBuildingNo(String value) =>
      _buildingNoPattern.hasMatch(value.trim());

  static bool isValidApartment(String value) =>
      _apartmentPattern.hasMatch(value.trim());

  static bool isValidFloor(String value) {
    var text = _fold(value.trim()).replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s?(kat|kati)$'), '').trim();
    if (text.isEmpty) return false;
    return _floorNumber.hasMatch(text) ||
        _floorCode.hasMatch(text) ||
        _floorWords.contains(text);
  }

  /// Mahalle adı: en az iki harf; rakam ya da yalnızca "Mahalle" olamaz.
  static bool isValidNeighborhood(String value) {
    final text = value.trim();
    if (RegExp(r'\d').hasMatch(text)) return false;
    final letters = RegExp('[$_harf]').allMatches(text).length;
    if (letters < 2) return false;
    final bare = _fold(text).replaceAll(RegExp(r'[.\s]'), '');
    return !{'mahalle', 'mahallesi', 'mah'}.contains(bare);
  }

  /// Sokak / cadde: en az iki karakter, harf ya da rakam içermeli
  /// ("Atatürk Cd.", "1. Sokak", "5021 Sokak").
  static bool isValidStreet(String value) {
    final text = value.trim();
    if (text.length < 2) return false;
    final bare = _fold(text).replaceAll(RegExp(r'[.\s]'), '');
    if ({'sokak', 'sk', 'cadde', 'cd', 'caddesi', 'sokagi'}.contains(bare)) {
      return false;
    }
    return RegExp('[$_harf\\d]').hasMatch(text);
  }

  /// Bölge tipine göre zorunlu alanlar ve biçim kuralları. Hata yoksa boş;
  /// varsa alan → mesaj. Devrek'teki konum zorunluluğunu ve sınır denetimini
  /// form ayrıca yapar.
  Map<String, String> validate(DeliveryZoneType type) {
    final errors = <String, String>{};
    if (type == DeliveryZoneType.yurt) return errors;
    final requireAll = type == DeliveryZoneType.ilce;

    final n = neighborhood.trim();
    if (requireAll && n.isEmpty) {
      errors['neighborhood'] = 'Mahalleni yaz';
    } else if (n.isNotEmpty && !isValidNeighborhood(n)) {
      errors['neighborhood'] = 'Mahalle adını yaz (örn. Cumhuriyet Mahallesi)';
    }

    final st = street.trim();
    if (st.isEmpty) {
      errors['street'] = 'Sokak / cadde yaz';
    } else if (!isValidStreet(st)) {
      errors['street'] = 'Sokak ya da cadde adını yaz (örn. Atatürk Caddesi)';
    }

    final b = buildingNo.trim();
    if (requireAll && b.isEmpty) {
      errors['buildingNo'] = 'Bina no yaz';
    } else if (b.isNotEmpty && !isValidBuildingNo(b)) {
      errors['buildingNo'] = 'Rakamla yaz (örn. 5, 12A, 15/2)';
    }

    final f = floor.trim();
    if (f.isNotEmpty && !isValidFloor(f)) {
      errors['floor'] = 'Örn. 2, Zemin, Bodrum';
    }

    final a = apartment.trim();
    if (a.isNotEmpty && !isValidApartment(a)) {
      errors['apartment'] = 'Örn. 4, 4B';
    }
    return errors;
  }
}

/// Kayıtlı adres (`/addresses`).
class DeliveryAddress {
  final String id;
  final String label;
  final String zoneId;
  final String zoneName;
  final DeliveryZoneType zoneType;

  /// Bölge sonradan kapatıldıysa false: listede görünür, ödemede seçilemez
  final bool zoneEnabled;
  final AddressFields fields;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.zoneId,
    required this.zoneName,
    required this.zoneType,
    this.zoneEnabled = true,
    this.fields = const AddressFields(),
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        id: _toStr(json['_id'] ?? json['id']),
        label: _toStr(json['label']),
        zoneId: _toStr(json['zoneId']),
        zoneName: _toStr(json['zoneName']),
        zoneType: DeliveryZoneType.parse(json['zoneType']),
        zoneEnabled: json['zoneEnabled'] != false,
        fields: AddressFields.fromJson(json),
        isDefault: json['isDefault'] == true,
        createdAt: DateTime.tryParse(_toStr(json['createdAt'])),
        updatedAt: DateTime.tryParse(_toStr(json['updatedAt'])),
      );

  /// Liste başlığı: etiket yoksa bölge adı
  String get title => label.trim().isNotEmpty ? label.trim() : zoneName;

  /// Devrek: "Cumhuriyet Mah. · Atatürk Cd. No:5"; mahallesiz (eski ya da
  /// yurt) adreste başta bölge adı.
  String get summary => [
        if (fields.neighborhood.trim().isEmpty) zoneName,
        fields.summary,
      ].where((s) => s.isNotEmpty).join(' · ');

  static List<DeliveryAddress> listFromJson(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((a) => DeliveryAddress.fromJson(Map<String, dynamic>.from(a)))
          .where((a) => a.id.isNotEmpty)
          .toList()
      : const [];
}

/// Teslimat ücreti ve minimum hesabı (`POST /delivery/quote`).
class DeliveryQuote {
  final String zoneId;
  final String zoneName;
  final double subtotal;
  final double deliveryFee;
  final bool isFree;

  /// "campaign" | "zone" | "threshold" | null
  final String? freeReason;

  /// Ücretsiz teslimata kalan tutar (yoksa null/0)
  final double? remainingForFree;
  final double minimumOrderAmount;
  final bool meetsMinimum;

  /// Kupon öncesi toplam (ürünler + teslimat)
  final double total;

  const DeliveryQuote({
    required this.zoneId,
    this.zoneName = '',
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.isFree = false,
    this.freeReason,
    this.remainingForFree,
    this.minimumOrderAmount = 0,
    this.meetsMinimum = true,
    this.total = 0,
  });

  bool get isCampaign => isFree && freeReason == 'campaign';

  /// Ödenecek teslimat ücreti
  double get payableFee => isFree ? 0 : deliveryFee;

  /// Minimuma kalan tutar
  double get missingForMinimum => meetsMinimum
      ? 0
      : (minimumOrderAmount - subtotal).clamp(0, double.infinity);

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    final remaining = json['remainingForFree'];
    final reason = json['freeReason'];
    return DeliveryQuote(
      zoneId: _toStr(json['zoneId']),
      zoneName: _toStr(json['zoneName']),
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      isFree: json['isFree'] == true,
      freeReason: reason is String && reason.isNotEmpty ? reason : null,
      remainingForFree:
          remaining is num && remaining > 0 ? remaining.toDouble() : null,
      minimumOrderAmount: _toDouble(json['minimumOrderAmount']),
      meetsMinimum: json['meetsMinimum'] != false,
      total: _toDouble(json['total']),
    );
  }
}

/// Siparişteki teslimat bölgesi özeti (`deliveryZone`).
class OrderDeliveryZone {
  final String id;
  final String name;
  final DeliveryZoneType type;

  const OrderDeliveryZone({
    required this.id,
    required this.name,
    required this.type,
  });

  static OrderDeliveryZone? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _toStr(json['id']);
    if (id.isEmpty && _toStr(json['name']).isEmpty) return null;
    return OrderDeliveryZone(
      id: id,
      name: _toStr(json['name']),
      type: DeliveryZoneType.parse(json['type']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.key};
}
