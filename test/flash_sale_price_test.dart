// Flash sale fiyat düzeltmesi: actualPrice, ürünün flashSale özeti, sunucu
// saati, liste yenileme ve `/flash-sales/active` + `/cart` yanıtlarının
// okunması.

import 'package:benimmarketim_app/models/flash_sale.dart';
import 'package:benimmarketim_app/models/home_feed.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/services/server_clock.dart';
import 'package:benimmarketim_app/viewmodels/category_products_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/flash_sale_viewmodel.dart';
import 'package:benimmarketim_app/viewmodels/home_page_viewmodel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/orders_test_utils.dart' show FakeHttpAdapter;

String _iso(DateTime value) => value.toUtc().toIso8601String();

Map<String, dynamic> productJson(
  String id, {
  double price = 100,
  double? actualPrice,
  bool isDiscounted = false,
  double? discountedPrice,
  DateTime? updatedAt,
  Map<String, dynamic>? flashSale,
}) =>
    {
      '_id': id,
      'name': 'Ürün $id',
      'price': price,
      if (actualPrice != null) 'actualPrice': actualPrice,
      'isDiscounted': isDiscounted,
      'discountedPrice': discountedPrice,
      'category': 'atistirma',
      'createdAt': '2026-09-01T10:00:00Z',
      'updatedAt': _iso(updatedAt ?? DateTime.utc(2026, 10, 1, 10)),
      if (flashSale != null) 'flashSale': flashSale,
    };

Map<String, dynamic> flashInfo({
  required DateTime start,
  required DateTime end,
  String id = 's1',
  double percent = 25,
  double price = 75,
  String idKey = '_id',
}) =>
    {
      idKey: id,
      'discountPercentage': percent,
      'price': price,
      'startDate': _iso(start),
      'endDate': _iso(end),
    };

/// Ürünü flash sale'de (%25, 75 TL) olan ürün.
Product flashProduct(
  String id, {
  required DateTime start,
  required DateTime end,
  DateTime? updatedAt,
}) =>
    Product.fromJson(productJson(
      id,
      actualPrice: 75,
      isDiscounted: true,
      discountedPrice: 75,
      updatedAt: updatedAt,
      flashSale: flashInfo(start: start, end: end),
    ));

FlashSale activeSale(
  String productId, {
  required DateTime start,
  required DateTime end,
  DateTime? productUpdatedAt,
  String id = 's1',
}) =>
    FlashSale.fromJson({
      '_id': id,
      'discountPercentage': 25,
      'startDate': _iso(start),
      'endDate': _iso(end),
      'isActive': true,
      'product': productJson(
        productId,
        actualPrice: 75,
        isDiscounted: true,
        discountedPrice: 75,
        updatedAt: productUpdatedAt ?? start,
      ),
    });

class FakeFlashApi extends ApiService {
  List<FlashSale>? active = [];
  DateTime? serverTime;
  final Map<String, Product> products = {};

  @override
  Future<ActiveFlashSales?> getActiveFlashSales() async {
    final sales = active;
    return sales == null
        ? null
        : ActiveFlashSales(sales, serverTime: serverTime);
  }

  @override
  Future<Product> getProductById(String id) async => products[id]!;
}

class FakeHomeApi extends ApiService {
  int feedCalls = 0;

  @override
  Future<HomeFeed?> getHomeFeed({String? deliveryPoint, int limit = 24}) async {
    feedCalls++;
    return HomeFeed(
      deals: const [],
      forYou: const [],
      popular: [Product.fromJson(productJson('p1'))],
      strategy: 'popular',
    );
  }
}

class FakeCategoryApi extends ApiService {
  int calls = 0;

  @override
  Future<List<Product>> getProducts({
    String? category,
    int? limit,
    int? page,
    bool cardFields = false,
  }) async {
    calls++;
    return [Product.fromJson(productJson('p1'))];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ürün fiyatı (actualPrice)', () {
    test('gösterilen fiyat actualPrice: haftalık fırsat daha düşükse o', () {
      final p = Product.fromJson(productJson(
        'p1',
        actualPrice: 70,
        isDiscounted: true,
        discountedPrice: 90,
      ));
      expect(p.actualPrice, 70);
      expect(p.isDiscounted, isTrue);
      expect(p.flashSale, isNull);
    });

    test('flashSale özeti okunur ve önbelleğe yazılıp aynen geri okunur', () {
      final start = DateTime.utc(2026, 10, 25, 9);
      final end = DateTime.utc(2026, 10, 25, 18);
      final p = flashProduct('p1', start: start, end: end);
      expect(p.flashSale!.id, 's1');
      expect(p.flashSale!.discountPercentage, 25);
      expect(p.flashSale!.price, 75);
      expect(p.flashSale!.endDate, end);

      final restored = Product.fromJson(p.toJson());
      expect(restored.flashSale!.id, 's1');
      expect(restored.flashSale!.startDate, start);
      expect(restored.flashSale!.endDate, end);
      expect(restored.actualPrice, 75);
    });

    test("/flash-sales/active içindeki ham özet ('sale' alanı) okunur", () {
      final info = ProductFlashSale.tryParse(flashInfo(
        start: DateTime.utc(2026, 10, 25, 9),
        end: DateTime.utc(2026, 10, 25, 18),
        id: 'abc',
        idKey: 'sale',
      ));
      expect(info!.id, 'abc');
      expect(ProductFlashSale.tryParse({'discountPercentage': 10}), isNull);
    });

    test('FlashSale.flashPrice ürünün actualPrice değeridir', () {
      final now = DateTime.now();
      final sale = FlashSale.fromJson({
        '_id': 's1',
        'discountPercentage': 20,
        'startDate': _iso(now.subtract(const Duration(hours: 1))),
        'endDate': _iso(now.add(const Duration(hours: 1))),
        'product': productJson('p1', actualPrice: 70),
      });
      // %20 indirim 80 TL ederdi; sipariş fiyatı (haftalık) 70 TL
      expect(sale.flashPrice, 70);
      expect(sale.discountedPrice, 70);
    });
  });

  group('ServerClock', () {
    test('fark sunucu saati − telefon saatidir; belirgin değişimde haber verir',
        () {
      final device = DateTime.utc(2026, 10, 25, 12);
      final clock = ServerClock(deviceClock: () => device);
      var notified = 0;
      clock.addListener(() => notified++);

      clock.sync(device.add(const Duration(hours: 3)));
      expect(clock.offset, const Duration(hours: 3));
      expect(clock.now(), device.add(const Duration(hours: 3)));
      expect(clock.isSynced, isTrue);
      expect(notified, 1);

      // Yarım saniyelik oynama yeniden çizdirmez
      clock.sync(device.add(const Duration(hours: 3, milliseconds: 500)));
      expect(notified, 1);
    });
  });

  group('FlashSaleViewModel', () {
    test('ayarlar: yoklama 60 sn, bitiş payı 15 sn', () {
      expect(FlashSaleViewModel.pollInterval, const Duration(seconds: 60));
      expect(FlashSaleViewModel.endGrace, const Duration(seconds: 15));
    });

    test('rozet ürünün flashSale alanından gelir (aktif listeye bakmadan)',
        () async {
      final now = DateTime.now();
      final api = FakeFlashApi(); // aktif liste boş
      final vm = FlashSaleViewModel(apiService: api, clock: () => now);
      await vm.refreshActive();

      final product = flashProduct(
        'p1',
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 2)),
      );
      final sale = vm.saleOf(product);
      expect(sale, isNotNull);
      expect(sale!.discountPercentage, 25);
      expect(sale.endDate, product.flashSale!.endDate);
      expect(sale.flashPrice, 75);
      vm.dispose();
    });

    test('süresi (sunucu saatine göre) dolmuş özet rozet göstermez', () async {
      final now = DateTime.now();
      final vm = FlashSaleViewModel(apiService: FakeFlashApi(), clock: () => now);
      final product = flashProduct(
        'p1',
        start: now.subtract(const Duration(hours: 2)),
        end: now.subtract(const Duration(seconds: 1)),
      );
      expect(vm.saleOf(product), isNull);
      vm.dispose();
    });

    test('telefonun saati yanlışken satış sunucu saatine göre görünür',
        () async {
      final server = DateTime.now();
      for (final skew in const [Duration(hours: -3), Duration(hours: 3)]) {
        final device = server.add(skew);
        final api = FakeFlashApi()
          ..serverTime = server
          ..active = [
            activeSale(
              'p1',
              start: server.subtract(const Duration(minutes: 10)),
              end: server.add(const Duration(minutes: 30)),
            ),
          ];
        final vm = FlashSaleViewModel(apiService: api, clock: () => device);
        await vm.refreshActive();

        expect(vm.activeFlashSales, hasLength(1), reason: 'kayma: $skew');
        expect(vm.serverNow.difference(server).inSeconds.abs(), lessThan(2));
        final product = flashProduct(
          'p2',
          start: server.subtract(const Duration(minutes: 10)),
          end: server.add(const Duration(minutes: 30)),
        );
        expect(vm.saleOf(product), isNotNull, reason: 'kayma: $skew');
        vm.dispose();
      }
    });

    test('kampanya bitince alınmış (daha yeni) ürün eski kaydı geçersiz kılar',
        () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 1));
      final api = FakeFlashApi()
        ..active = [
          activeSale('p1', start: start, end: now.add(const Duration(hours: 1))),
        ];
      final vm = FlashSaleViewModel(apiService: api, clock: () => now);
      await vm.refreshActive();

      // İptal edilip geri alınmış ürün: flashSale yok, kayıttan yeni
      final released = Product.fromJson(productJson(
        'p1',
        actualPrice: 100,
        updatedAt: start.add(const Duration(minutes: 5)),
      ));
      expect(vm.saleOf(released), isNull);
      expect(vm.latest(released).actualPrice, 100);

      // Eski (kampanyadan önce kaydedilmiş) liste ürünü: kampanya kaydı geçerli
      final cached = Product.fromJson(productJson(
        'p1',
        updatedAt: start.subtract(const Duration(days: 1)),
      ));
      expect(vm.saleOf(cached), isNotNull);
      expect(vm.latest(cached).actualPrice, 75);
      vm.dispose();
    });

    test('ürün sayfasında alınan güncel ürün kartlara da yansır', () async {
      final now = DateTime.now();
      final vm = FlashSaleViewModel(apiService: FakeFlashApi(), clock: () => now);
      final listed = Product.fromJson(productJson('p1'));
      final fresh = flashProduct(
        'p1',
        start: now.subtract(const Duration(minutes: 1)),
        end: now.add(const Duration(hours: 1)),
        updatedAt: now,
      );
      var notified = 0;
      vm.addListener(() => notified++);

      vm.rememberProduct(fresh);
      vm.rememberProduct(fresh); // aynı sürüm tekrar bildirmez

      expect(notified, 1);
      expect(vm.latest(listed).actualPrice, 75);
      expect(vm.saleOf(listed), isNotNull);
      vm.dispose();
    });

    test(
        'kampanya başlayınca ve bitince liste dinleyicisi çağrılır, '
        'ilk okumada çağrılmaz', () async {
      final now = DateTime.now();
      final api = FakeFlashApi()
        ..active = [
          activeSale('p1',
              start: now.subtract(const Duration(hours: 1)),
              end: now.add(const Duration(hours: 1))),
        ];
      final vm = FlashSaleViewModel(apiService: api, clock: () => now);
      var catalogChanges = 0;
      vm.addCatalogChangeListener(() => catalogChanges++);

      await vm.refreshActive(); // ilk okuma
      expect(catalogChanges, 0);

      await vm.refreshActive(); // değişiklik yok
      expect(catalogChanges, 0);

      // Yeni kampanya başladı
      api.active = [
        ...api.active!,
        activeSale('p2',
            id: 's2',
            start: now.subtract(const Duration(minutes: 1)),
            end: now.add(const Duration(hours: 1))),
      ];
      await vm.refreshActive();
      expect(catalogChanges, 1);

      // İlk kampanya bitti (iptal edildi)
      api.products['p1'] = Product.fromJson(productJson(
        'p1',
        updatedAt: now.add(const Duration(seconds: 1)),
      ));
      api.active = [api.active!.last];
      await vm.refreshActive();
      expect(catalogChanges, 2);
      vm.dispose();
    });
  });

  group('Liste yenileme', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ana sayfa: 1 dk\'dan uzun arka planda kalınca öne gelişte yenilenir',
        () async {
      var now = DateTime(2026, 10, 25, 12);
      final api = FakeHomeApi();
      final vm = HomePageViewModel(apiService: api, clock: () => now);
      await vm.refreshProducts();
      expect(api.feedCalls, 1);

      // 30 sn arka plan, raflar 2 dk'dan yeni: yenilenmez
      vm.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 30));
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(api.feedCalls, 1);

      // 90 sn arka plan: yenilenir
      vm.didChangeAppLifecycleState(AppLifecycleState.hidden);
      vm.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 90));
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(api.feedCalls, 2);

      // Arka plana gitmeden ama raflar 2 dk'dan eski: yenilenir
      now = now.add(const Duration(minutes: 2, seconds: 1));
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(api.feedCalls, 3);
      vm.dispose();
    });

    test('kategori: bellek önbelleği temizlenince açık kategori yenilenir',
        () async {
      final api = FakeCategoryApi();
      final vm = CategoryProductsViewModel(apiService: api);
      await vm.loadCategoryProducts('atistirma');
      final afterLoad = api.calls;

      // Bellekte taze: tekrar girişte ağa gidilmez
      await vm.loadCategoryProducts('atistirma');
      expect(api.calls, afterLoad);

      vm.clearMemoryCache();
      await pumpEventQueue();
      expect(api.calls, afterLoad + 1);
      expect(vm.products, hasLength(1));
    });
  });

  group('ApiService yanıtları', () {
    test('/flash-sales/active: serverTime ve ürünün actualPrice değeri okunur',
        () async {
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({
        'GET /flash-sales/active': (_) => {
              'serverTime': '2026-10-25T12:00:00.000Z',
              'flashSales': [
                {
                  '_id': 's1',
                  'discountPercentage': 25,
                  'startDate': '2026-10-25T10:00:00.000Z',
                  'endDate': '2026-10-25T14:00:00.000Z',
                  'isActive': true,
                  'product': productJson('p1',
                      actualPrice: 75, isDiscounted: true, discountedPrice: 75),
                },
              ],
            },
      }));
      final result = await ApiService().getActiveFlashSales();
      expect(result!.serverTime, DateTime.utc(2026, 10, 25, 12));
      expect(result.sales.single.flashPrice, 75);
    });

    test('/cart: liste fiyatı originalPrice, sipariş fiyatı actualPrice',
        () async {
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({
        'GET /cart': (_) => [
              {
                ...productJson('p1', price: 75, isDiscounted: true,
                    discountedPrice: 75),
                'originalPrice': 100,
                'actualPrice': 75,
                'quantity': 2,
                'flashSale': flashInfo(
                  start: DateTime.utc(2026, 10, 25, 10),
                  end: DateTime.utc(2026, 10, 25, 14),
                  idKey: 'sale',
                ),
              },
            ],
      }));
      final products = await ApiService().getCartProducts();
      final p1 = products!['p1']!;
      expect(p1.price, 100);
      expect(p1.actualPrice, 75);
      expect(p1.isDiscounted, isTrue);
      // Ham (süzülmemiş) özet alınmaz
      expect(p1.flashSale, isNull);
    });

    test('/cart isteği başarısızsa null döner', () async {
      ApiService.debugUseHttpAdapter(FakeHttpAdapter({}));
      expect(await ApiService().getCartProducts(), isNull);
    });
  });
}
