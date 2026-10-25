class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final double actualPrice;
  final String image;
  final String category;
  final String categoryId;
  final bool isDiscounted;
  final double? discountedPrice;
  final bool isOutOfStock;
  final bool isFeatured;
  final bool isHidden;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Fiyatı belirleyen indirim süren bir flash sale ise sunucunun verdiği
  /// özet (rozet ve geri sayım bundan gösterilir); yoksa null.
  final ProductFlashSale? flashSale;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.actualPrice,
    required this.image,
    required this.category,
    required this.categoryId,
    required this.isDiscounted,
    this.discountedPrice,
    required this.isOutOfStock,
    required this.isFeatured,
    required this.isHidden,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.flashSale,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] ?? 0.0).toDouble();
    final apiActualPrice = (json['actualPrice'] as num?)?.toDouble();
    final rawDiscountedPrice = (json['discountedPrice'] as num?)?.toDouble();
    // Sunucu (sipariş fiyatı) ile aynı kural: indirim yalnızca isDiscounted
    // açıkken ve indirimli fiyat normal fiyattan düşükken geçerlidir. Panelde
    // kapatılmış ama alanı temizlenmemiş bir indirim uygulamada da görünmez.
    final serverDiscountedPrice = json['isDiscounted'] == true &&
            rawDiscountedPrice != null &&
            rawDiscountedPrice >= 0 &&
            rawDiscountedPrice < price
        ? rawDiscountedPrice
        : null;
    final actualPrice = apiActualPrice ?? serverDiscountedPrice ?? price;
    final isDiscounted = actualPrice < price;
    final discountedPrice = isDiscounted ? actualPrice : null;

    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: price,
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? price,
      actualPrice: actualPrice,
      image: json['image'] ?? '',
      category: json['category'] ?? '',
      categoryId: json['categoryId'] ?? json['category'] ?? '',
      isDiscounted: isDiscounted,
      discountedPrice: discountedPrice,
      isOutOfStock: json['isOutOfStock'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      isHidden: json['isHidden'] ?? false,
      order: json['order'] ?? 0,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      flashSale: ProductFlashSale.tryParse(json['flashSale']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'actualPrice': actualPrice,
      'image': image,
      'category': category,
      'categoryId': categoryId,
      'isDiscounted': isDiscounted,
      'discountedPrice': discountedPrice,
      'isOutOfStock': isOutOfStock,
      'isFeatured': isFeatured,
      'isHidden': isHidden,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (flashSale != null) 'flashSale': flashSale!.toJson(),
    };
  }

  // İndirim yüzdesi hesapla
  double get discountPercentage {
    if (!isDiscounted || discountedPrice == null || price <= 0) return 0.0;
    return ((price - discountedPrice!) / price * 100).roundToDouble();
  }
}

/// Ürün yanıtındaki `flashSale` özeti:
/// `{ _id, discountPercentage, price, startDate, endDate }`.
///
/// Sunucu bu alanı yalnızca kampanya sürerken ve fiyatı gerçekten belirleyen
/// indirim oyken gönderir. `/flash-sales/active` içindeki ham üründe kimlik
/// `sale` alanındadır; ikisi de okunur.
class ProductFlashSale {
  final String id;
  final double discountPercentage;

  /// Kampanya fiyatı (ürünün `actualPrice` değeriyle aynıdır).
  final double price;
  final DateTime? startDate;
  final DateTime endDate;

  const ProductFlashSale({
    required this.id,
    required this.discountPercentage,
    required this.price,
    this.startDate,
    required this.endDate,
  });

  /// Alan yoksa ya da bitiş tarihi okunamıyorsa null.
  static ProductFlashSale? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final end = DateTime.tryParse('${raw['endDate'] ?? ''}');
    if (end == null) return null;
    final start = raw['startDate'] == null
        ? null
        : DateTime.tryParse('${raw['startDate']}');
    return ProductFlashSale(
      id: (raw['_id'] ?? raw['sale'] ?? raw['id'] ?? '').toString(),
      discountPercentage: (raw['discountPercentage'] as num?)?.toDouble() ?? 0,
      price: (raw['price'] as num?)?.toDouble() ?? 0,
      startDate: start,
      endDate: end,
    );
  }

  /// [now] anında sürüyor mu (sunucu saatiyle sorulmalı).
  bool isLiveAt(DateTime now) =>
      (startDate == null || !startDate!.isAfter(now)) && endDate.isAfter(now);

  Map<String, dynamic> toJson() => {
        '_id': id,
        'discountPercentage': discountPercentage,
        'price': price,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
}
