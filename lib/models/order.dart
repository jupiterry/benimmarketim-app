import 'product.dart';

class Order {
  final String id;
  final String userId;
  final List<OrderProduct> products;
  final double totalAmount;
  final String status; // 'Hazırlanıyor', 'Yolda', 'Teslim Edildi', 'İptal Edildi'
  final String note;
  final String city;
  final String deliveryPoint;
  final String deliveryPointName;
  final String phone;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.products,
    required this.totalAmount,
    required this.status,
    required this.note,
    required this.city,
    required this.deliveryPoint,
    required this.deliveryPointName,
    required this.phone,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      products: (json['products'] as List<dynamic>?)
          ?.map((product) => OrderProduct.fromJson(product))
          .toList() ?? [],
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'Hazırlanıyor',
      note: json['note'] ?? '',
      city: json['city'] ?? 'Zonguldak',
      deliveryPoint: json['deliveryPoint'] ?? '',
      deliveryPointName: json['deliveryPointName'] ?? '',
      phone: json['phone'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'products': products.map((product) => product.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'note': note,
      'city': city,
      'deliveryPoint': deliveryPoint,
      'deliveryPointName': deliveryPointName,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  double get totalPrice => price * quantity;
}

class OrderProduct {
  final String name;
  final int quantity;
  final double price;
  final String? image;

  OrderProduct({
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
    };
  }
}

class CreateOrderRequest {
  final List<Map<String, dynamic>> products;
  final double totalAmount;
  final String city;
  final String phone;
  final String deliveryPoint; // 'girlsDorm' veya 'boysDorm'
  final String deliveryPointName;
  final String note;
  final String? couponCode; // Kupon kodu
  final double? discountAmount; // İndirim miktarı
  final Map<String, dynamic>? device; // Cihaz bilgisi

  CreateOrderRequest({
    required this.products,
    required this.totalAmount,
    required this.city,
    required this.phone,
    required this.deliveryPoint,
    required this.deliveryPointName,
    required this.note,
    this.couponCode,
    this.discountAmount,
    this.device,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'products': products,
      'totalAmount': totalAmount,
      'city': city,
      'phone': phone,
      'deliveryPoint': deliveryPoint,
      'deliveryPointName': deliveryPointName,
      'note': note,
    };
    
    // Kupon bilgisi varsa ekle
    if (couponCode != null && couponCode!.isNotEmpty) {
      json['couponCode'] = couponCode!;
    }
    if (discountAmount != null && discountAmount! > 0) {
      json['couponDiscount'] = discountAmount!; // Backend 'couponDiscount' bekliyor
      json['subtotalAmount'] = totalAmount + discountAmount!; // İndirim öncesi ara toplam
    }
    
    // Cihaz bilgisi varsa ekle
    if (device != null) {
      json['device'] = device;
    }
    
    return json;
  }
}

