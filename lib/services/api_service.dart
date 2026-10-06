import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/product.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/category.dart' as models;
import '../models/flash_sale.dart';
import '../models/search_result.dart';
import '../models/banner.dart';
import '../models/referral.dart';
import '../models/coupon.dart';
import 'token_manager.dart';
import 'app_logger.dart';

class ApiService {
  // Gerçek API base URL'i
  static const String baseUrl = 'https://devrekbenimmarketim.com/api';

  // Tüm ApiService örnekleri aynı Dio'yu (bağlantı havuzu + interceptor)
  // paylaşır; böylece token yenileme tek noktadan yönetilir.
  static Dio? _sharedDio;

  // Aynı anda gelen 401'lerde refresh isteği yalnızca bir kez atılır.
  static Future<String?>? _refreshInFlight;

  late final Dio _dio = _sharedDio ??= _createDio();

  /// Yalnızca testler/ekran görüntüleri için: ağ yerine sahte yanıt verir.
  @visibleForTesting
  static void debugUseHttpAdapter(HttpClientAdapter adapter) {
    _sharedDio = _createDio()..httpClientAdapter = adapter;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60), // 60 saniye
        receiveTimeout: const Duration(seconds: 60), // 60 saniye
        sendTimeout: const Duration(seconds: 60), // 60 saniye
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // NOT: badCertificateCallback yalnızca sertifika sistem doğrulamasından
    // GEÇEMEDİĞİNDE çağrılır. Geçerli (CA imzalı) sertifikalarda bu kontrol
    // hiç çalışmaz; yani bu blok gerçek bir SSL pinning sağlamaz.
    // Aşağıdaki parmak izi sunucunun güncel Let's Encrypt zincirindeki hiçbir
    // sertifikayla eşleşmiyor (2026-10-05 kontrolü). Zorunlu pinning açılırsa
    // uygulama sunucuya bağlanamaz. Gerçek pinning için yedek pin'li
    // public-key (SPKI) pinning gerekir.
    const String knownFingerprint =
        'EE:EB:A5:75:11:B3:AF:3F:C3:E3:FC:3B:FB:4F:98:D0:03:46:94:E4:C6:DD:5C:02:C2:47:2E:EA:91:0B:C2:81';

    (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        // Fingerprint kontrolü:
        // Sertifikanın DER formatındaki verisini SHA256 ile hashle
        final digest = sha256.convert(cert.der).toString().toUpperCase();

        // Beklenen fingerprint'i formatla (aradaki : işaretlerini kaldır)
        final expectedFingerprint =
            knownFingerprint.replaceAll(':', '').toUpperCase();

        // Hash'i karşılaştır
        final isValid = digest == expectedFingerprint;

        if (!isValid) {
          AppLogger.debug('GÜVENLİK UYARISI: Sertifika parmak izi eşleşmedi!');
          AppLogger.debug('Beklenen: $expectedFingerprint');
          AppLogger.debug('Gelen: $digest');
        } else {
          AppLogger.debug('GÜVENLİK: SSL Pinning başarılı, sertifika doğrulandı.');
        }

        return isValid;
      };
      return client;
    };

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
            AppLogger.debug('401 hatası - Token geçersiz, yenileniyor...');

            // Sonsuz döngüyü engelle - sadece bir kez yenile
            if (error.requestOptions.path.contains('/auth/refresh-token')) {
              AppLogger.debug('Refresh token endpoint\'i, döngüyü durdur');
              _clearStoredToken();
              handler.next(error);
              return;
            }

            // Token yenilemeyi dene
            final newToken = await _refreshAccessToken(dio);
            if (newToken != null) {
              // Yeni token ile isteği tekrar dene
              final originalRequest = error.requestOptions;
              originalRequest.headers['Authorization'] = 'Bearer $newToken';

              try {
                final response = await dio.fetch(originalRequest);
                handler.resolve(response);
                return;
              } catch (e) {
                AppLogger.debug('Token yenilendikten sonra istek başarısız: $e');
              }
            }

            // Token yenilenemedi, temizle
            _clearStoredToken();
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
        if (newToken != null) {
          await TokenManager.saveAccessToken(newToken);
          AppLogger.debug('Token başarıyla yenilendi');
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

      // HTTP hata kodları kontrolü
      if (response.statusCode == 400) {
        throw Exception('E-posta veya şifre hatalı');
      } else if (response.statusCode == 401) {
        throw Exception('E-posta veya şifre hatalı');
      } else if (response.statusCode == 404) {
        throw Exception('Kullanıcı bulunamadı');
      } else if (response.statusCode == 500) {
        throw Exception('Sunucu hatası. Lütfen daha sonra tekrar deneyin');
      } else if (response.statusCode != 200) {
        throw Exception('Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin');
      }

      // Response null ise hata fırlat
      if (response.data == null) {
        throw Exception('API\'den yanıt alınamadı');
      }

      final authResponse = AuthResponse.fromJson(response.data);

      // Token kontrolü
      if (authResponse.accessToken.isEmpty) {
        throw Exception('Geçersiz token alındı');
      }

      await TokenManager.saveAccessToken(authResponse.accessToken);
      await TokenManager.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } catch (e) {
      AppLogger.debug('Login Error: $e');

      // Timeout ve bağlantı hataları kontrolü
      if (e.toString().contains('receive timeout') ||
          e.toString().contains('connect timeout') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        AppLogger.debug('API çalışmıyor, gerçek hata fırlatılıyor...');
        throw Exception(
          'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.',
        );
      }

      throw Exception('Giriş yapılırken hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      // Telefon numarası kontrolü
      if (request.phone.isEmpty) {
        throw Exception('Telefon numarası zorunludur');
      }

      final response = await _dio.post('/auth/signup', data: request.toJson());

      AppLogger.debug('Register Response Status: ${response.statusCode}');

      // HTTP hata kodları kontrolü
      if (response.statusCode == 400) {
        throw Exception('Bu e-posta adresi zaten kullanılıyor');
      } else if (response.statusCode == 401) {
        throw Exception('Kayıt bilgileri hatalı');
      } else if (response.statusCode == 500) {
        throw Exception('Sunucu hatası. Lütfen daha sonra tekrar deneyin');
      } else if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Kayıt olunamadı. Lütfen bilgilerinizi kontrol edin');
      }

      if (response.data == null) {
        throw Exception('API\'den yanıt alınamadı');
      }

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      AppLogger.debug('Register Error: $e');

      // Bağlantı hataları kontrolü
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        AppLogger.debug('API çalışmıyor, gerçek hata fırlatılıyor...');
        throw Exception(
          'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.',
        );
      }

      throw Exception('Kayıt olurken hata oluştu. Lütfen tekrar deneyin.');
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
    } catch (e) {
      AppLogger.debug('getProfile: Hata: $e');
      throw Exception('Profil bilgileri alınırken hata oluştu: $e');
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
  Future<List<Product>> getProducts({String? category}) async {
    try {
      AppLogger.debug('Getting products for category: $category');

      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

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

  Future<List<Product>> getPersonalizedProducts() async {
    try {
      final response = await _dio.get('/products/personalized');
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

  // Kullanıcının geri bildirimlerini getir
  Future<List<Map<String, dynamic>>> getUserFeedbacks() async {
    try {
      AppLogger.debug('Getting user feedbacks...');

      final response = await _dio.get('/feedback/user');

      AppLogger.debug('User Feedbacks Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map && response.data['feedbacks'] != null) {
          return List<Map<String, dynamic>>.from(response.data['feedbacks']);
        }
      }

      return [];
    } catch (e) {
      AppLogger.debug('Get User Feedbacks Error: $e');
      return [];
    }
  }

  Future<Product> getProductById(String id) async {
    try {
      final response = await _dio.get('/products/$id');
      return Product.fromJson(response.data);
    } catch (e) {
      throw Exception(
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
  Future<bool> cancelOrder(String orderId) async {
    try {
      AppLogger.debug('Cancelling order: $orderId');

      final response = await _dio.put(
        '/orders-analytics/cancel-order',
        data: {'orderId': orderId},
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
        throw Exception('Telefon numarası zorunludur');
      }

      // Token kontrolü
      final token = await _getStoredToken();
      if (token == null) {
        throw Exception('Token bulunamadı, lütfen tekrar giriş yapın');
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
        throw Exception('Sipariş oluşturulamadı: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('Create Order Error: $e');

      // 401 hatası durumunda özel mesaj
      if (e.toString().contains('401')) {
        throw Exception('Oturum süresi doldu, lütfen tekrar giriş yapın');
      }

      throw Exception(
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

  Future<Order> getOrderById(String orderId) async {
    try {
      AppLogger.debug('Getting order: $orderId');

      final response = await _dio.get('/orders/$orderId');

      AppLogger.debug('Order Detail Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Order.fromJson(response.data);
      } else {
        throw Exception('Sipariş bulunamadı: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('Get Order Error: $e');
      throw Exception(
        'Sipariş detayı alınırken hata oluştu. Lütfen tekrar deneyin.',
      );
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
    String? channel,
  }) async {
    try {
      AppLogger.debug('Validating coupon for amount: $orderAmount');

      final response = await _dio.post('/coupons/validate', data: {
        'code': code,
        'orderAmount': orderAmount,
        'products': products,
        if (deliveryPoint != null) 'deliveryPoint': deliveryPoint,
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
    String? channel,
  }) async {
    try {
      final response = await _dio.post('/coupons/recommend', data: {
        'orderAmount': orderAmount,
        'products': products,
        if (deliveryPoint != null) 'deliveryPoint': deliveryPoint,
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

  // Flash Sale API'leri
  Future<List<FlashSale>> getFlashSales() async {
    try {
      AppLogger.debug('Getting flash sales from API...');

      final response = await _dio.get('/flash-sales');

      AppLogger.debug('Flash Sales Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        if (response.data is List) {
          return response.data.map((json) => FlashSale.fromJson(json)).toList();
        } else if (response.data is Map &&
            response.data['flashSales'] != null) {
          return (response.data['flashSales'] as List)
              .map((json) => FlashSale.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e) {
      AppLogger.debug('Flash Sales API Error: $e');
      return [];
    }
  }

  Future<FlashSale> createFlashSale({
    required String productId,
    required String name,
    required double discountPercentage,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      AppLogger.debug(
        'Creating flash sale: productId=$productId, discount=$discountPercentage%',
      );

      final response = await _dio.post(
        '/flash-sales',
        data: {
          'product': productId,
          'name': name,
          'discountPercentage': discountPercentage,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'isActive': true,
        },
      );

      AppLogger.debug('Create Flash Sale Response Status: ${response.statusCode}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        return FlashSale.fromJson(response.data);
      }

      throw Exception('Flash sale oluşturulamadı');
    } catch (e) {
      AppLogger.debug('Create Flash Sale Error: $e');
      rethrow;
    }
  }

  Future<FlashSale> updateFlashSale({
    required String id,
    required String name,
    required double discountPercentage,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
  }) async {
    try {
      AppLogger.debug('Updating flash sale: id=$id');

      final response = await _dio.put(
        '/flash-sales/$id',
        data: {
          'name': name,
          'discountPercentage': discountPercentage,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'isActive': isActive,
        },
      );

      AppLogger.debug('Update Flash Sale Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return FlashSale.fromJson(response.data);
      }

      throw Exception('Flash sale güncellenemedi');
    } catch (e) {
      AppLogger.debug('Update Flash Sale Error: $e');
      rethrow;
    }
  }

  Future<void> deleteFlashSale(String id) async {
    try {
      AppLogger.debug('Deleting flash sale: id=$id');

      final response = await _dio.delete('/flash-sales/$id');

      AppLogger.debug('Delete Flash Sale Response Status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Flash sale silinemedi');
      }
    } catch (e) {
      AppLogger.debug('Delete Flash Sale Error: $e');
      rethrow;
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

  // Arama önerileri
  Future<List<String>> getSearchSuggestions() async {
    try {
      final response = await _dio.get('/products/search/suggestions');

      if (response.statusCode == 200) {
        return List<String>.from(response.data['categories'] ?? []);
      }

      return [];
    } catch (e) {
      AppLogger.debug('Arama önerileri hatası: $e');
      return [];
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
  Future<List<Coupon>> getUserCoupons() async {
    try {
      final response = await _dio.get('/coupons');

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
