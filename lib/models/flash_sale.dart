import 'product.dart';

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
    return FlashSale(
      id: json['_id'] ?? '',
      productId: json['product'] ?? '',
      name: json['name'] ?? '',
      discountPercentage: (json['discountPercentage'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      product: Product.fromJson(json['product'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'product': productId,
      'name': name,
      'discountPercentage': discountPercentage,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'product': product.toJson(),
    };
  }

  // Kalan süre hesaplama
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }

  // Aktif mi kontrolü
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate) && isActive;
  }

  // İndirimli fiyat hesaplama
  double get discountedPrice {
    return product.price * (1 - discountPercentage / 100);
  }

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
