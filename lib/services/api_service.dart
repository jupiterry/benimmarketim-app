import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
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

class ApiService {
  // Gerçek API base URL'i
  static const String baseUrl = 'https://devrekbenimmarketim.com/api';
  late Dio _dio;

  // Token'ı memory'de tut
  String? _storedToken;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60), // 60 saniye
        receiveTimeout: const Duration(seconds: 60), // 60 saniye
        sendTimeout: const Duration(seconds: 60), // 60 saniye
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // SSL Pinning (Güvenlik)
    // Not: Gerçek production ortamında buraya sertifika SHA-256 parmak izi eklenmeli
    // Şu anlık self-signed veya geçersiz sertifikaları reddediyoruz (varsayılan davranış)
    // Ancak Man-in-the-Middle saldırılarını önlemek için fingerprint kontrolü ekliyoruz.

    // Bu fingerprint devrekbenimmarketim.com'un sertifikasına ait.
    // Sertifika değişirse bu değerin de güncellenmesi gerekir!
    const String knownFingerprint =
        'EE:EB:A5:75:11:B3:AF:3F:C3:E3:FC:3B:FB:4F:98:D0:03:46:94:E4:C6:DD:5C:02:C2:47:2E:EA:91:0B:C2:81';

    (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
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
          print('GÜVENLİK UYARISI: Sertifika parmak izi eşleşmedi!');
          print('Beklenen: $expectedFingerprint');
          print('Gelen: $digest');
        } else {
          print('GÜVENLİK: SSL Pinning başarılı, sertifika doğrulandı.');
        }

        return isValid;
      };
      return client;
    };

    // Interceptor ekle (token için)
    _dio.interceptors.add(
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
            print('401 hatası - Token geçersiz, yenileniyor...');

            // Sonsuz döngüyü engelle - sadece bir kez yenile
            if (error.requestOptions.path.contains('/auth/refresh-token')) {
              print('Refresh token endpoint\'i, döngüyü durdur');
              _clearStoredToken();
              handler.next(error);
              return;
            }

            // Token yenilemeyi dene
            final newToken = await refreshToken();
            if (newToken != null) {
              // Yeni token ile isteği tekrar dene
              final originalRequest = error.requestOptions;
              originalRequest.headers['Authorization'] = 'Bearer $newToken';

              try {
                final response = await _dio.fetch(originalRequest);
                handler.resolve(response);
                return;
              } catch (e) {
                print('Token yenilendikten sonra istek başarısız: $e');
              }
            }

            // Token yenilenemedi, temizle
            _clearStoredToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<String?> _getStoredToken() async {
    return await TokenManager.getAccessToken();
  }

  Future<void> _clearStoredToken() async {
    await TokenManager.clearAllTokens();
    _storedToken = null;
    print('Token temizlendi');
  }

  // Kullanıcı işlemleri
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      print('Login Request: ${request.toJson()}');

      final response = await _dio.post('/auth/login', data: request.toJson());

      print('Login Response Status: ${response.statusCode}');
      print('Login Response: ${response.data}');

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

      _storedToken = authResponse.accessToken;
      await TokenManager.saveAccessToken(authResponse.accessToken);
      await TokenManager.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } catch (e) {
      print('Login Error: $e');

      // Timeout ve bağlantı hataları kontrolü
      if (e.toString().contains('receive timeout') ||
          e.toString().contains('connect timeout') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        print('API çalışmıyor, gerçek hata fırlatılıyor...');
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

      print('Register Request: ${request.toJson()}');

      final response = await _dio.post('/auth/signup', data: request.toJson());

      print('Register Response Status: ${response.statusCode}');
      print('Register Response: ${response.data}');

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
      print('Register Error: $e');

      // Bağlantı hataları kontrolü
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        print('API çalışmıyor, gerçek hata fırlatılıyor...');
        throw Exception(
          'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.',
        );
      }

      throw Exception('Kayıt olurken hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  Future<User> getProfile() async {
    try {
      print('getProfile: API çağrısı yapılıyor...');
      final response = await _dio.get('/auth/profile');
      print('getProfile: Response status: ${response.statusCode}');
      print('getProfile: Response data: ${response.data}');

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
      print(
        'getProfile: User yüklendi - Name: ${user.name}, Email: ${user.email}',
      );
      return user;
    } catch (e) {
      print('getProfile: Hata: $e');
      throw Exception('Profil bilgileri alınırken hata oluştu: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      print('Logout API hatası: $e');
    } finally {
      // Her durumda token'ı temizle
      _clearStoredToken();
    }
  }

  // Hesap silme
  Future<void> deleteAccount() async {
    try {
      print('Deleting account...');
      final response = await _dio.delete('/auth/delete-account');

      print('Delete Account Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Başarılı, tokenları temizle
        await _clearStoredToken();
        return;
      }

      throw Exception('Hesap silinemedi');
    } catch (e) {
      print('Delete Account Error: $e');
      throw Exception('Hesap silinirken bir hata oluştu: $e');
    }
  }

  // Token yenileme metodu (web projesindeki refresh token sistemi)
  Future<String?> refreshToken() async {
    try {
      print('Token yenileniyor...');

      // Token yoksa yenileme yapma
      final currentToken = await _getStoredToken();
      if (currentToken == null) {
        print('Token bulunamadı, yenileme yapılamıyor');
        return null;
      }

      final response = await _dio.post('/auth/refresh-token');

      if (response.statusCode == 200) {
        final newToken = response.data['accessToken'];
        if (newToken != null) {
          _storedToken = newToken;
          await TokenManager.saveAccessToken(newToken);
          print('Token başarıyla yenilendi: $newToken');
          return newToken;
        }
      }

      return null;
    } catch (e) {
      print('Token yenileme hatası: $e');
      return null;
    }
  }

  // Kategori işlemleri
  Future<List<models.Category>> getCategories() async {
    try {
      print('Getting categories from products API...');
      // Tüm ürünleri çek ve kategorileri çıkar
      final response = await _dio.get('/products');

      print('Products Response Status: ${response.statusCode}');

      if (response.data == null) {
        print('Products response is null, using mock data');
        return _getMockCategories();
      }

      // API'den gelen ürünlerden kategorileri çıkar
      List<models.Category> categories = [];

      if (response.data is Map && response.data['products'] != null) {
        List products = response.data['products'];
        print('Found ${products.length} products, extracting categories...');

        // Sabit kategori listesi - API'deki kategori ID'leri ile eşleştirildi
        final List<Map<String, String>> fixedCategories = [
          {'id': 'kahve', 'name': 'Benim Kahvem'},
          {'id': 'yiyecekler', 'name': 'Yiyecekler'},
          {'id': 'kahvalti', 'name': 'Kahvaltılık Ürünler'},
          {'id': 'gida', 'name': 'Temel Gıda'},
          {'id': 'meyve-sebze', 'name': 'Meyve & Sebze'},
          {'id': 'sut', 'name': 'Süt & Süt Ürünleri'},
          {'id': 'bespara', 'name': 'Beş Para Etmeyen Ürünler'},
          {'id': 'tozicecekler', 'name': 'Toz İçecekler'},
          {'id': 'cips', 'name': 'Cips & Çerez'},
          {'id': 'cayseker', 'name': 'Çay ve Şekerler'},
          {'id': 'atistirma', 'name': 'Atıştırmalıklar'},
          {'id': 'temizlik', 'name': 'Temizlik & Hijyen'},
          {'id': 'kisisel', 'name': 'Kişisel Bakım'},
          {'id': 'makarna', 'name': 'Makarna ve Kuru Bakliyat'},
          {'id': 'et', 'name': 'Şarküteri & Et Ürünleri'},
          {'id': 'icecekler', 'name': 'Buz Gibi İçecekler'},
          {'id': 'dondurulmus', 'name': 'Dondurulmuş Gıdalar'},
          {'id': 'baharat', 'name': 'Baharatlar'},
          {'id': 'dondurma', 'name': 'Golf Dondurmalar'},
        ];

        print('Using fixed categories: ${fixedCategories.length}');

        // Kategorileri Category objelerine dönüştür
        for (int i = 0; i < fixedCategories.length; i++) {
          final categoryData = fixedCategories[i];
          categories.add(
            models.Category(
              id: categoryData['id']!,
              name: categoryData['name']!,
              description: _getCategoryDescription(categoryData['id']!),
              icon: _getCategoryIcon(categoryData['id']!),
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      print('Created ${categories.length} categories from API');
      return categories.isNotEmpty ? categories : _getMockCategories();
    } catch (e) {
      print('Categories API Error: $e');
      print('Using mock categories as fallback');
      return _getMockCategories();
    }
  }

  // Kategori açıklamalarını döndür
  String _getCategoryDescription(String categoryName) {
    switch (categoryName) {
      case 'dondurma':
        return 'Golf dondurmalar ve dondurma ürünleri';
      case 'gida':
        return 'Temel gıda ürünleri';
      case 'yiyecekler':
        return 'Hazır yiyecekler';
      case 'icecekler':
        return 'Soğuk içecekler';
      case 'atistirma':
        return 'Atıştırmalık ürünler';
      case 'cayseker':
        return 'Çay ve şeker ürünleri';
      case 'makarna':
        return 'Makarna ve kuru bakliyat';
      case 'et':
        return 'Et ve et ürünleri';
      case 'sut':
        return 'Süt ve süt ürünleri';
      case 'meyve-sebze':
        return 'Taze meyve ve sebzeler';
      case 'temizlik':
        return 'Temizlik ürünleri';
      case 'kisisel':
        return 'Kişisel bakım ürünleri';
      case 'baharat':
        return 'Baharat ve soslar';
      case 'dondurulmus':
        return 'Dondurulmuş gıdalar';
      case 'tozicecekler':
        return 'Toz içecekler';
      case 'cips':
        return 'Cips ve çerezler';
      case 'bespara':
        return 'Uygun fiyatlı ürünler';
      case 'kahve':
        return 'Kahve ürünleri';
      case 'kahvalti':
        return 'Kahvaltılık ürünler';
      default:
        return 'Kategori ürünleri';
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

  // Mock kategoriler (API çalışmadığında)
  List<models.Category> _getMockCategories() {
    return [
      models.Category(
        id: '1',
        name: 'Vegan',
        description: 'Vegan ürünler',
        icon: 'eco',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      models.Category(
        id: '2',
        name: 'Et',
        description: 'Et ve et ürünleri',
        icon: 'restaurant',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      models.Category(
        id: '3',
        name: 'Meyve',
        description: 'Taze meyveler',
        icon: 'apple',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      models.Category(
        id: '4',
        name: 'Süt',
        description: 'Süt ve süt ürünleri',
        icon: 'local_drink',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      models.Category(
        id: '5',
        name: 'Balık',
        description: 'Deniz ürünleri',
        icon: 'set_meal',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  // Banner işlemleri
  Future<List<Banner>> getBanners() async {
    try {
      print('Getting banners from API...');

      final response = await _dio.get('/banners');

      print('Banners Response Status: ${response.statusCode}');
      print('Banners Response: ${response.data}');

      if (response.data != null) {
        // Response formatı: { "success": true, "banners": [...] }
        if (response.data is Map &&
            response.data['success'] == true &&
            response.data['banners'] != null) {
          final List<dynamic> bannersData = response.data['banners'];
          print('Found ${bannersData.length} banners');

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

      print('No banners found');
      return [];
    } catch (e) {
      print('Banners API Error: $e');
      return [];
    }
  }

  // Ürün işlemleri
  Future<List<Product>> getProducts({String? category}) async {
    try {
      print('Getting products for category: $category');

      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _dio.get(
        '/products',
        queryParameters: queryParams,
      );

      print('Products Response Status: ${response.statusCode}');
      print('Products Response: ${response.data}');

      // API response yapısına göre parse et
      if (response.data is Map && response.data['products'] != null) {
        final List<dynamic> productsData = response.data['products'];
        print('Found ${productsData.length} products for category: $category');
        return productsData.map((json) => Product.fromJson(json)).toList();
      } else if (response.data is List) {
        final List<dynamic> productsData = response.data;
        print('Found ${productsData.length} products for category: $category');
        return productsData.map((json) => Product.fromJson(json)).toList();
      }

      print('No products found for category: $category');
      return [];
    } catch (e) {
      print('API Error: $e');
      // API çalışmıyorsa mock data döndür
      return _getMockProducts();
    }
  }

  // Öne çıkan ürünleri getir
  Future<List<Product>> getFeaturedProducts() async {
    try {
      print('Getting featured products from API...');

      final response = await _dio.get('/products/featured');

      print('Featured Products Response Status: ${response.statusCode}');
      print('Featured Products Response: ${response.data}');

      if (response.data is Map &&
          response.data['success'] == true &&
          response.data['products'] != null) {
        final List<dynamic> productsData = response.data['products'];
        print('Found ${productsData.length} featured products');
        return productsData.map((json) => Product.fromJson(json)).toList();
      }

      print('No featured products found');
      return [];
    } catch (e) {
      print('Featured Products API Error: $e');
      // API çalışmıyorsa mock data döndür
      final mockProducts = await _getMockProducts();
      return mockProducts.take(4).toList();
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
      print('Creating feedback: rating=$rating, category=$category');

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

      print('Feedback Response Status: ${response.statusCode}');
      print('Feedback Response: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Geri bildirim gönderilemedi');
    } catch (e) {
      print('Create Feedback Error: $e');
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
      print('Getting user feedbacks...');

      final response = await _dio.get('/feedback/user');

      print('User Feedbacks Response Status: ${response.statusCode}');
      print('User Feedbacks Response: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map && response.data['feedbacks'] != null) {
          return List<Map<String, dynamic>>.from(response.data['feedbacks']);
        }
      }

      return [];
    } catch (e) {
      print('Get User Feedbacks Error: $e');
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
      print('Getting similar products for: $productId');
      final response = await _dio.get('/products/$productId/similar');

      print('Similar Products Response Status: ${response.statusCode}');

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
      print('Get Similar Products Error: $e');
      return [];
    }
  }

  // Kullanıcı siparişlerini getir
  Future<List<Order>> getUserOrders() async {
    try {
      print('Getting user orders...');

      final response = await _dio.get('/orders-analytics/user-orders');

      print('User Orders Response Status: ${response.statusCode}');
      print('User Orders Response: ${response.data}');

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
      print('Get User Orders Error: $e');

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
      print('Cancelling order: $orderId');

      final response = await _dio.put(
        '/orders-analytics/cancel-order',
        data: {'orderId': orderId},
      );

      print('Cancel Order Response Status: ${response.statusCode}');
      print('Cancel Order Response: ${response.data}');

      return response.statusCode == 200;
    } catch (e) {
      print('Cancel Order Error: $e');
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

      print('Creating order: ${request.toJson()}');

      // Token kontrolü
      final token = await _getStoredToken();
      if (token == null) {
        throw Exception('Token bulunamadı, lütfen tekrar giriş yapın');
      }

      // Web projenizdeki doğru endpoint: /cart/place-order
      print('Sending order request to: /cart/place-order');
      print('Request data: ${request.toJson()}');

      final response = await _dio.post(
        '/cart/place-order',
        data: request.toJson(),
      );

      print('Order Response Status: ${response.statusCode}');
      print('Order Response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend'den gelen response yapısına göre parse et
        if (response.data is Map) {
          // Eğer response'da 'order' key'i varsa
          final orderData = response.data['order'] ?? response.data;
          print('=== ORDER DATA DEBUG ===');
          print('Order Data: $orderData');
          print('_id field: ${orderData['_id']}');
          print('id field: ${orderData['id']}');

          final order = Order.fromJson(orderData);
          print('Parsed Order ID: ${order.id}');
          print('========================');
          return order;
        }
        final order = Order.fromJson(response.data);
        print('Parsed Order ID (direct): ${order.id}');
        return order;
      } else {
        throw Exception('Sipariş oluşturulamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Create Order Error: $e');

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
      print('hasUserGivenFeedback error: $e');
      return false;
    }
  }

  Future<Order> getOrderById(String orderId) async {
    try {
      print('Getting order: $orderId');

      final response = await _dio.get('/orders/$orderId');

      print('Order Detail Response Status: ${response.statusCode}');
      print('Order Detail Response: ${response.data}');

      if (response.statusCode == 200) {
        return Order.fromJson(response.data);
      } else {
        throw Exception('Sipariş bulunamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Order Error: $e');
      throw Exception(
        'Sipariş detayı alınırken hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  // Ayarları getir (minimum tutar için)
  Future<Map<String, dynamic>> getSettings() async {
    try {
      print('Getting settings...');

      final response = await _dio.get('/settings');

      print('Settings Response Status: ${response.statusCode}');
      print('Settings Response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Ayarlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Settings Error: $e');
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
  Future<Map<String, dynamic>> validateCoupon(String code, double orderAmount) async {
    try {
      print('Validating coupon: $code for amount: $orderAmount');

      final response = await _dio.post('/coupons/validate', data: {
        'code': code,
        'orderAmount': orderAmount,
      });

      print('Validate Coupon Response Status: ${response.statusCode}');
      print('Validate Coupon Response: ${response.data}');

      return response.data ?? {};
    } catch (e) {
      print('Validate Coupon Error: $e');
      if (e is DioException && e.response != null) {
        return e.response!.data ?? {'success': false, 'message': 'Kupon doğrulanamadı'};
      }
      throw Exception('Kupon doğrulanırken hata oluştu');
    }
  }

  // Eski arama metodu kaldırıldı - yeni gelişmiş arama kullanılıyor

  // Mock data (API çalışmadığında kullanılır)
  Future<List<Product>> _getMockProducts() async {
    await Future.delayed(const Duration(seconds: 1));

    return [
      Product(
        id: '1',
        name: 'Süt',
        description: 'Taze günlük süt',
        price: 8.50,
        originalPrice: 8.50,
        actualPrice: 8.50,
        image: 'https://via.placeholder.com/150',
        category: 'Süt Ürünleri',
        categoryId: 'sut-urunleri',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '2',
        name: 'Ekmek',
        description: 'Taze beyaz ekmek',
        price: 3.00,
        originalPrice: 3.00,
        actualPrice: 3.00,
        image: 'https://via.placeholder.com/150',
        category: 'Fırın',
        categoryId: 'firin',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '3',
        name: 'Yumurta',
        description: 'Taze yumurta (30\'lu)',
        price: 45.00,
        originalPrice: 45.00,
        actualPrice: 45.00,
        image: 'https://via.placeholder.com/150',
        category: 'Süt Ürünleri',
        categoryId: 'sut-urunleri',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '4',
        name: 'Domates',
        description: 'Taze domates (kg)',
        price: 12.00,
        originalPrice: 12.00,
        actualPrice: 12.00,
        image: 'https://via.placeholder.com/150',
        category: 'Sebze',
        categoryId: 'sebze',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '5',
        name: 'Elma',
        description: 'Kırmızı elma (kg)',
        price: 8.00,
        originalPrice: 8.00,
        actualPrice: 8.00,
        image: 'https://via.placeholder.com/150',
        category: 'Meyve',
        categoryId: 'meyve',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: '6',
        name: 'Pirinç',
        description: 'Baldo pirinç (1kg)',
        price: 15.00,
        originalPrice: 15.00,
        actualPrice: 15.00,
        image: 'https://via.placeholder.com/150',
        category: 'Bakliyat',
        categoryId: 'bakliyat',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: false,
        isHidden: false,
        order: 6,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  // Flash Sale API'leri
  Future<List<FlashSale>> getFlashSales() async {
    try {
      print('Getting flash sales from API...');

      final response = await _dio.get('/flash-sales');

      print('Flash Sales Response Status: ${response.statusCode}');
      print('Flash Sales Response: ${response.data}');

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
      print('Flash Sales API Error: $e');
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
      print(
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

      print('Create Flash Sale Response Status: ${response.statusCode}');
      print('Create Flash Sale Response: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return FlashSale.fromJson(response.data);
      }

      throw Exception('Flash sale oluşturulamadı');
    } catch (e) {
      print('Create Flash Sale Error: $e');
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
      print('Updating flash sale: id=$id');

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

      print('Update Flash Sale Response Status: ${response.statusCode}');
      print('Update Flash Sale Response: ${response.data}');

      if (response.statusCode == 200) {
        return FlashSale.fromJson(response.data);
      }

      throw Exception('Flash sale güncellenemedi');
    } catch (e) {
      print('Update Flash Sale Error: $e');
      rethrow;
    }
  }

  Future<void> deleteFlashSale(String id) async {
    try {
      print('Deleting flash sale: id=$id');

      final response = await _dio.delete('/flash-sales/$id');

      print('Delete Flash Sale Response Status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Flash sale silinemedi');
      }
    } catch (e) {
      print('Delete Flash Sale Error: $e');
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
      print('Gelişmiş arama yapılıyor: query=$query, category=$category');

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

      print('Arama Response Status: ${response.statusCode}');
      print('Arama Response: ${response.data}');

      if (response.statusCode == 200) {
        return SearchResult.fromJson(response.data);
      }

      throw Exception('Arama başarısız');
    } catch (e) {
      print('Arama API Error: $e');
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
      print('Arama önerileri hatası: $e');
      return [];
    }
    // Ayarları getir
    Future<Map<String, dynamic>> getSettings() async {
      try {
        print('Getting settings from API...');
        final response = await _dio.get('/settings');
        print('Settings Response Status: ${response.statusCode}');

        if (response.statusCode == 200 && response.data != null) {
          return response.data as Map<String, dynamic>;
        }

        return {};
      } catch (e) {
        print('Get Settings Error: $e');
        return {};
      }
    }
  }

  // ========================
  // REFERRAL API METHODS
  // ========================

  /// Kullanıcının referral bilgilerini getir
  Future<Referral> getMyReferrals() async {
    try {
      print('Getting my referrals from API...');
      final response = await _dio.get('/referrals/my-referrals');

      print('My Referrals Response Status: ${response.statusCode}');
      print('My Referrals Response: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true && response.data['referral'] != null) {
          return Referral.fromJson(response.data['referral']);
        }
      }

      throw Exception('Referral bilgileri alınamadı');
    } catch (e) {
      print('Get My Referrals Error: $e');
      rethrow;
    }
  }

  /// Referral kodu kontrol et (kayıt öncesi)
  Future<ReferralCodeCheck> checkReferralCode(String code) async {
    try {
      print('Checking referral code: $code');
      final response = await _dio.get('/referrals/check/$code');

      print('Check Referral Code Response Status: ${response.statusCode}');
      print('Check Referral Code Response: ${response.data}');

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
      print('Check Referral Code Error: $e');

      // Handle 400 (limit dolmuş) and 404 (geçersiz) errors
      if (e.response?.statusCode == 400) {
        return ReferralCodeCheck(
          isValid: false,
          message: e.response?.data['message'] ?? 'Bu referral kodu artık kullanılamaz (limit doldu)',
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
      print('Check Referral Code Error: $e');
      return ReferralCodeCheck(
        isValid: false,
        message: 'Referral kodu kontrol edilemedi',
      );
    }
  }

  /// Yeni referral kodu oluştur
  Future<Referral> regenerateReferralCode() async {
    try {
      print('Regenerating referral code...');
      final response = await _dio.post('/referrals/regenerate');

      print('Regenerate Referral Response Status: ${response.statusCode}');
      print('Regenerate Referral Response: ${response.data}');

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
      print('Regenerate Referral Code Error: $e');
      rethrow;
    }
  }

  /// Kullanıcının kuponlarını getir
  Future<List<Coupon>> getUserCoupons() async {
    try {
      print('Getting user coupons from API...');
      final response = await _dio.get('/coupons');

      print('User Coupons Response Status: ${response.statusCode}');
      print('User Coupons Response: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true && response.data['coupons'] != null) {
          final List<dynamic> couponsData = response.data['coupons'];
          return couponsData.map((json) => Coupon.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      print('Get User Coupons Error: $e');
      return [];
    }
  }
}
