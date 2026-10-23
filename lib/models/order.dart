import 'delivery.dart';

/// Sipariş ödeme yöntemi. Sunucu anahtarları: cash, card, bank_transfer.
enum PaymentMethod {
  cash('cash', 'Kapıda nakit', 'Teslimatta nakit ödersin'),
  card('card', 'Kapıda kart (POS)', 'Teslimatta POS cihazıyla kartla ödersin'),
  bankTransfer('bank_transfer', 'Havale / EFT', 'Sipariş sonrası hesabımıza gönderirsin');

  const PaymentMethod(this.key, this.label, this.description);

  /// Sunucuya gönderilen ve sunucudan gelen anahtar
  final String key;
  final String label;
  final String description;

  /// Mobilde sipariş verirken seçilebilen yöntemler: yalnızca kapıda ödeme.
  /// Havale/EFT yeni siparişte sunulmaz; eski siparişlerin doğru
  /// görünmesi için enum değeri korunur.
  static const List<PaymentMethod> selectable = [cash, card];

  static PaymentMethod? fromKey(Object? value) {
    if (value is! String) return null;
    for (final method in PaymentMethod.values) {
      if (method.key == value) return method;
    }
    return null;
  }
}

class Order {
  final String id;
  final String userId;
  final List<OrderProduct> products;
  final double totalAmount;
  final String
      status; // 'Hazırlanıyor', 'Yolda', 'Teslim Edildi', 'İptal Edildi'
  final String note;
  final String city;
  final String deliveryPoint;
  final String deliveryPointName;
  final String phone;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Kupon bilgileri (sunucu: couponCode, couponDiscount, subtotalAmount)
  final String? couponCode;
  final double couponDiscount;
  /// İndirim öncesi ara toplam (kupon yoksa 0 gelebilir)
  final double subtotalAmount;
  /// Ödeme yöntemi; bu özellikten önce verilen siparişlerde null
  final PaymentMethod? paymentMethod;

  // Adrese teslimat (eski siparişlerde varsayılanlar: noktaya teslim, ücret 0)
  /// "point" (yurt) | "address"
  final String deliveryType;
  final OrderDeliveryZone? deliveryZone;

  /// Adresli siparişte teslimat adresi; diğerlerinde null
  final AddressFields? deliveryAddress;

  /// Teslimat ücreti (TL), 0 = ücretsiz
  final double deliveryFee;

  /// Ürün tutarı − kupon, teslimat hariç. Sunucu göndermediyse null.
  final double? productTotal;

  /// Mağaza siparişi teyit etmek için arayacak
  final bool needsCallback;
  final DateTime? callbackConfirmedAt;

  /// Teslim edilemediyse nedeni ("Teslim edilemedi: Adres bulunamadı")
  final String deliveryOutcomeLabel;

  /// Müşteri iptal ettiyse nedeni
  final String cancelReasonLabel;
  final String cancelReasonNote;

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
    this.couponCode,
    this.couponDiscount = 0,
    this.subtotalAmount = 0,
    this.paymentMethod,
    this.deliveryType = 'point',
    this.deliveryZone,
    this.deliveryAddress,
    this.deliveryFee = 0,
    this.productTotal,
    this.needsCallback = false,
    this.callbackConfirmedAt,
    this.deliveryOutcomeLabel = '',
    this.cancelReasonLabel = '',
    this.cancelReasonNote = '',
  });

  bool get isAddressDelivery => deliveryType == 'address';

  /// Teyit araması bekleniyor
  bool get awaitingCallback => needsCallback && callbackConfirmedAt == null;

  /// Ürün tutarı (kupon düşülmüş, teslimat hariç)
  double get productTotalOrDerived =>
      productTotal ?? (totalAmount - deliveryFee).clamp(0, double.infinity);

  /// Kupon uygulandıysa indirim satırı gösterilir
  bool get hasDiscount => couponDiscount > 0;

  /// İndirim öncesi tutar: sunucu göndermediyse toplam + indirim
  double get subtotalOrDerived =>
      subtotalAmount > 0 ? subtotalAmount : totalAmount + couponDiscount;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: (json['_id'] ?? json['id'] ?? json['orderId'] ?? '').toString(),
      userId: json['userId'] ?? '',
      products: (json['products'] as List<dynamic>?)
              ?.map((product) => OrderProduct.fromJson(product))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'Hazırlanıyor',
      note: json['note'] ?? '',
      city: json['city'] ?? 'Zonguldak',
      deliveryPoint: json['deliveryPoint'] ?? '',
      deliveryPointName: json['deliveryPointName'] ?? '',
      phone: json['phone'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      couponCode: json['couponCode'] is String && (json['couponCode'] as String).isNotEmpty
          ? json['couponCode'] as String
          : null,
      couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0,
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: PaymentMethod.fromKey(json['paymentMethod']),
      deliveryType: json['deliveryType'] == 'address' ? 'address' : 'point',
      deliveryZone: OrderDeliveryZone.fromJson(json['deliveryZone']),
      deliveryAddress: json['deliveryAddress'] is Map
          ? AddressFields.fromJson(
              Map<String, dynamic>.from(json['deliveryAddress'] as Map))
          : null,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
      productTotal: (json['productTotal'] as num?)?.toDouble(),
      needsCallback: json['needsCallback'] == true,
      callbackConfirmedAt: json['callbackConfirmedAt'] is String
          ? DateTime.tryParse(json['callbackConfirmedAt'] as String)
          : null,
      deliveryOutcomeLabel: (json['deliveryOutcomeLabel'] ?? '').toString(),
      cancelReasonLabel: (json['cancelReasonLabel'] ?? '').toString(),
      cancelReasonNote: (json['cancelReasonNote'] ?? '').toString(),
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
      'couponCode': couponCode,
      'couponDiscount': couponDiscount,
      'subtotalAmount': subtotalAmount,
      'paymentMethod': paymentMethod?.key,
      'deliveryType': deliveryType,
      'deliveryZone': deliveryZone?.toJson(),
      'deliveryAddress': deliveryAddress?.toJson(),
      'deliveryFee': deliveryFee,
      'productTotal': productTotal,
      'needsCallback': needsCallback,
      'callbackConfirmedAt': callbackConfirmedAt?.toIso8601String(),
      'deliveryOutcomeLabel': deliveryOutcomeLabel,
      'cancelReasonLabel': cancelReasonLabel,
      'cancelReasonNote': cancelReasonNote,
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
  /// Ürün silinmişse veya eski backend sürümünde boş gelir.
  final String? productId;
  final String name;
  final int quantity;
  final double price;
  final String? image;

  OrderProduct({
    this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    final rawId = json['productId'];
    return OrderProduct(
      productId: rawId == null || rawId.toString().isEmpty
          ? null
          : rawId.toString(),
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
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
  /// Yurt akışı: 'girlsDorm' veya 'boysDorm'. Adres akışında boş.
  final String deliveryPoint;
  final String deliveryPointName;

  /// Adres akışı: kayıtlı adresin kimliği
  final String? addressId;

  /// Adres akışı (kayıtsız adres) ya da bölge olarak seçilen yurt
  final String? zoneId;

  /// Kayıtsız adresle siparişte adres alanları ([zoneId] ile birlikte)
  final AddressFields? deliveryAddress;
  final String note;
  final String? couponCode; // Kupon kodu
  final double? discountAmount; // İndirim miktarı
  final Map<String, dynamic>? device; // Cihaz bilgisi
  final PaymentMethod paymentMethod; // Zorunlu: nakit, kart (POS) ya da havale/EFT

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
    required this.paymentMethod,
    this.addressId,
    this.zoneId,
    this.deliveryAddress,
  });

  /// Adrese teslimat isteği mi (yurt akışı değil)
  bool get isAddressOrder =>
      (addressId != null && addressId!.isNotEmpty) || deliveryAddress != null;

  Map<String, dynamic> toJson() {
    if (isAddressOrder) {
      // Adres akışı: ücret ve toplamı sunucu hesaplar; yurt alanları gönderilmez.
      return {
        'paymentMethod': paymentMethod.key,
        'products': products,
        'phone': phone,
        'note': note,
        if (couponCode != null && couponCode!.isNotEmpty)
          'couponCode': couponCode,
        if (device != null) 'device': device,
        if (addressId != null && addressId!.isNotEmpty)
          'addressId': addressId
        else ...{
          'zoneId': zoneId,
          'deliveryAddress': deliveryAddress!.toJson(),
        },
      };
    }

    final Map<String, dynamic> json = {
      'paymentMethod': paymentMethod.key,
      'products': products,
      'totalAmount': totalAmount,
      'city': city,
      'phone': phone,
      'deliveryPoint': deliveryPoint,
      'deliveryPointName': deliveryPointName,
      'note': note,
      if (zoneId != null && zoneId!.isNotEmpty) 'zoneId': zoneId,
    };

    // Kupon bilgisi varsa ekle
    if (couponCode != null && couponCode!.isNotEmpty) {
      json['couponCode'] = couponCode!;
    }
    if (discountAmount != null && discountAmount! > 0) {
      json['couponDiscount'] =
          discountAmount!; // Backend 'couponDiscount' bekliyor
      json['subtotalAmount'] =
          totalAmount + discountAmount!; // İndirim öncesi ara toplam
    }

    // Cihaz bilgisi varsa ekle
    if (device != null) {
      json['device'] = device;
    }

    return json;
  }
}
