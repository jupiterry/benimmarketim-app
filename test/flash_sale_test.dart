import 'package:benimmarketim_app/models/flash_sale.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/flash_sale_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> productJson(
  String id, {
  double price = 100,
  bool isDiscounted = false,
  double? discountedPrice,
  String updatedAt = '2026-10-01T10:00:00Z',
}) =>
    {
      '_id': id,
      'name': 'Ürün $id',
      'price': price,
      'isDiscounted': isDiscounted,
      'discountedPrice': discountedPrice,
      'category': 'atistirma',
      'createdAt': '2026-09-01T10:00:00Z',
      'updatedAt': updatedAt,
    };

FlashSale sale(
  String productId, {
  required DateTime now,
  Duration left = const Duration(hours: 2),
  double percent = 20,
  String id = 's1',
}) =>
    FlashSale.fromJson({
      '_id': id,
      'discountPercentage': percent,
      'startDate': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'endDate': now.add(left).toIso8601String(),
      'isActive': true,
      'product': productJson(
        productId,
        isDiscounted: true,
        discountedPrice: 100 * (1 - percent / 100),
        updatedAt: now.toIso8601String(),
      ),
    });

class FakeFlashApi extends ApiService {
  List<FlashSale>? active = [];
  final Map<String, Product> products = {};
  int productRequests = 0;

  @override
  Future<List<FlashSale>?> getActiveFlashSales() async => active;

  @override
  Future<Product> getProductById(String id) async {
    productRequests++;
    return products[id]!;
  }
}

void main() {
  group('Product indirim kuralı (sunucuyla aynı)', () {
    test('isDiscounted kapalıysa indirimli fiyat yok sayılır', () {
      final p = Product.fromJson(
        productJson('p1', isDiscounted: false, discountedPrice: 80),
      );
      expect(p.isDiscounted, isFalse);
      expect(p.actualPrice, 100);
    });

    test('indirimli fiyat normal fiyattan yüksekse yok sayılır', () {
      final p = Product.fromJson(
        productJson('p1', isDiscounted: true, discountedPrice: 120),
      );
      expect(p.isDiscounted, isFalse);
      expect(p.actualPrice, 100);
    });

    test('geçerli indirim uygulanır', () {
      final p = Product.fromJson(
        productJson('p1', isDiscounted: true, discountedPrice: 80),
      );
      expect(p.isDiscounted, isTrue);
      expect(p.actualPrice, 80);
      expect(p.discountPercentage, 20);
    });
  });

  group('FlashSaleViewModel', () {
    final now = DateTime.now();

    test('süren kampanya ürün için bulunur, güncel fiyat verilir', () async {
      final api = FakeFlashApi()..active = [sale('p1', now: now)];
      final vm = FlashSaleViewModel(apiService: api);
      final notified = <String>[];
      vm.addProductRefreshListener(
        (products) => notified.addAll(products.map((p) => p.id)),
      );

      await vm.refreshActive();

      final listed = Product.fromJson(productJson('p1'));
      expect(vm.saleFor('p1'), isNotNull);
      expect(vm.saleFor('p2'), isNull);
      expect(vm.latest(listed).actualPrice, 80);
      expect(notified, ['p1']);
      vm.dispose();
    });

    test('aynı kampanya tekrar okununca dinleyici yeniden çağrılmaz', () async {
      final api = FakeFlashApi()..active = [sale('p1', now: now)];
      final vm = FlashSaleViewModel(apiService: api);
      var calls = 0;
      vm.addProductRefreshListener((_) => calls++);

      await vm.refreshActive();
      await vm.refreshActive();

      expect(calls, 1);
      vm.dispose();
    });

    test('kampanya bitince ürün yeniden alınır ve normal fiyat döner',
        () async {
      final api = FakeFlashApi()..active = [sale('p1', now: now)];
      final vm = FlashSaleViewModel(apiService: api);
      final notified = <Product>[];
      vm.addProductRefreshListener(notified.addAll);
      await vm.refreshActive();

      api.active = [];
      api.products['p1'] = Product.fromJson(productJson(
        'p1',
        updatedAt: now.add(const Duration(minutes: 1)).toIso8601String(),
      ));
      await vm.refreshActive();

      final stale = Product.fromJson(
        productJson('p1', isDiscounted: true, discountedPrice: 80),
      );
      expect(vm.saleFor('p1'), isNull);
      expect(api.productRequests, 1);
      expect(vm.latest(stale).actualPrice, 100);
      expect(notified.last.actualPrice, 100);
      vm.dispose();
    });

    test('istek başarısızsa son liste korunur', () async {
      final api = FakeFlashApi()..active = [sale('p1', now: now)];
      final vm = FlashSaleViewModel(apiService: api);
      await vm.refreshActive();

      api.active = null; // ağ hatası
      await vm.refreshActive();

      expect(vm.saleFor('p1'), isNotNull);
      vm.dispose();
    });

    test('süresi dolmuş kayıt kampanya sayılmaz', () async {
      final api = FakeFlashApi()
        ..active = [sale('p1', now: now, left: const Duration(seconds: -5))];
      final vm = FlashSaleViewModel(apiService: api);
      await vm.refreshActive();

      expect(vm.activeFlashSales, isEmpty);
      vm.dispose();
    });
  });
}
