/// Coupon model for user's available coupons
class Coupon {
  final String id;
  final String code;
  final String description;
  final String discountType; // 'percentage' or 'fixed'
  final double? discountPercentage;
  final double? discountAmount;
  final double minimumOrderAmount;
  final double maximumDiscount;
  final DateTime expirationDate;
  final bool isReferralCoupon;
  final String? userId;
  final bool isUsed;

  Coupon({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    this.discountPercentage,
    this.discountAmount,
    required this.minimumOrderAmount,
    required this.maximumDiscount,
    required this.expirationDate,
    required this.isReferralCoupon,
    this.userId,
    this.isUsed = false,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      discountType: json['discountType'] ?? 'percentage',
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      maximumDiscount: (json['maximumDiscount'] as num?)?.toDouble() ?? 0,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'])
          : DateTime.now().add(const Duration(days: 7)),
      isReferralCoupon: json['isReferralCoupon'] ?? false,
      userId: json['userId'],
      isUsed: json['isUsed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountPercentage': discountPercentage,
      'discountAmount': discountAmount,
      'minimumOrderAmount': minimumOrderAmount,
      'maximumDiscount': maximumDiscount,
      'expirationDate': expirationDate.toIso8601String(),
      'isReferralCoupon': isReferralCoupon,
      'userId': userId,
      'isUsed': isUsed,
    };
  }

  /// Check if coupon is expired
  bool get isExpired => DateTime.now().isAfter(expirationDate);

  /// Check if coupon is valid for use
  bool get isValid => !isExpired && !isUsed;

  /// Get discount display text
  String get discountText {
    if (discountType == 'percentage' && discountPercentage != null) {
      return '%${discountPercentage!.toInt()} İndirim';
    } else if (discountAmount != null) {
      return '₺${discountAmount!.toStringAsFixed(0)} İndirim';
    }
    return 'İndirim';
  }

  /// Calculate discount for a given order amount
  double calculateDiscount(double orderAmount) {
    if (!isValid) return 0;
    if (orderAmount < minimumOrderAmount) return 0;

    double discount = 0;
    if (discountType == 'percentage' && discountPercentage != null) {
      discount = orderAmount * (discountPercentage! / 100);
    } else if (discountAmount != null) {
      discount = discountAmount!;
    }

    // Apply maximum discount cap
    if (maximumDiscount > 0 && discount > maximumDiscount) {
      discount = maximumDiscount;
    }

    return discount;
  }

  /// Get days until expiration
  int get daysUntilExpiration {
    final diff = expirationDate.difference(DateTime.now());
    return diff.inDays;
  }
}
