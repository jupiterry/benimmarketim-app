import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/product.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/category.dart' as models;
import '../models/flash_sale.dart';
import '../models/home_feed.dart';
import '../models/search_result.dart';
import '../models/banner.dart';
import '../models/referral.dart';
import '../models/coupon.dart';
import '../models/delivery.dart';
import 'token_manager.dart';
import 'app_logger.dart';
import 'socket_service.dart';

/// Sunucudan gelen anlaşılır hata (ör. "Sipariş saatleri dışında"). [message]
/// doğrudan kullanıcıya gösterilebilir; [statusCode] HTTP durum kodudur
/// (ağ hatasında null).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Sunucunun makine okunur hata kodu (ör. ZONE_CLOSED, BELOW_MINIMUM)
  final String? code;

  /// Hata yanıtının tamamı (ör. BELOW_MINIMUM → minimumOrderAmount)
  final Map<String, dynamic>? data;

  const ApiException(this.message, {this.statusCode, this.code, this.data});

  /// Dio hatasından sunucunun `{ error, message, code }` yanıtını okur.
  factory ApiException.fromDio(DioException e, String fallback) {
    final raw = e.response?.data;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final message = data?['message'];
    final code = data?['code'] ?? data?['error'];
    return ApiException(
      message is String && message.trim().isNotEmpty
          ? message.trim()
          : e.response == null
              ? 'Sunucuya bağlanılamıyor. İnternet bağlantını kontrol et.'
              : fallback,
      statusCode: e.response?.statusCode,
      code: code is String && code.isNotEmpty ? code : null,
      data: data,
    );
  }

  @override
  String toString() => message;
}

/// Geri bildirim gönderiminin sonucu
class FeedbackSubmitResult {
  /// Gönderilemediyse kullanıcıya gösterilecek mesaj
  final String? error;

  /// Düşük puan / 👎 / ürün sorunu sonrası açılan destek görüşmesi
  final String? supportChatId;

  const FeedbackSubmitResult({this.error, this.supportChatId});

  bool get ok => error == null;
}

class ApiService {
  // Gerçek API base URL'i
  static const String baseUrl = 'https://devrekbenimmarketim.com/api';

  // Tüm ApiService örnekleri aynı Dio'yu (bağlantı havuzu + interceptor)
  // paylaşır; böylece token yenileme tek noktadan yönetilir.
  static Dio? _sharedDio;

  // Aynı anda gelen 401'lerde refresh isteği yalnızca bir kez atılır.
  static Future<String?>? _refreshInFlight;

  // Token yenilenemeyip oturum düştüğünde yayınlanır; AuthViewModel dinler.
  static final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  /// Oturum sunucu tarafında geçersiz sayılıp token'lar silindiğinde tetiklenir.
  static Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  late final Dio _dio = _sharedDio ??= _createDio();

  /// Paylaşılan Dio (auth/refresh interceptor'ları dahil). Fotokopi gibi
  /// ayrı servisler kendi Dio'sunu kurmak yerine bunu kullanır.
  static Dio get sharedDio => _sharedDio ??= _createDio();

  /// Yalnızca testler/ekran görüntüleri için: ağ yerine sahte yanıt verir.
  @visibleForTesting
  static void debugUseHttpAdapter(HttpClientAdapter adapter) {
    _sharedDio = _createDio()..httpClientAdapter = adapter;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Sertifika doğrulaması platformun varsayılan CA zinciriyle yapılır.

    // Interceptor ekle (token için)
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Token varsa header'a ekle
          final token = await _getStoredToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Refresh uç noktasının kendisi 401 verdiyse döngüye girme;
            // temizlik ve oturum-düştü yayını özgün isteğin akışında yapılır.
            if (error.requestOptions.path.contains('/auth/refresh-token')) {
              AppLogger.debug('Refresh token geçersiz');
              handler.next(error);
              return;
            }

            // Misafir (token yok): yenilenecek/temizlenecek bir oturum yok.
            final storedToken = await _getStoredToken();
            if (storedToken == null || storedToken.isEmpty) {
              handler.next(error);
              return;
            }

            // Yenilenmiş token ile tekrar denenen istek yine 401 verdiyse
            // ikinci kez yenileme yapma (sonsuz döngü koruması).
            if (error.requestOptions.extra['tokenRetried'] == true) {
              await _clearStoredToken();
              _sessionExpiredController.add(null);
              handler.next(error);
              return;
            }

            AppLogger.debug('401 hatası - Token geçersiz, yenileniyor...');

            // Token yenilemeyi dene
            final newToken = await _refreshAccessToken(dio);
            if (newToken != null) {
              // Yeni token ile isteği tekrar dene
              final originalRequest = error.requestOptions;
              originalRequest.headers['Authorization'] = 'Bearer $newToken';
              originalRequest.extra['tokenRetried'] = true;

              try {
                final response = await dio.fetch(originalRequest);
                handler.resolve(response);
                return;
              } catch (e) {
                AppLogger.debug('Token yenilendikten sonra istek başarısız: $e');
                handler.next(error);
                return;
              }
            }

            // Token yenilenemedi: oturumu kapat ve dinleyenlere haber ver
            await _clearStoredToken();
            _sessionExpiredController.add(null);
          }
          handler.next(error);
        },
      ),
    );
    return dio;
  }

  static Future<String?> _getStoredToken() async {
    return await TokenManager.getAccessToken();
  }

  static Future<void> _clearStoredToken() async {
    await TokenManager.clearAllTokens();
    AppLogger.debug('Token temizlendi');
  }

  /// Eşzamanlı çağrılar aynı refresh isteğini bekler.
  static Future<String?> _refreshAccessToken(Dio dio) {
    return _refreshInFlight ??=
        _performRefresh(dio).whenComplete(() => _refreshInFlight = null);
  }

  static Future<String?> _performRefresh(Dio dio) async {
    try {
      AppLogger.debug('Token yenileniyor...');

      // Token yoksa yenileme yapma
      final currentToken = await _getStoredToken();
      if (currentToken == null) {
        AppLogger.debug('Token bulunamadı, yenileme yapılamıyor');
        return null;
      }

      final refreshToken = await TokenManager.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }

      final response = await dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['accessToken'];
        if (newToken is String && newToken.isNotEmpty) {
          await TokenManager.saveAccessToken(newToken);
          AppLogger.debug('Token başarıyla yenilendi');
          // Canlı sohbet soketi eski token ile kurulduysa yenisiyle bağlan
          SocketService.instance.reconnectWithToken(newToken);
          return newToken;
        }
      }

      return null;
    } catch (e) {
      AppLogger.debug('Token yenileme hatası: $e');
      return null;
    }
  }

  // Kullanıcı işlemleri
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());

      AppLogger.debug('Login Response Status: ${response.statusCode}');

      // Response null ise hata fırlat
      if (response.data is! Map) {
        throw const ApiException('API\'den yanıt alınamadı');
      }

      final authResponse =
          AuthResponse.fromJson(Map<String, dynamic>.from(response.data as Map));

      // Token kontrolü
      if (authResponse.accessToken.isEmpty) {
        throw const ApiException('Geçersiz token alındı');
      }

      await TokenManager.saveAccessToken(authResponse.accessToken);
      await TokenManager.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      AppLogger.debug('Login Error: $e');
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        throw const ApiException('E-posta veya şifre hatalı', statusCode: 400);
      }
      if (status == 429) {
        throw ApiException(
          _serverMessage(e) ??
              'Çok fazla deneme yaptınız. Lütfen biraz sonra tekrar deneyin.',
          statusCode: 429,
        );
      }
      if (status == 404) {
        throw const ApiException('Kullanıcı bulunamadı', statusCode: 404);
      }
      if (e.response == null) {
        throw const ApiException(
          'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.',
        );
      }
      throw ApiException(
        'Giriş yapılırken hata oluştu. Lütfen tekrar deneyin.',
        statusCode: status,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.debug('Login Error: $e');
      throw const ApiException(
        'Giriş yapılırken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Sunucu yanıtındaki `message` alanı (varsa).
  static String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    return null;
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    // Telefon numarası kontrolü
    if (request.phone.isEmpty) {
      throw const ApiException('Telefon numarası zorunludur');
    }

    try {
      final response = await _dio.post('/auth/signup', data: request.toJson());

      AppLogger.debug('Register Response Status: ${response.statusCode}');

      if (response.data is! Map) {
        throw const ApiException('API\'den yanıt alınamadı');
      }

      return AuthResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      AppLogger.debug('Register Error: $e');
      final status = e.response?.statusCode;
      final message = _serverMessage(e);
      if (status == 400) {
        throw ApiException(
          message ?? 'Bu e-posta adresi zaten kullanılıyor',
          statusCode: 400,
        );
      }
      if (status == 429) {
        throw ApiException(
          message ?? 'Çok fazla deneme yaptınız. Lütfen biraz sonra tekrar deneyin.',
          statusCode: 429,
        );
      }
      if (e.response == null) {
        throw const ApiException(
          'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.',
        );
      }
      throw ApiException(
        message ?? 'Kayıt olurken hata oluştu. Lütfen tekrar deneyin.',
        statusCode: status,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.debug('Register Error: $e');
      throw const ApiException(
        'Kayıt olurken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<User> getProfile() async {
    try {
      AppLogger.debug('getProfile: API çağrısı yapılıyor...');
      final response = await _dio.get('/auth/profile');
      AppLogger.debug('getProfile: Response status: ${response.statusCode}');

      // Response data'yı kontrol et
      Map<String, dynamic> userData;
      if (response.data is Map<String, dynamic>) {
        // Eğer data içinde user varsa onu kullan
        if (response.data.containsKey('user')) {
          userData = response.data['user'] as Map<String, dynamic>;
        } else if (response.data.containsKey('data')) {
          userData = response.data['data'] as Map<String, dynamic>;
        } else {
          userData = response.data as Map<String, dynamic>;
        }
      } else {
        throw Exception('Geçersiz response formatı');
      }

      final user = User.fromJson(userData);
      AppLogger.debug('getProfile: Kullanıcı yüklendi');
      return user;
    } on DioException catch (e) {
      AppLogger.debug('getProfile: Hata: $e');
      throw ApiException(
        _serverMessage(e) ?? 'Profil bilgileri alınırken hata oluştu.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.debug('getProfile: Hata: $e');
      throw ApiException('Profil bilgileri alınırken hata oluştu: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      AppLogger.debug('Logout API hatası: $e');
    } finally {
      // Her durumda token'ı temizle
      _clearStoredToken();
    }
  }

  // Hesap silme
  Future<void> deleteAccount() async {
    try {
      AppLogger.debug('Deleting account...');
      final response = await _dio.delete('/auth/delete-account');

      AppLogger.debug('Delete Account Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Başarılı, tokenları temizle
        await _clearStoredToken();
        return;
      }

      throw Exception('Hesap silinemedi');
    } catch (e) {
      AppLogger.debug('Delete Account Error: $e');
      throw Exception('Hesap silinirken bir hata oluştu: $e');
    }
  }

  // Token yenileme metodu (web projesindeki refresh token sistemi)
  Future<String?> refreshToken() => _refreshAccessToken(_dio);

  // ========================
  // PROFİL: TELEFON VE FOTOĞRAF
  // ========================

  /// Telefon numarasını günceller (biçim 05XXXXXXXXX). Sunucudaki kayıtlı
  /// numarayı döndürür; hata mesajı [ApiException] ile gelir.
  Future<String> updatePhone(String phone) async {
    try {
      final response =
          await _dio.put('/auth/update-phone', data: {'phone': phone});
      final data = response.data;
      if (data is Map && data['phone'] is String) {
        return data['phone'] as String;
      }
      return phone;
    } on DioException catch (e) {
      throw ApiException(
        _serverMessage(e) ?? 'Telefon numarası güncellenemedi.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Profil fotoğrafını yükler (JPEG/PNG/WebP baytları, en fazla 5 MB).
  /// Yeni fotoğraf URL'sini döndürür.
  Future<String> uploadProfilePhoto(Uint8List bytes, {String? mimeType}) async {
    try {
      final type = mimeType ?? _imageMimeType(bytes);
      final image = 'data:$type;base64,${base64Encode(bytes)}';
      final response = await _dio.put(
        '/auth/profile-photo',
        data: {'image': image},
        // Görsel sunucusuna (Cloudinary) yükleme birkaç saniye sürebilir.
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      final data = response.data;
      if (data is Map && data['avatar'] is String) {
        return data['avatar'] as String;
      }
      throw const ApiException('Fotoğraf yüklendi ama adres alınamadı.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      AppLogger.debug('Profil fotoğrafı yüklenemedi: status=$status type=${e.type}');
      throw ApiException(
        _serverMessage(e) ?? _photoUploadError(e),
        statusCode: status,
      );
    }
  }

  /// Sunucu açıklama göndermediğinde kullanıcıya anlaşılır neden söylenir.
  static String _photoUploadError(DioException e) {
    switch (e.response?.statusCode) {
      case 401:
        return 'Oturumun sona ermiş. Çıkış yapıp tekrar giriş yap.';
      case 404:
        return 'Fotoğraf yükleme şu an kullanılamıyor. Lütfen daha sonra tekrar dene.';
      case 413:
        return 'Fotoğraf çok büyük. Daha küçük bir fotoğraf seç.';
      case 502:
      case 503:
      case 504:
        return 'Görsel sunucusuna ulaşılamadı. Lütfen biraz sonra tekrar dene.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Yükleme zaman aşımına uğradı. Bağlantını kontrol edip tekrar dene.';
      case DioExceptionType.connectionError:
        return 'İnternet bağlantısı yok gibi görünüyor.';
      default:
        return 'Fotoğraf yüklenemedi. Lütfen tekrar deneyin.';
    }
  }

  /// Baytlardan görsel türünü bulur; seçici bazen PNG/WebP döndürür.
  static String _imageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50) {
      // P
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Profil fotoğrafını kaldırır.
  Future<void> removeProfilePhoto() async {
    try {
      await _dio.delete('/auth/profile-photo');
    } on DioException catch (e) {
      throw ApiException(
        _serverMessage(e) ?? 'Fotoğraf kaldırılamadı. Lütfen tekrar deneyin.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // Kategori işlemleri
  Future<List<models.Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      final rawCategories = response.data is Map
          ? (response.data['categories'] as List<dynamic>? ?? [])
          : <dynamic>[];

      return rawCategories
          .map((json) {
            final name = (json['name'] ?? '').toString();
            final slug = name
                .toLowerCase()
                .replaceAll('ı', 'i')
                .replaceAll('ş', 's')
                .replaceAll('ğ', 'g')
                .replaceAll('ü', 'u')
                .replaceAll('ö', 'o')
                .replaceAll('ç', 'c')
                .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                .replaceAll(RegExp(r'^-|-$'), '');
            return models.Category(
              // Backend ürünleri kategori adlarıyla filtrelediği için ID olarak adı kullan.
              id: name,
              name: name,
              description: '${json['productCount'] ?? 0} ürün',
              image: json['image'],
              icon: _getCategoryIcon(slug),
              order: json['productCount'] ?? 0,
              isActive: json['isActive'] ?? true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          })
          .where((category) => category.name.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.debug('Categories API Error: $e');
      // Sahte kategori gösterilmez; CategoryViewModel hatayı yakalar.
      rethrow;
    }
  }

  // Kategori ikonlarını döndür
  String _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'dondurma':
        return 'ice_cream';
      case 'gida':
        return 'restaurant';
      case 'yiyecekler':
        return 'fastfood';
      case 'icecekler':
        return 'local_drink';
      case 'atistirma':
        return 'cookie';
      case 'cayseker':
        return 'coffee';
      case 'makarna':
        return 'ramen_dining';
      case 'et':
        return 'set_meal';
      case 'sut':
        return 'local_drink';
      case 'meyve-sebze':
        return 'apple';
      case 'temizlik':
        return 'cleaning_services';
      case 'kisisel':
        return 'face';
      case 'baharat':
        return 'spa';
      case 'dondurulmus':
        return 'ac_unit';
      case 'tozicecekler':
        return 'coffee_maker';
      case 'cips':
        return 'cookie';
      case 'bespara':
        return 'savings';
      case 'kahve':
        return 'coffee';
      case 'kahvalti':
        return 'breakfast_dining';
      default:
        return 'category';
    }
  }

  // Banner işlemleri
  Future<List<Banner>> getBanners() async {
    try {
      AppLogger.debug('Getting banners from API...');

      final response = await _dio.get('/banners');

      AppLogger.debug('Banners Response Status: ${response.statusCode}');
      if (response.data != null) {
        // Response formatı: { "success": true, "banners": [...] }
        if (response.data is Map &&
            response.data['success'] == true &&
            response.data['banners'] != null) {
          final List<dynamic> bannersData = response.data['banners'];
          AppLogger.debug('Found ${bannersData.length} banners');

          // Sadece aktif banner'ları ve sıralı şekilde döndür
          final banners = bannersData
              .map((json) => Banner.fromJson(json))
              .where((banner) => banner.isActive)
              .toList();

          // Order'a göre sırala
          banners.sort((a, b) => a.order.compareTo(b.order));

          return banners;
        } else if (response.data is List) {
          // Direkt array formatında gelirse
          final List<dynamic> bannersData = response.data;
          final banners = bannersData
              .map((json) => Banner.fromJson(json))
              .where((banner) => banner.isActive)
              .toList();
          banners.sort((a, b) => a.order.compareTo(b.order));
          return banners;
        }
      }

      AppLogger.debug('No banners found');
      return [];
    } catch (e) {
      AppLogger.debug('Banners API Error: $e');
      return [];
    }
  }

  // Ürün işlemleri
  /// [limit] verilirse sunucunun sırasıyla (`order`) ilk [limit] ürün gelir;
  /// [page] 1'den başlar. [cardFields] liste ekranları için açıklama gibi
  /// kartta gösterilmeyen alanların gönderilmemesini ister (destekleyen
  /// sunucuda yanıt küçülür; desteklemeyen sunucu parametreyi yok sayar).
  Future<List<Product>> getProducts({
    String? category,
    int? limit,
    int? page,
    bool cardFields = false,
  }) async {
    try {
      AppLogger.debug('Getting products for category: $category');

      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (limit != null) queryParams['limit'] = limit;
      if (page != null) queryParams['page'] = page;
      if (cardFields) queryParams['fields'] = 'card';

      final response = await _dio.get(
        '/products',
        queryParameters: queryParams,
      );

      AppLogger.debug('Products Response Status: ${response.statusCode}');
      // API response yapısına göre parse et
      if (response.data is Map && response.data['products'] != null) {
        final List<dynamic> productsData = response.data['products'];
        AppLogger.debug('Found ${productsData.length} products for category: $category');
        return productsData.map((json) => Product.fromJson(json)).toList();
      } else if (response.data is List) {
        final List<dynamic> productsData = response.data;
        AppLogger.debug('Found ${productsData.length} products for category: $category');
        return productsData.map((json) => Product.fromJson(json)).toList();
      }

      AppLogger.debug('No products found for category: $category');
      return [];
    } catch (e) {
      AppLogger.debug('API Error: $e');
      // Sahte ürün gösterilmez; ViewModel hata + "Tekrar dene" durumunu gösterir.
      throw Exception(
        'Ürünler yüklenemedi. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }

  // Öne çıkan ürünleri getir
  Future<List<Product>> getFeaturedProducts() async {
    try {
      AppLogger.debug('Getting featured products from API...');

      final response = await _dio.get('/products/featured');

      AppLogger.debug('Featured Products Response Status: ${response.statusCode}');
      if (response.data is Map &&
          response.data['success'] == true &&
          response.data['products'] != null) {
        final List<dynamic> productsData = response.data['products'];
        AppLogger.debug('Found ${productsData.length} featured products');
        return productsData.map((json) => Product.fromJson(json)).toList();
      }

      AppLogger.debug('No featured products found');
      return [];
    } catch (e) {
      AppLogger.debug('Featured Products API Error: $e');
      // Öne çıkanlar opsiyonel; ana ürün listesi yüklenebiliyorsa sayfa çalışır.
      return [];
    }
  }

  /// Ana sayfa rafları tek istekte. Sunucu bu uç noktayı henüz
  /// desteklemiyorsa (404) ya da istek başarısızsa null döner; çağıran eski
  /// uç noktalarla devam eder.
  Future<HomeFeed?> getHomeFeed({String? deliveryPoint, int limit = 24}) async {
    try {
      final response = await _dio.get(
        '/products/home-feed',
        queryParameters: {
          'limit': limit,
          if (deliveryPoint != null && deliveryPoint.isNotEmpty)
            'deliveryPoint': deliveryPoint,
          'fields': 'card',
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final feed = HomeFeed.fromJson(Map<String, dynamic>.from(data));
      return feed.isEmpty ? null : feed;
    } catch (e) {
      AppLogger.debug('Home feed unavailable: $e');
      return null;
    }
  }

  Future<List<Product>> getPersonalizedProducts({String? deliveryPoint}) async {
    try {
      final response = await _dio.get(
        '/products/personalized',
        queryParameters: {
          if (deliveryPoint != null && deliveryPoint.isNotEmpty)
            'deliveryPoint': deliveryPoint,
        },
      );
      final data = response.data;
      if (data is Map && data['products'] is List) {
        return (data['products'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }
      return [];
    } catch (_) {
      // Giriş yapılmamış veya geçmiş oluşmamışsa ana sayfa normal ürünlerle devam eder.
      return [];
    }
  }

  // Geri bildirim gönder
  Future<Map<String, dynamic>> createFeedback({
    required int rating,
    required Map<String, int> ratings,
    required String title,
    required String message,
    required String category,
  }) async {
    try {
      AppLogger.debug('Creating feedback: rating=$rating, category=$category');

      final response = await _dio.post(
        '/feedback',
        data: {
          'rating': rating,
          'ratings': ratings,
          'title': title,
          'message': message,
          'category': category,
        },
      );

      AppLogger.debug('Feedback Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Geri bildirim gönderilemedi');
    } catch (e) {
      AppLogger.debug('Create Feedback Error: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('Oturum süresi dolmuş, lütfen tekrar giriş yapın');
        } else if (e.response?.statusCode == 400) {
          throw Exception('Geri bildirim verileri hatalı');
        }
      }
      rethrow;
    }
  }

  /// Ürün detayı. Ürün kaldırılmışsa [ApiException] `statusCode: 404` ile
  /// gelir; ağ hatasında statusCode null'dır.
  Future<Product> getProductById(String id) async {
    try {
      final response = await _dio.get('/products/$id');
      return Product.fromJson(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        status == 404
            ? 'Ürün bulunamadı.'
            : 'Ürün detayları alınırken hata oluştu. Lütfen tekrar deneyin.',
        statusCode: status,
      );
    } catch (e) {
      throw const ApiException(
        'Ürün detayları alınırken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  // Benzer ürünleri getir
  Future<List<Product>> getSimilarProducts(String productId) async {
    try {
      AppLogger.debug('Getting similar products for: $productId');
      final response = await _dio.get('/products/$productId/similar');

      AppLogger.debug('Similar Products Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          final List<dynamic> productsData = response.data;
          return productsData.map((json) => Product.fromJson(json)).toList();
        } else if (response.data is Map && response.data['products'] != null) {
          final List<dynamic> productsData = response.data['products'];
          return productsData.map((json) => Product.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      AppLogger.debug('Get Similar Products Error: $e');
      return [];
    }
  }

  // Kullanıcı siparişlerini getir
  Future<List<Order>> getUserOrders() async {
    try {
      AppLogger.debug('Getting user orders...');

      final response = await _dio.get('/orders-analytics/user-orders');

      AppLogger.debug('User Orders Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // API {orders: [...]} formatında döndürüyor
        List<dynamic> ordersData;
        if (response.data is Map && response.data['orders'] != null) {
          ordersData = response.data['orders'] as List<dynamic>;
        } else if (response.data is List) {
          ordersData = response.data as List<dynamic>;
        } else {
          ordersData = [];
        }
        return ordersData
            .map((orderJson) => Order.fromJson(orderJson))
            .toList();
      }

      throw Exception('Siparişler alınamadı: ${response.statusCode}');
    } catch (e) {
      AppLogger.debug('Get User Orders Error: $e');

      if (e.toString().contains('401')) {
        throw Exception('Oturum süresi dolmuş, lütfen tekrar giriş yapın');
      }

      throw Exception(
        'Siparişler alınırken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  // Sipariş iptal et
  /// [reason]: iptal nedeni kimliği (gec, fikir, yanlis_siparis, fiyat, baska_yer, diger)
  Future<bool> cancelOrder(String orderId, {String? reason, String? note}) async {
    try {
      AppLogger.debug('Cancelling order: $orderId');

      final response = await _dio.put(
        '/orders-analytics/cancel-order',
        data: {
          'orderId': orderId,
          if (reason != null) 'reason': reason,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );

      AppLogger.debug('Cancel Order Response Status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.debug('Cancel Order Error: $e');
      return false;
    }
  }

  // Sipariş işlemleri
  Future<Order> createOrder(CreateOrderRequest request) async {
    try {
      // Telefon numarası kontrolü
      if (request.phone.isEmpty) {
        throw const ApiException('Telefon numarası zorunludur');
      }

      // Token kontrolü
      final token = await _getStoredToken();
      if (token == null) {
        throw const ApiException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın',
          statusCode: 401,
        );
      }

      // Web projenizdeki doğru endpoint: /cart/place-order
      AppLogger.debug('Sending order request to: /cart/place-order');

      final response = await _dio.post(
        '/cart/place-order',
        data: request.toJson(),
      );

      AppLogger.debug('Order Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend'den gelen response yapısına göre parse et
        if (response.data is Map) {
          // Eğer response'da 'order' key'i varsa
          final orderData = Map<String, dynamic>.from(
            response.data['order'] ?? response.data,
          );
          orderData['_id'] ??= response.data['orderId'];

          final order = Order.fromJson(orderData);
          AppLogger.debug('Parsed Order ID: ${order.id}');
          return order;
        }
        final order = Order.fromJson(response.data);
        AppLogger.debug('Parsed Order ID (direct): ${order.id}');
        return order;
      } else {
        throw ApiException(
          'Sipariş oluşturulamadı: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      AppLogger.debug('Create Order Error: $e');
      final status = e.response?.statusCode;
      if (status == 401) {
        throw const ApiException(
          'Oturum süresi doldu, lütfen tekrar giriş yapın',
          statusCode: 401,
        );
      }
      // Sunucu 4xx ile anlaşılır mesaj döner (sipariş saatleri, minimum
      // tutar, kupon 409 vb.); aynen göster.
      throw ApiException.fromDio(
        e,
        'Sipariş oluşturulurken hata oluştu. Lütfen tekrar dene.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.debug('Create Order Error: $e');
      throw const ApiException(
        'Sipariş oluşturulurken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  // Kullanıcı ilk siparişte geri bildirim verdi mi?
  Future<bool> hasUserGivenFeedback(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final direct = data['hasFeedback'] == true;
          final nested =
              (data['user'] is Map) && (data['user']['hasFeedback'] == true);
          return direct || nested;
        }
      }
      return false;
    } catch (e) {
      AppLogger.debug('hasUserGivenFeedback error: $e');
      return false;
    }
  }

  // Ayarları getir (minimum tutar için)
  Future<Map<String, dynamic>> getSettings() async {
    try {
      AppLogger.debug('Getting settings...');

      final response = await _dio.get('/settings');

      AppLogger.debug('Settings Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Ayarlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('Get Settings Error: $e');
      // API çalışmıyorsa varsayılan değerleri döndür
      return {
        'minimumOrderAmount': 250.0,
        'orderStartHour': 10,
        'orderStartMinute': 0,
        'orderEndHour': 1,
        'orderEndMinute': 0,
        'deliveryPoints': {
          'girlsDorm': {'enabled': true},
          'boysDorm': {'enabled': true},
        },
      };
    }
  }

  // Kupon kodu doğrula
  Future<Map<String, dynamic>> validateCoupon(
    String code,
    double orderAmount, {
    List<Map<String, dynamic>> products = const [],
    String? deliveryPoint,
    String? deliveryZone,
    String? channel,
  }) async {
    try {
      AppLogger.debug('Validating coupon for amount: $orderAmount');

      final response = await _dio.post('/coupons/validate', data: {
        'code': code,
        'orderAmount': orderAmount,
        'products': products,
        'zoneAware': true,
        if (deliveryPoint != null) 'deliveryPoint': deliveryPoint,
        if (deliveryZone != null) 'deliveryZone': deliveryZone,
        if (channel != null) 'channel': channel,
      });

      AppLogger.debug('Validate Coupon Response Status: ${response.statusCode}');

      return response.data ?? {};
    } catch (e) {
      AppLogger.debug('Validate Coupon Error: $e');
      if (e is DioException && e.response != null) {
        return e.response!.data ??
            {'success': false, 'message': 'Kupon doğrulanamadı'};
      }
      throw Exception('Kupon doğrulanırken hata oluştu');
    }
  }

  Future<Map<String, dynamic>> recommendCoupons(
    double orderAmount, {
    List<Map<String, dynamic>> products = const [],
    String? deliveryPoint,
    String? deliveryZone,
    String? channel,
  }) async {
    try {
      final response = await _dio.post('/coupons/recommend', data: {
        'orderAmount': orderAmount,
        'products': products,
        'zoneAware': true,
        if (deliveryPoint != null) 'deliveryPoint': deliveryPoint,
        if (deliveryZone != null) 'deliveryZone': deliveryZone,
        if (channel != null) 'channel': channel,
      });
      return response.data ?? {};
    } catch (e) {
      if (e is DioException && e.response != null) {
        return e.response!.data ?? {'success': false};
      }
      return {'success': false};
    }
  }

  // Eski arama metodu kaldırıldı - yeni gelişmiş arama kullanılıyor

  /// Şu an süren flash sale'ler (herkese açık; web sitesiyle aynı uç nokta).
  /// İstek başarısızsa null döner; çağıran son bilinen listeyi korur.
  Future<List<FlashSale>?> getActiveFlashSales() async {
    try {
      final response = await _dio.get('/flash-sales/active');
      final data = response.data;
      final list = data is Map ? data['flashSales'] : data;
      if (list is! List) return null;
      final sales = <FlashSale>[];
      for (final json in list) {
        if (json is! Map) continue;
        try {
          final sale = FlashSale.fromJson(Map<String, dynamic>.from(json));
          if (sale.productId.isNotEmpty) sales.add(sale);
        } catch (e) {
          AppLogger.debug('Flash sale okunamadı: $e');
        }
      }
      return sales;
    } catch (e) {
      AppLogger.debug('Active Flash Sales API Error: $e');
      return null;
    }
  }

  // Gelişmiş arama sistemi
  Future<SearchResult> searchProducts({
    required String query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String sort = 'createdAt',
  }) async {
    try {
      AppLogger.debug('Gelişmiş arama yapılıyor: category=$category');

      final Map<String, dynamic> params = {'q': query};

      if (category != null && category.isNotEmpty) {
        params['category'] = category;
      }
      if (minPrice != null && minPrice > 0) {
        params['minPrice'] = minPrice.toString();
      }
      if (maxPrice != null && maxPrice < 1000) {
        params['maxPrice'] = maxPrice.toString();
      }
      if (sort != 'createdAt') {
        params['sort'] = sort;
      }

      final response = await _dio.get(
        '/products/search',
        queryParameters: params,
      );

      AppLogger.debug('Arama Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return SearchResult.fromJson(response.data);
      }

      throw Exception('Arama başarısız');
    } catch (e) {
      AppLogger.debug('Arama API Error: $e');
      rethrow;
    }
  }

  // ========================
  // REFERRAL API METHODS
  // ========================

  /// Kullanıcının referral bilgilerini getir
  Future<Referral> getMyReferrals() async {
    try {
      AppLogger.debug('Getting my referrals from API...');
      final response = await _dio.get('/referrals/my-referrals');

      AppLogger.debug('My Referrals Response Status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true &&
            response.data['referral'] != null) {
          return Referral.fromJson(response.data['referral']);
        }
      }

      throw Exception('Referral bilgileri alınamadı');
    } catch (e) {
      AppLogger.debug('Get My Referrals Error: $e');
      rethrow;
    }
  }

  /// Referral kodu kontrol et (kayıt öncesi)
  Future<ReferralCodeCheck> checkReferralCode(String code) async {
    try {
      final response = await _dio.get('/referrals/check/$code');

      AppLogger.debug('Check Referral Code Response Status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        return ReferralCodeCheck.fromJson(
          response.data,
          response.data['success'] ?? false,
        );
      }

      return ReferralCodeCheck(
        isValid: false,
        message: 'Geçersiz referral kodu',
      );
    } on DioException catch (e) {
      AppLogger.debug('Check Referral Code Error: $e');

      // Handle 400 (limit dolmuş) and 404 (geçersiz) errors
      if (e.response?.statusCode == 400) {
        return ReferralCodeCheck(
          isValid: false,
          message: e.response?.data['message'] ??
              'Bu referral kodu artık kullanılamaz (limit doldu)',
        );
      } else if (e.response?.statusCode == 404) {
        return ReferralCodeCheck(
          isValid: false,
          message: e.response?.data['message'] ?? 'Geçersiz referral kodu',
        );
      }

      return ReferralCodeCheck(
        isValid: false,
        message: 'Referral kodu kontrol edilemedi',
      );
    } catch (e) {
      AppLogger.debug('Check Referral Code Error: $e');
      return ReferralCodeCheck(
        isValid: false,
        message: 'Referral kodu kontrol edilemedi',
      );
    }
  }

  /// Yeni referral kodu oluştur
  Future<Referral> regenerateReferralCode() async {
    try {
      AppLogger.debug('Regenerating referral code...');
      final response = await _dio.post('/referrals/regenerate');

      AppLogger.debug('Regenerate Referral Response Status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true) {
          // Yeni kod ve link ile basit Referral objesi döndür
          return Referral(
            code: response.data['code'] ?? '',
            link: response.data['link'] ?? '',
            totalReferrals: 0,
            successfulReferrals: 0,
            totalRewardsEarned: 0,
            referredUsers: [],
          );
        }
      }

      throw Exception('Referral kodu yenilenemedi');
    } catch (e) {
      AppLogger.debug('Regenerate Referral Code Error: $e');
      rethrow;
    }
  }

  /// Kullanıcının kuponlarını getir
  // -------------------------------------------------------------------------
  // Adrese teslimat
  // -------------------------------------------------------------------------

  /// Adrese teslimat bu kullanıcıya açık mı? Hata verirse çağıran güvenli
  /// tarafta kalır (yurt akışı).
  Future<DeliveryAccess> getDeliveryAccess() async {
    final response = await _dio.get('/delivery/me');
    final data = response.data;
    if (data is Map) {
      return DeliveryAccess.fromJson(Map<String, dynamic>.from(data));
    }
    return DeliveryAccess.disabled;
  }

  /// Açık teslimat bölgeleri (sıralı). Giriş gerekmez.
  Future<DeliveryZonesResult> getDeliveryZones() async {
    try {
      final response = await _dio.get('/delivery/zones');
      final data = response.data;
      if (data is Map) {
        return DeliveryZonesResult.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ApiException('Teslimat bölgeleri alınamadı.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Teslimat bölgeleri alınamadı.');
    }
  }

  /// Kayıtlı adresler ve en fazla adres sayısı.
  Future<({List<DeliveryAddress> addresses, int max})> getAddresses() async {
    try {
      final response = await _dio.get('/addresses');
      final data = response.data;
      if (data is Map) {
        final max = data['max'];
        return (
          addresses: DeliveryAddress.listFromJson(data['addresses']),
          max: max is num && max > 0 ? max.toInt() : 5,
        );
      }
      throw const ApiException('Adreslerin alınamadı.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Adreslerin alınamadı.');
    }
  }

  /// Yeni adres. Yanıt güncel listeyi de döndürür.
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      createAddress({
    required String label,
    required String zoneId,
    required AddressFields fields,
    bool? isDefault,
  }) async {
    try {
      final response = await _dio.post('/addresses', data: {
        'label': label.trim(),
        'zoneId': zoneId,
        ...fields.toJson(),
        if (isDefault != null) 'isDefault': isDefault,
      });
      return _addressResult(response.data, 'Adres kaydedilemedi.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Adres kaydedilemedi.');
    }
  }

  /// Adresi günceller; yalnızca değişen alanlar gönderilir.
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      updateAddress(String id, Map<String, dynamic> changes) async {
    try {
      final response = await _dio.put('/addresses/$id', data: changes);
      return _addressResult(response.data, 'Adres güncellenemedi.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Adres güncellenemedi.');
    }
  }

  /// Adresi siler; güncel listeyi döndürür.
  Future<List<DeliveryAddress>> deleteAddress(String id) async {
    try {
      final response = await _dio.delete('/addresses/$id');
      final data = response.data;
      if (data is Map) return DeliveryAddress.listFromJson(data['addresses']);
      throw const ApiException('Adres silinemedi.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Adres silinemedi.');
    }
  }

  /// Adresi varsayılan yapar.
  Future<({DeliveryAddress address, List<DeliveryAddress> addresses})>
      setDefaultAddress(String id) async {
    try {
      final response = await _dio.patch('/addresses/$id/default');
      return _addressResult(response.data, 'Varsayılan adres değiştirilemedi.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Varsayılan adres değiştirilemedi.');
    }
  }

  ({DeliveryAddress address, List<DeliveryAddress> addresses}) _addressResult(
      Object? data, String fallback) {
    if (data is Map && data['address'] is Map) {
      return (
        address: DeliveryAddress.fromJson(
            Map<String, dynamic>.from(data['address'] as Map)),
        addresses: DeliveryAddress.listFromJson(data['addresses']),
      );
    }
    throw ApiException(fallback);
  }

  /// Seçili bölge ve sepet için teslimat ücreti ve minimum.
  Future<DeliveryQuote> getDeliveryQuote({
    required String zoneId,
    required List<Map<String, dynamic>> products,
  }) async {
    try {
      final response = await _dio.post('/delivery/quote', data: {
        'zoneId': zoneId,
        'products': products,
      });
      final data = response.data;
      if (data is Map) {
        return DeliveryQuote.fromJson(Map<String, dynamic>.from(data));
      }
      throw const ApiException('Teslimat ücreti hesaplanamadı.');
    } on DioException catch (e) {
      throw ApiException.fromDio(e, 'Teslimat ücreti hesaplanamadı.');
    }
  }

  /// [deliveryZone]: seçili adresin bölgesi; bölgeye özel kuponlar ancak bu
  /// verilince döner.
  Future<List<Coupon>> getUserCoupons({String? deliveryZone}) async {
    try {
      final response = await _dio.get('/coupons', queryParameters: {
        'zoneAware': 1,
        if (deliveryZone != null && deliveryZone.isNotEmpty)
          'deliveryZone': deliveryZone,
      });

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true &&
            response.data['coupons'] != null) {
          final List<dynamic> couponsData = response.data['coupons'];
          return couponsData.map((json) => Coupon.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActiveCouponRequestCampaign() async {
    try {
      final response = await _dio.get('/coupon-requests/active');
      return response.data?['campaign'] == null
          ? null
          : Map<String, dynamic>.from(response.data['campaign']);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> requestCouponCampaign() async {
    try {
      final response = await _dio.post('/coupon-requests/active/request');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (error) {
      return Map<String, dynamic>.from(error.response?.data ??
          {'success': false, 'message': 'İstek gönderilemedi'});
    }
  }

  /// Benim Asistanım: yazılan isteğe (ve varsa bütçeye) göre sepet önerisi.
  /// Her durumda {success, message, proposal} döner; hata fırlatmaz.
  Future<Map<String, dynamic>> suggestCart({
    required String prompt,
    double? budget,
  }) async {
    try {
      final response = await _dio.post('/cart-assistant/suggest', data: {
        'prompt': prompt,
        if (budget != null) 'budget': budget,
      });
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'message': 'Sepet şu anda hazırlanamadı. Lütfen tekrar dene.'};
    } on DioException catch (error) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      if (data is Map && data['message'] is String) {
        return {'success': false, 'message': data['message']};
      }
      if (status == 401) {
        return {'success': false, 'message': 'Oturumunun süresi dolmuş. Lütfen tekrar giriş yap.'};
      }
      if (status == 404) {
        return {'success': false, 'message': 'Asistan henüz kullanıma açılmadı. Lütfen daha sonra tekrar dene.'};
      }
      return {'success': false, 'message': 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.'};
    } catch (_) {
      return {'success': false, 'message': 'Sepet şu anda hazırlanamadı. Lütfen tekrar dene.'};
    }
  }

  /// Telefondaki sepetin son hâlini sunucuya bildirir (sepet hatırlatması ve
  /// sepete özel bildirimler bunu kullanır). Başarısız olursa sessizce geçer.
  Future<bool> syncCart(List<Map<String, dynamic>> items) async {
    try {
      final response = await _dio.put('/cart/sync', data: {'items': items});
      return response.data is Map && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Favori sepetler. {success, carts, message} döner; hata fırlatmaz.
  Future<Map<String, dynamic>> getSavedCarts() async {
    try {
      final response = await _dio.get('/saved-carts');
      final carts = response.data is Map ? response.data['carts'] : null;
      return {
        'success': true,
        'carts': carts is List
            ? carts
                .whereType<Map>()
                .map((cart) => Map<String, dynamic>.from(cart))
                .toList()
            : <Map<String, dynamic>>[],
      };
    } on DioException catch (error) {
      return _savedCartError(error, 'Favori sepetlerin yüklenemedi.');
    } catch (_) {
      return {'success': false, 'message': 'Favori sepetlerin yüklenemedi.'};
    }
  }

  /// Ürün listesini verilen adla favori sepet olarak kaydeder. Aynı adla
  /// kayıt varsa üzerine yazılır ({replaced: true}).
  Future<Map<String, dynamic>> saveSavedCart({
    required String name,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post('/saved-carts', data: {
        'name': name,
        'items': items,
      });
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'message': 'Sepet kaydedilemedi. Lütfen tekrar dene.'};
    } on DioException catch (error) {
      return _savedCartError(error, 'Sepet kaydedilemedi. Lütfen tekrar dene.');
    } catch (_) {
      return {'success': false, 'message': 'Sepet kaydedilemedi. Lütfen tekrar dene.'};
    }
  }

  Future<Map<String, dynamic>> deleteSavedCart(String id) async {
    try {
      await _dio.delete('/saved-carts/$id');
      return {'success': true};
    } on DioException catch (error) {
      return _savedCartError(error, 'Sepet silinemedi. Lütfen tekrar dene.');
    } catch (_) {
      return {'success': false, 'message': 'Sepet silinemedi. Lütfen tekrar dene.'};
    }
  }

  Map<String, dynamic> _savedCartError(DioException error, String fallback) {
    final data = error.response?.data;
    final status = error.response?.statusCode;
    if (status == 401) {
      return {'success': false, 'message': 'Oturumunun süresi dolmuş. Lütfen tekrar giriş yap.'};
    }
    if (status == 404 && !(data is Map && data['message'] is String)) {
      return {'success': false, 'message': 'Favori sepetler henüz kullanıma açılmadı. Lütfen daha sonra tekrar dene.'};
    }
    if (data is Map && data['message'] is String) {
      return {'success': false, 'message': data['message']};
    }
    if (status == null) {
      return {'success': false, 'message': 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.'};
    }
    return {'success': false, 'message': fallback};
  }

  /// Süren sipariş görevleri ve müşterinin ilerlemesi
  Future<List<Map<String, dynamic>>> getActiveMissions() async {
    try {
      final response = await _dio.get('/missions/active');
      final missions = response.data is Map ? response.data['missions'] : null;
      if (missions is! List) return [];
      return missions
          .whereType<Map>()
          .map((mission) => Map<String, dynamic>.from(mission))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sipariş sonrası anket durumu: {deliveredCount, prompt: {milestone, orderId} | null}
  Future<Map<String, dynamic>?> getOrderFeedbackPrompt() async {
    try {
      final response = await _dio.get('/feedback/prompt');
      if (response.data is! Map) return null;
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return null;
    }
  }

  /// Sipariş sonrası anketi gönderir. Sonuç: hata mesajı ya da destek görüşmesi kimliği.
  Future<FeedbackSubmitResult> submitOrderFeedback({
    required int rating,
    required int milestone,
    required List<String> tags,
    required String comment,
    int? deliveryRating,
    List<Map<String, String>> problemItems = const [],
    String? orderId,
  }) {
    return _postFeedback('/feedback/order', {
      'rating': rating,
      'milestone': milestone,
      'tags': tags,
      'comment': comment,
      if (deliveryRating != null) 'deliveryRating': deliveryRating,
      if (problemItems.isNotEmpty) 'problemItems': problemItems,
      if (orderId != null) 'orderId': orderId,
    });
  }

  /// Sipariş sonrası tek dokunuşluk 👍/👎 (thumb: 'up' | 'down')
  Future<FeedbackSubmitResult> submitQuickFeedback({
    required String orderId,
    required String thumb,
    List<String> tags = const [],
    String comment = '',
    List<Map<String, String>> problemItems = const [],
  }) {
    return _postFeedback('/feedback/quick', {
      'orderId': orderId,
      'thumb': thumb,
      if (tags.isNotEmpty) 'tags': tags,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      if (problemItems.isNotEmpty) 'problemItems': problemItems,
    });
  }

  /// "Bizi bir arkadaşına önerir misin?" (0-10)
  Future<FeedbackSubmitResult> submitNps({required int score, String comment = ''}) {
    return _postFeedback('/feedback/nps', {
      'score': score,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }

  /// Sepetini boşaltan müşteri: "Neden vazgeçtin?"
  Future<FeedbackSubmitResult> submitAbandonReason({required String reason, String note = ''}) {
    return _postFeedback('/feedback/abandon', {
      'reason': reason,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<FeedbackSubmitResult> _postFeedback(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      final data = response.data;
      final chatId = data is Map ? data['supportChatId'] : null;
      return FeedbackSubmitResult(supportChatId: chatId is String && chatId.isNotEmpty ? chatId : null);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return FeedbackSubmitResult(error: data['message'] as String);
      }
      return const FeedbackSubmitResult(error: 'Geri bildirim gönderilemedi. Lütfen tekrar dene.');
    } catch (_) {
      return const FeedbackSubmitResult(error: 'Geri bildirim gönderilemedi. Lütfen tekrar dene.');
    }
  }

  /// Kullanıcının kendi geri bildirimleri (yönetici yanıtlarıyla birlikte)
  Future<List<Map<String, dynamic>>> getMyFeedbacks() async {
    try {
      final response = await _dio.get('/feedback/user');
      final data = response.data;
      if (data is! List) return [];
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Bildirim tercihlerini getir (orders, messages, campaigns)
  Future<Map<String, bool>?> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/notifications/preferences');
      return _parseNotificationPreferences(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Bildirim tercihlerini güncelle; başarısız olursa null döner
  Future<Map<String, bool>?> updateNotificationPreferences(
      Map<String, bool> changes) async {
    try {
      final response =
          await _dio.put('/notifications/preferences', data: changes);
      return _parseNotificationPreferences(response.data);
    } catch (_) {
      return null;
    }
  }

  Map<String, bool>? _parseNotificationPreferences(dynamic data) {
    if (data is! Map || data['preferences'] is! Map) return null;
    final preferences = data['preferences'] as Map;
    return {
      for (final key in const ['orders', 'messages', 'campaigns'])
        key: preferences[key] != false,
    };
  }
}
