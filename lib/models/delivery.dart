/// Adrese teslimat modelleri. Sunucu sözleşmesi: GET /delivery/me,
/// GET /delivery/zones, /addresses, POST /delivery/quote.
library;

double _toDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

String _toStr(Object? value) => value == null ? '' : value.toString();

/// Bölge tipi: yurt, mahalle ya da köy.
enum DeliveryZoneType {
  yurt,
  mahalle,
  koy;

  static DeliveryZoneType parse(Object? value) {
    switch (value) {
      case 'yurt':
        return DeliveryZoneType.yurt;
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

/// Adres konumu (isteğe bağlı).
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
}

/// Adresin yazılı alanları. Kayıtlı adres, sipariş içi adres ve form ortak
/// kullanır. Uzunluk sınırları sunucuyla aynıdır.
class AddressFields {
  static const int labelMax = 30;
  static const int streetMax = 120;
  static const int buildingNoMax = 20;
  static const int buildingNameMax = 60;
  static const int floorMax = 10;
  static const int apartmentMax = 10;
  static const int directionsMax = 300;

  /// Köyde adres tarifi zorunlu; en az bu kadar karakter
  static const int villageDirectionsMin = 10;

  final String street;
  final String buildingNo;
  final String buildingName;
  final String floor;
  final String apartment;
  final String directions;
  final GeoPoint? location;

  const AddressFields({
    this.street = '',
    this.buildingNo = '',
    this.buildingName = '',
    this.floor = '',
    this.apartment = '',
    this.directions = '',
    this.location,
  });

  factory AddressFields.fromJson(Map<String, dynamic> json) => AddressFields(
        street: _toStr(json['street']),
        buildingNo: _toStr(json['buildingNo']),
        buildingName: _toStr(json['buildingName']),
        floor: _toStr(json['floor']),
        apartment: _toStr(json['apartment']),
        directions: _toStr(json['directions']),
        location: GeoPoint.fromJson(json['location']),
      );

  Map<String, dynamic> toJson() => {
        'street': street.trim(),
        'buildingNo': buildingNo.trim(),
        'buildingName': buildingName.trim(),
        'floor': floor.trim(),
        'apartment': apartment.trim(),
        'directions': directions.trim(),
        'location': location?.toJson(),
      };

  /// "Atatürk Cd. No:5 · Gül Apt. · Kat 2 · Daire 4"
  String get summary {
    final first = [
      street.trim(),
      if (buildingNo.trim().isNotEmpty) 'No:${buildingNo.trim()}',
    ].where((s) => s.isNotEmpty).join(' ');
    return [
      first,
      buildingName.trim(),
      if (floor.trim().isNotEmpty) 'Kat ${floor.trim()}',
      if (apartment.trim().isNotEmpty) 'Daire ${apartment.trim()}',
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  /// Bölge tipine göre doğrulama. Hata yoksa null; varsa alan → mesaj.
  Map<String, String> validate(DeliveryZoneType type) {
    final errors = <String, String>{};
    switch (type) {
      case DeliveryZoneType.mahalle:
        if (street.trim().isEmpty) errors['street'] = 'Sokak / cadde yaz';
        if (buildingNo.trim().isEmpty) errors['buildingNo'] = 'Bina no yaz';
      case DeliveryZoneType.koy:
        if (directions.trim().length < villageDirectionsMin) {
          errors['directions'] =
              'Evini bulabilmemiz için kısa bir tarif yaz (en az $villageDirectionsMin karakter)';
        }
      case DeliveryZoneType.yurt:
        break;
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

  /// "Cumhuriyet Mahallesi · Atatürk Cd. No:5"
  String get summary =>
      [zoneName, fields.summary].where((s) => s.isNotEmpty).join(' · ');

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
  double get missingForMinimum =>
      meetsMinimum ? 0 : (minimumOrderAmount - subtotal).clamp(0, double.infinity);

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
