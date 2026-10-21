import 'product.dart';

/// Ana sayfa rafları tek istekte: `GET /products/home-feed`.
///
/// - [deals]: indirimli ürünler (flash sale hariç), sunucunun sıralamasıyla.
/// - [forYou]: giriş yapmış ve geçmişi olan kullanıcıya kişisel öneriler,
///   diğerlerine popüler ürünler ([strategy] hangisi olduğunu söyler).
/// - [popular]: son günlerde çok satanlar (misafir için de dolu gelir).
class HomeFeed {
  final List<Product> deals;
  final List<Product> forYou;
  final List<Product> popular;
  final String strategy;

  const HomeFeed({
    required this.deals,
    required this.forYou,
    required this.popular,
    required this.strategy,
  });

  bool get isPersonal => strategy == 'personal';

  bool get isEmpty => deals.isEmpty && forYou.isEmpty && popular.isEmpty;

  static List<Product> _products(Object? raw) {
    if (raw is! List) return const [];
    final products = <Product>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final product = Product.fromJson(Map<String, dynamic>.from(item));
        if (product.id.isNotEmpty && !product.isHidden) products.add(product);
      } catch (_) {
        // Bozuk tek kayıt rafı düşürmez
      }
    }
    return products;
  }

  /// Raf hem `{"products": [...]}` nesnesi hem de doğrudan liste olabilir.
  static List<Product> _shelf(Object? raw) =>
      _products(raw is Map ? raw['products'] : raw);

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final shelves = json['shelves'] is Map
        ? Map<String, dynamic>.from(json['shelves'] as Map)
        : json;
    final forYou = shelves['forYou'];
    final strategy = (forYou is Map ? forYou['strategy'] : null) ??
        json['strategy'] ??
        'popular';
    return HomeFeed(
      deals: _shelf(shelves['deals']),
      forYou: _shelf(forYou),
      popular: _shelf(shelves['popular']),
      strategy: strategy.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'shelves': {
          'deals': {'products': deals.map((p) => p.toJson()).toList()},
          'forYou': {
            'strategy': strategy,
            'products': forYou.map((p) => p.toJson()).toList(),
          },
          'popular': {'products': popular.map((p) => p.toJson()).toList()},
        },
      };
}
