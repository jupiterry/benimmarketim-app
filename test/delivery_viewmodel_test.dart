import 'package:benimmarketim_app/models/cart_item.dart';
import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/models/order.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/delivery_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, double price) => Product(
      id: id,
      name: 'Ürün $id',
      description: '',
      price: price,
      originalPrice: price,
      actualPrice: price,
      image: '',
      category: '',
      categoryId: '',
      isDiscounted: false,
      isOutOfStock: false,
      isFeatured: false,
      isHidden: false,
      order: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Map<String, dynamic> _zoneJson(String id, String type,
        {double fee = 40, bool free = false}) =>
    {
      'id': id,
      'name': 'Bölge $id',
      'type': type,
      'deliveryFee': fee,
      'isFree': free,
      'freeDeliveryThreshold': 500,
      'minimumOrderAmount': 250,
      'etaText': '30-60 dk',
      'requiresFirstOrderCallback': false,
    };

Map<String, dynamic> _addressJson(String id, String zoneId,
        {bool isDefault = false, bool zoneEnabled = true}) =>
    {
      '_id': id,
      'label': 'Ev',
      'zoneId': zoneId,
      'zoneName': 'Bölge $zoneId',
      'zoneType': 'mahalle',
      'zoneEnabled': zoneEnabled,
      'street': 'Atatürk Cd.',
      'buildingNo': '5',
      'buildingName': '',
      'floor': '2',
      'apartment': '4',
      'directions': '',
      'location': null,
      'isDefault': isDefault,
    };

/// Ağ yerine sabit yanıtlar veren ApiService.
class _FakeApi extends ApiService {
  DeliveryAccess access = const DeliveryAccess(
      addressOrdering: 'public', canOrderToAddress: true);
  bool accessFails = false;
  int accessCalls = 0;
  int quoteCalls = 0;
  ApiException? quoteFailure;
  final List<Map<String, dynamic>> quoteRequests = [];

  List<DeliveryAddress> addresses = [
    DeliveryAddress.fromJson(_addressJson('a1', 'mah-1', isDefault: true)),
    DeliveryAddress.fromJson(_addressJson('a2', 'koy-1')),
  ];

  @override
  Future<DeliveryAccess> getDeliveryAccess() async {
    accessCalls++;
    if (accessFails) throw const ApiException('Sunucu hatası', statusCode: 500);
    return access;
  }

  @override
  Future<DeliveryZonesResult> getDeliveryZones() async =>
      DeliveryZonesResult.fromJson({
        'zones': [
          _zoneJson('girlsDorm', 'yurt', fee: 0, free: true),
          _zoneJson('mah-1', 'mahalle'),
          _zoneJson('koy-1', 'koy', fee: 60),
        ],
        'freeDeliveryEverywhere': false,
      });

  @override
  Future<({List<DeliveryAddress> addresses, int max})> getAddresses() async =>
      (addresses: addresses, max: 5);

  @override
  Future<DeliveryQuote> getDeliveryQuote({
    required String zoneId,
    required List<Map<String, dynamic>> products,
  }) async {
    quoteCalls++;
    quoteRequests.add({'zoneId': zoneId, 'products': products});
    if (quoteFailure != null) throw quoteFailure!;
    final subtotal = products.fold<double>(
        0, (sum, p) => sum + 10 * (p['quantity'] as int));
    return DeliveryQuote(
      zoneId: zoneId,
      subtotal: subtotal,
      deliveryFee: 40,
      minimumOrderAmount: 250,
      meetsMinimum: subtotal >= 250,
      remainingForFree: 500 - subtotal,
      total: subtotal + 40,
    );
  }
}

Future<DeliveryViewModel> _signedIn(_FakeApi api) async {
  final vm = DeliveryViewModel(
    api: api,
    quoteDebounce: const Duration(milliseconds: 10),
    listenLifecycle: false,
  );
  vm.onAuthChanged(true);
  // Erişim mikro görevde istenir; bölge ve adresler ardından yüklenir.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return vm;
}

void main() {
  group('modeller', () {
    test('bölge listesi ve kampanya bayrağı okunur', () {
      final result = DeliveryZonesResult.fromJson({
        'zones': [
          _zoneJson('mah-1', 'mahalle'),
          {'id': '', 'name': 'kimliksiz'},
        ],
        'freeDeliveryEverywhere': true,
      });
      expect(result.zones, hasLength(1));
      expect(result.zones.single.type, DeliveryZoneType.mahalle);
      expect(result.zones.single.freeDeliveryThreshold, 500);
      expect(result.freeDeliveryEverywhere, isTrue);
    });

    test('teklif: kampanya ve minimuma kalan tutar', () {
      final quote = DeliveryQuote.fromJson({
        'zoneId': 'mah-1',
        'subtotal': 140,
        'deliveryFee': 40,
        'isFree': true,
        'freeReason': 'campaign',
        'remainingForFree': 0,
        'minimumOrderAmount': 250,
        'meetsMinimum': false,
        'total': 140,
      });
      expect(quote.isCampaign, isTrue);
      expect(quote.payableFee, 0);
      expect(quote.remainingForFree, isNull);
      expect(quote.missingForMinimum, 110);
    });

    test('adres doğrulaması bölge tipine göre değişir', () {
      const empty = AddressFields();
      expect(empty.validate(DeliveryZoneType.ilce).keys,
          ['neighborhood', 'street', 'buildingNo']);
      // Eski (kapatılmış) bölgeler: sunucu yalnızca sokak ister
      expect(empty.validate(DeliveryZoneType.mahalle).keys, ['street']);
      expect(empty.validate(DeliveryZoneType.koy).keys, ['street']);
      expect(empty.validate(DeliveryZoneType.yurt), isEmpty);
      const full = AddressFields(
          neighborhood: 'Cumhuriyet', street: 'Atatürk Cd.', buildingNo: '5');
      expect(full.validate(DeliveryZoneType.ilce), isEmpty);
    });

    test('Devrek bölgesi ve mahalle', () {
      final zone = DeliveryZone.fromJson({
        'id': 'devrek',
        'name': 'Devrek',
        'type': 'ilce',
        'deliveryFee': 40,
        'requiresLocation': true,
        'hasArea': true,
      });
      expect(zone.type, DeliveryZoneType.ilce);
      expect(zone.requiresLocation, isTrue);
      expect(zone.hasArea, isTrue);
      expect(zone.isDorm, isFalse);

      expect(AddressFields.neighborhoodLabel('Cumhuriyet'), 'Cumhuriyet Mah.');
      expect(AddressFields.neighborhoodLabel('Cumhuriyet Mahallesi'),
          'Cumhuriyet Mah.');
      expect(AddressFields.neighborhoodLabel(' '), '');

      final address = DeliveryAddress.fromJson({
        '_id': 'a1',
        'zoneId': 'devrek',
        'zoneName': 'Devrek',
        'zoneType': 'ilce',
        'neighborhood': 'Cumhuriyet Mahallesi',
        'street': 'Atatürk Cd.',
        'buildingNo': '5',
      });
      expect(address.fields.neighborhood, 'Cumhuriyet Mahallesi');
      // Mahalle varken bölge adı tekrar edilmez
      expect(address.summary, 'Cumhuriyet Mah. · Atatürk Cd. No:5');
      expect(address.fields.toJson()['neighborhood'], 'Cumhuriyet Mahallesi');
    });

    test('adres özeti', () {
      final address = DeliveryAddress.fromJson(_addressJson('a1', 'mah-1'));
      expect(address.fields.summary, 'Atatürk Cd. No:5 · Kat 2 · Daire 4');
      expect(address.summary, 'Bölge mah-1 · Atatürk Cd. No:5 · Kat 2 · Daire 4');
    });
  });

  group('sipariş isteği', () {
    CreateOrderRequest request({
      String? addressId,
      String? zoneId,
      AddressFields? address,
    }) =>
        CreateOrderRequest(
          products: const [
            {'product': 'p1', 'quantity': 2}
          ],
          totalAmount: 20,
          city: 'Zonguldak',
          phone: '05321234567',
          deliveryPoint: addressId == null && address == null ? 'girlsDorm' : '',
          deliveryPointName: 'Kız KYK Yurdu',
          note: '',
          paymentMethod: PaymentMethod.cash,
          addressId: addressId,
          zoneId: zoneId,
          deliveryAddress: address,
        );

    test('yurt akışında bugünkü gövde gider', () {
      final json = request().toJson();
      expect(json['deliveryPoint'], 'girlsDorm');
      expect(json['deliveryPointName'], 'Kız KYK Yurdu');
      expect(json.containsKey('addressId'), isFalse);
      expect(json.containsKey('zoneId'), isFalse);
    });

    test('yurt bölge olarak seçildiyse zoneId eklenir', () {
      final json = request(zoneId: 'girlsDorm').toJson();
      expect(json['deliveryPoint'], 'girlsDorm');
      expect(json['zoneId'], 'girlsDorm');
    });

    test('kayıtlı adresle yalnızca addressId gider', () {
      final json = request(addressId: 'a1').toJson();
      expect(json['addressId'], 'a1');
      expect(json.containsKey('deliveryPoint'), isFalse);
      expect(json.containsKey('totalAmount'), isFalse);
      expect(json['paymentMethod'], 'cash');
    });

    test('kayıtsız adresle zoneId ve deliveryAddress gider', () {
      final json = request(
        zoneId: 'mah-1',
        address: const AddressFields(street: 'Atatürk Cd.', buildingNo: '5'),
      ).toJson();
      expect(json['zoneId'], 'mah-1');
      expect((json['deliveryAddress'] as Map)['street'], 'Atatürk Cd.');
      expect(json.containsKey('addressId'), isFalse);
    });
  });

  group('sipariş modeli', () {
    test('eski siparişte varsayılanlar', () {
      final order = Order.fromJson({'_id': 'o1', 'totalAmount': 120});
      expect(order.isAddressDelivery, isFalse);
      expect(order.deliveryFee, 0);
      expect(order.productTotalOrDerived, 120);
      expect(order.awaitingCallback, isFalse);
    });

    test('adresli sipariş alanları', () {
      final order = Order.fromJson({
        '_id': 'o2',
        'totalAmount': 180,
        'deliveryType': 'address',
        'deliveryZone': {'id': 'mah-1', 'name': 'Cumhuriyet', 'type': 'mahalle'},
        'deliveryAddress': {'street': 'Atatürk Cd.', 'buildingNo': '5'},
        'deliveryFee': 40,
        'productTotal': 140,
        'needsCallback': true,
        'callbackConfirmedAt': null,
        'deliveryOutcomeLabel': 'Teslim edilemedi: Adres bulunamadı',
      });
      expect(order.isAddressDelivery, isTrue);
      expect(order.deliveryZone?.type, DeliveryZoneType.mahalle);
      expect(order.deliveryAddress?.summary, 'Atatürk Cd. No:5');
      expect(order.productTotalOrDerived, 140);
      expect(order.awaitingCallback, isTrue);
      expect(order.deliveryOutcomeLabel, contains('Adres bulunamadı'));
    });
  });

  group('DeliveryViewModel', () {
    test('oturum yokken adres akışı kapalı', () {
      final vm = DeliveryViewModel(api: _FakeApi(), listenLifecycle: false);
      expect(vm.canOrderToAddress, isFalse);
      vm.dispose();
    });

    test('açılınca bölgeler ve adresler yüklenir, varsayılan seçilir', () async {
      final api = _FakeApi();
      final vm = await _signedIn(api);
      expect(vm.canOrderToAddress, isTrue);
      expect(vm.zones, hasLength(3));
      expect(vm.addresses, hasLength(2));
      expect(vm.selectedAddress?.id, 'a1');
      expect(vm.selectedZoneId, 'mah-1');
      expect(vm.selectionUsable, isTrue);
      expect(vm.cheapestFee, 0);
      vm.dispose();
    });

    test('erişim sorgusu hata verirse yurt akışında kalınır', () async {
      final api = _FakeApi()..accessFails = true;
      final vm = await _signedIn(api);
      expect(vm.canOrderToAddress, isFalse);
      expect(vm.addressesLoaded, isFalse);
      vm.dispose();
    });

    test('anahtar kapanınca yurt akışına dönülür', () async {
      final api = _FakeApi();
      final vm = await _signedIn(api);
      expect(vm.canOrderToAddress, isTrue);
      api.access = DeliveryAccess.disabled;
      await vm.handleAddressOrderingDisabled();
      expect(vm.canOrderToAddress, isFalse);
      vm.dispose();
    });

    test('oturum kapanınca kullanıcı verisi temizlenir', () async {
      final vm = await _signedIn(_FakeApi());
      vm.onAuthChanged(false);
      expect(vm.canOrderToAddress, isFalse);
      expect(vm.addresses, isEmpty);
      expect(vm.selectedAddress, isNull);
      vm.dispose();
    });

    test('kapalı bölgedeki adres seçilemez', () async {
      final api = _FakeApi()
        ..addresses = [
          DeliveryAddress.fromJson(
              _addressJson('a1', 'mah-1', isDefault: true, zoneEnabled: false)),
        ];
      final vm = await _signedIn(api);
      expect(vm.selectedAddress?.id, 'a1');
      expect(vm.selectionUsable, isFalse);
      vm.dispose();
    });

    test('yurt seçimi bölge kimliğini değiştirir', () async {
      final vm = await _signedIn(_FakeApi());
      vm.selectDorm('girlsDorm');
      expect(vm.selectedAddress, isNull);
      expect(vm.selectedZoneId, 'girlsDorm');
      expect(vm.selectedDormZone?.isDorm, isTrue);
      vm.selectAddress('a2');
      expect(vm.selectedZoneId, 'koy-1');
      vm.dispose();
    });

    test('teklif istekleri gecikmeli ve tek seferlik gider', () async {
      final api = _FakeApi();
      final vm = await _signedIn(api);
      final items = [CartItem(product: _product('p1', 10), quantity: 2)];
      vm.requestQuote(items);
      vm.requestQuote(items);
      vm.requestQuote([CartItem(product: _product('p1', 10), quantity: 3)]);
      expect(vm.quoteLoading, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(api.quoteCalls, 1);
      expect(vm.quote?.subtotal, 30);
      expect(vm.quote?.zoneId, 'mah-1');
      expect(vm.quoteLoading, isFalse);

      // Aynı sepet tekrar sorulmaz
      vm.requestQuote([CartItem(product: _product('p1', 10), quantity: 3)]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(api.quoteCalls, 1);

      // Adres değişince eski teklif gösterilmez, yenisi istenir
      vm.selectAddress('a2');
      expect(vm.quote, isNull);
      vm.requestQuote([CartItem(product: _product('p1', 10), quantity: 3)]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(api.quoteCalls, 2);
      expect(vm.quote?.zoneId, 'koy-1');
      vm.dispose();
    });

    test('kapalı bölge hatası saklanır', () async {
      final api = _FakeApi()
        ..quoteFailure = const ApiException('Bölge bugün kapalı',
            statusCode: 400, code: 'ZONE_CLOSED');
      final vm = await _signedIn(api);
      vm.requestQuote([CartItem(product: _product('p1', 10))]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(vm.quote, isNull);
      expect(vm.quoteError?.code, 'ZONE_CLOSED');
      expect(vm.quoteError?.message, 'Bölge bugün kapalı');
      vm.dispose();
    });
  });
}
