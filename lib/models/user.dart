class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String role; // 'user' veya 'admin'
  final DateTime createdAt;
  /// Profil fotoğrafı URL'si (yoksa null; baş harfler gösterilir)
  final String? avatar;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    required this.role,
    required this.createdAt,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      address: json['address'],
      role: json['role'] ?? 'user',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      avatar: (json['avatar'] is String && (json['avatar'] as String).isNotEmpty)
          ? json['avatar'] as String
          : null,
    );
  }

  User copyWith({
    String? name,
    String? phone,
    String? address,
    String? avatar,
    bool clearAvatar = false,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role,
      createdAt: createdAt,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'avatar': avatar,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;
  final String deviceType;

  LoginRequest({
    required this.email,
    required this.password,
    this.deviceType = 'mobile', // API dökümanına göre varsayılan 'mobile'
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'deviceType': deviceType,
    };
  }
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String phone;
  final String deviceType;
  final String? referralCode;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    this.deviceType = 'mobile', // API dökümanına göre varsayılan 'mobile'
    this.referralCode,
  });

  Map<String, dynamic> toJson() {
    final data = {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'deviceType': deviceType,
    };
    if (referralCode != null && referralCode!.isNotEmpty) {
      data['referralCode'] = referralCode!;
    }
    return data;
  }
}

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;
  final String? referralCoupon; // Referral ile kayıt olunduğunda dönen kupon kodu

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.referralCoupon,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Sunucu kullanıcı alanlarını üst düzeyde döndürür ({_id, name, ...,
    // accessToken}); eski `user` sarmalayıcısı da desteklenir.
    final rawUser =
        json['user'] ?? (json['_id'] != null ? json : (json['data']?['user'] ?? {}));
    return AuthResponse(
      user: User.fromJson(Map<String, dynamic>.from(rawUser as Map)),
      accessToken: json['accessToken'] ?? json['token'] ?? json['data']?['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? json['data']?['refreshToken'] ?? '',
      referralCoupon: json['referralCoupon'],
    );
  }
}
