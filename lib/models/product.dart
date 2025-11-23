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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] ?? 0.0).toDouble();
    final discountedPrice = json['discountedPrice']?.toDouble();
    final isDiscounted = json['isDiscounted'] ?? false;
    
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: price,
      originalPrice: isDiscounted && discountedPrice != null ? price : price,
      actualPrice: isDiscounted && discountedPrice != null ? discountedPrice : price,
      image: json['image'] ?? '',
      category: json['category'] ?? '',
      categoryId: json['categoryId'] ?? json['category'] ?? '',
      isDiscounted: isDiscounted,
      discountedPrice: discountedPrice,
      isOutOfStock: json['isOutOfStock'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      isHidden: json['isHidden'] ?? false,
      order: json['order'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'category': category,
      'isDiscounted': isDiscounted,
      'discountedPrice': discountedPrice,
      'isOutOfStock': isOutOfStock,
      'isFeatured': isFeatured,
      'isHidden': isHidden,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  
  // İndirim yüzdesi hesapla
  double get discountPercentage {
    if (!isDiscounted || discountedPrice == null) return 0.0;
    return ((price - discountedPrice!) / price * 100).roundToDouble();
  }
}
