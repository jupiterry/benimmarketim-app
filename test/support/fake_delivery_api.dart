// Adrese teslimat testleri için sahte ApiService: bölgeler, kayıtlı adresler
// ve çağrı kayıtları bellekte tutulur. Ağa hiç gidilmez.

import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';

/// Örnek bölgeler: ücretli mahalle, ücretsiz mahalle, köy ve yurt.
const testZoneMahalle = DeliveryZone(
  id: 'cumhuriyet',
  name: 'Cumhuriyet Mahallesi',
  type: DeliveryZoneType.mahalle,
  deliveryFee: 40,
  etaText: '30-45 dk',
);
const testZoneFree = DeliveryZone(
  id: 'ozbag',
  name: 'Özbağ Mahallesi',
  type: DeliveryZoneType.mahalle,
  deliveryFee: 30,
  isFree: true,
  etaText: '20-30 dk',
);
const testZoneKoy = DeliveryZone(
  id: 'bostanlar',
  name: 'Bostanlar Köyü',
  type: DeliveryZoneType.koy,
  deliveryFee: 60,
  minimumOrderAmount: 150,
  etaText: '45-60 dk',
);
const testZoneYurt = DeliveryZone(
  id: 'girlsDorm',
  name: 'Kız KYK Yurdu',
  type: DeliveryZoneType.yurt,
  isFree: true,
  etaText: '20-30 dk',
);
const testZones = [testZoneMahalle, testZoneFree, testZoneKoy, testZoneYurt];

/// Kayıtlı adres örneği.
DeliveryAddress testAddress({
  String id = 'a1',
  String label = 'Ev',
  DeliveryZone zone = testZoneMahalle,
  bool zoneEnabled = true,
  bool isDefault = false,
  AddressFields fields = const AddressFields(
    street: 'Atatürk Cd.',
    buildingNo: '5',
    buildingName: 'Gül Apt.',
    floor: '2',
    apartment: '4',
    directions: 'Eczanenin karşısı',
  ),
}) =>
    DeliveryAddress(
      id: id,
      label: label,
      zoneId: zone.id,
      zoneName: zone.name,
      zoneType: zone.type,
      zoneEnabled: zoneEnabled,
      fields: fields,
      isDefault: isDefault,
    );

class FakeDeliveryApi extends ApiService {
  FakeDeliveryApi({
    this.access = const DeliveryAccess(
      addressOrdering: 'public',
      canOrderToAddress: true,
    ),
    List<DeliveryZone> zones = testZones,
    List<DeliveryAddress> addresses = const [],
    this.freeDeliveryEverywhere = false,
    this.maxAddresses = 5,
  })  : zones = List.of(zones),
        addresses = List.of(addresses);

  DeliveryAccess access;
  List<DeliveryZone> zones;
  List<DeliveryAddress> addresses;
  bool freeDeliveryEverywhere;
  int maxAddresses;

  /// Verilirse ilgili çağrı bu hatayı fırlatır.
  Object? zonesError;
  Object? addressesError;
  ApiException? saveError;

  /// Çağrı sırası: 'GET /addresses', 'POST /addresses', 'PUT /addresses/a1'...
  final List<String> calls = [];

  /// Son POST /addresses gövdesi ve son PUT değişiklikleri
  Map<String, dynamic>? lastCreateBody;
  Map<String, dynamic>? lastUpdateChanges;

  var _nextId = 1;

  @override
  Future<DeliveryAccess> getDeliveryAccess() async {
    calls.add('GET /delivery/me');
    return access;
  }

  @override
  Future<DeliveryZonesResult> getDeliveryZones() async {
    calls.add('GET /delivery/zones');
    if (zonesError != null) throw zonesError!;
    return DeliveryZonesResult(
      zones: List.of(zones),
      freeDeliveryEverywhere: freeDeliveryEverywhere,
    );
  }

  @override
  Future<({List<DeliveryAddress> addresses, int max})> getAddresses() async {
    calls.add('GET /addresses');
    if (addressesError != null) throw addressesError!;
    return (addresses: List.of(addresses), max: maxAddresses);
  }

  @override
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      createAddress({
    required String label,
    required String zoneId,
    required AddressFields fields,
    bool? isDefault,
  }) async {
    calls.add('POST /addresses');
    lastCreateBody = {
      'label': label.trim(),
      'zoneId': zoneId,
      ...fields.toJson(),
      if (isDefault != null) 'isDefault': isDefault,
    };
    if (saveError != null) throw saveError!;
    if (addresses.length >= maxAddresses) {
      throw ApiException('En fazla $maxAddresses adres kaydedebilirsin.',
          statusCode: 400, code: 'ADDRESS_LIMIT');
    }
    final zone = zones.firstWhere((z) => z.id == zoneId);
    final makeDefault = addresses.isEmpty || isDefault == true;
    final address = DeliveryAddress(
      id: 'new${_nextId++}',
      label: label.trim(),
      zoneId: zone.id,
      zoneName: zone.name,
      zoneType: zone.type,
      fields: fields,
      isDefault: makeDefault,
    );
    addresses = [
      for (final a in addresses) makeDefault ? _withDefault(a, false) : a,
      address,
    ];
    return (address: address, addresses: List.of(addresses));
  }

  @override
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      updateAddress(String id, Map<String, dynamic> changes) async {
    calls.add('PUT /addresses/$id');
    lastUpdateChanges = Map.of(changes);
    if (saveError != null) throw saveError!;
    final index = addresses.indexWhere((a) => a.id == id);
    final json = {..._toJson(addresses[index]), ...changes};
    final zoneId = changes['zoneId'];
    if (zoneId is String) {
      final zone = zones.firstWhere((z) => z.id == zoneId);
      json['zoneName'] = zone.name;
      json['zoneType'] = zone.type.key;
      json['zoneEnabled'] = true;
    }
    final updated = DeliveryAddress.fromJson(json);
    addresses = [...addresses]..[index] = updated;
    return (address: updated, addresses: List.of(addresses));
  }

  @override
  Future<List<DeliveryAddress>> deleteAddress(String id) async {
    calls.add('DELETE /addresses/$id');
    if (saveError != null) throw saveError!;
    final removed = addresses.firstWhere((a) => a.id == id);
    addresses = addresses.where((a) => a.id != id).toList();
    if (removed.isDefault && addresses.isNotEmpty) {
      addresses = [_withDefault(addresses.first, true), ...addresses.skip(1)];
    }
    return List.of(addresses);
  }

  @override
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      setDefaultAddress(String id) async {
    calls.add('PATCH /addresses/$id/default');
    if (saveError != null) throw saveError!;
    addresses = [for (final a in addresses) _withDefault(a, a.id == id)];
    return (
      address: addresses.firstWhere((a) => a.id == id),
      addresses: List.of(addresses),
    );
  }

  static DeliveryAddress _withDefault(DeliveryAddress a, bool value) =>
      DeliveryAddress.fromJson({..._toJson(a), 'isDefault': value});

  static Map<String, dynamic> _toJson(DeliveryAddress a) => {
        '_id': a.id,
        'label': a.label,
        'zoneId': a.zoneId,
        'zoneName': a.zoneName,
        'zoneType': a.zoneType.key,
        'zoneEnabled': a.zoneEnabled,
        'isDefault': a.isDefault,
        ...a.fields.toJson(),
      };
}

/// Oturumu açık, [api] ile çalışan view model. Erişim, bölgeler ve adresler
/// ilk `tester.pump()` ile yüklenir.
DeliveryViewModel createTestDeliveryViewModel(FakeDeliveryApi api) {
  final delivery = DeliveryViewModel(
    api: api,
    listenLifecycle: false,
    quoteDebounce: Duration.zero,
  );
  delivery.onAuthChanged(true);
  return delivery;
}
