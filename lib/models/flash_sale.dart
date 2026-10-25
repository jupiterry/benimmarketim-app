import '../services/server_clock.dart';
import 'product.dart';

/// `/flash-sales/active` yanıtı: süren kampanyalar ve yanıtın üretildiği
/// sunucu saati (eski sunucuda yoksa null).
class ActiveFlashSales {
  final List<FlashSale> sales;
  final DateTime? serverTime;

  const ActiveFlashSales(this.sales, {this.serverTime});
}

class FlashSale {
  final String id;
  final String productId;
  final String name;
  final double discountPercentage;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Product product;

  FlashSale({
    required this.id,
    required this.productId,
    required this.name,
    required this.discountPercentage,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.product,
  });

  factory FlashSale.fromJson(Map<String, dynamic> json) {
    // Backend 'product' alanını bazen dolu nesne, bazen yalnızca ID olarak
    // döndürür; ikisi de desteklenir.
    final rawProduct = json['product'];
    final productJson = rawProduct is Map
        ? Map<String, dynamic>.from(rawProduct)
        : <String, dynamic>{};
    final productId = rawProduct is Map
        ? (rawProduct['_id'] ?? '').toString()
        : (rawProduct ?? json['productId'] ?? '').toString();

    return FlashSale(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      productId: productId,
      name: json['name'] ?? '',
      discountPercentage: (json['discountPercentage'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      product: Product.fromJson(productJson),
    );
  }

  /// Ürün yanıtındaki `flashSale` özetinden kampanya (rozet ve geri sayım
  /// için; `/flash-sales/active` listesine bakmadan).
  factory FlashSale.fromProduct(Product product, ProductFlashSale info) {
    return FlashSale(
      id: info.id,
      productId: product.id,
      name: '',
      discountPercentage: info.discountPercentage,
      // Başlangıç gelmediyse kampanya şimdi başlamış sayılır
      startDate: info.startDate ?? ServerClock.instance.now(),
      endDate: info.endDate,
      isActive: true,
      product: product,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'productId': productId,
      'name': name,
      'discountPercentage': discountPercentage,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'product': product.toJson(),
    };
  }

  // Kalan süre (sunucu saatine göre; telefonun saati yanlış olabilir)
  Duration get remainingTime {
    final now = ServerClock.instance.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }

  // Aktif mi kontrolü (sunucu saatine göre)
  bool get isCurrentlyActive => isLiveAt(ServerClock.instance.now());

  /// Sunucudaki `isLive` ile aynı: başlamış, bitmemiş ve kapatılmamış.
  /// [now] sunucu saati olmalı ([ServerClock.now]).
  bool isLiveAt(DateTime now) =>
      isActive && !startDate.isAfter(now) && endDate.isAfter(now);

  /// Kampanya fiyatı: siparişte alınacak fiyat, yani ürünün `actualPrice`
  /// değeri (sunucu indirimi ürüne uygulayıp bu alanı hesaplar).
  double get flashPrice => product.actualPrice;

  // İndirimli fiyat (eski ad; [flashPrice] ile aynı)
  double get discountedPrice => flashPrice;

  // Kalan süre string formatı
  String get remainingTimeString {
    final remaining = remainingTime;

    if (remaining.isNegative) {
      return 'Süresi Doldu';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
