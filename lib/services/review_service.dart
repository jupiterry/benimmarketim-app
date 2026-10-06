import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Uygulama içi değerlendirme servisi
/// App Store ve Google Play'de puan isteme işlemlerini yönetir
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  static ReviewService get instance => _instance;

  final InAppReview _inAppReview = InAppReview.instance;

  // SharedPreferences anahtarları
  static const String _lastReviewRequestKey = 'last_review_request';
  static const String _reviewRequestCountKey = 'review_request_count';
  static const String _hasReviewedKey = 'has_reviewed';
  static const String _orderCountKey = 'completed_order_count';

  // Değerlendirme isteme koşulları
  static const int _minOrdersBeforeReview = 2; // En az 2 sipariş tamamlamış olmalı
  static const int _daysBetweenRequests = 30; // İstekler arasında en az 30 gün
  static const int _maxReviewRequests = 3; // Maksimum 3 kere sor

  /// Değerlendirme isteyip istemeyeceğini kontrol et
  Future<bool> shouldRequestReview() async {
    final prefs = await SharedPreferences.getInstance();

    // Zaten değerlendirme yaptıysa sorma
    final hasReviewed = prefs.getBool(_hasReviewedKey) ?? false;
    if (hasReviewed) {
      AppLogger.debug('📝 Review: Kullanıcı zaten değerlendirme yapmış');
      return false;
    }

    // Maksimum istek sayısına ulaştıysa sorma
    final requestCount = prefs.getInt(_reviewRequestCountKey) ?? 0;
    if (requestCount >= _maxReviewRequests) {
      AppLogger.debug('📝 Review: Maksimum istek sayısına ulaşıldı ($requestCount)');
      return false;
    }

    // Yeterli sipariş tamamlamadıysa sorma
    final orderCount = prefs.getInt(_orderCountKey) ?? 0;
    if (orderCount < _minOrdersBeforeReview) {
      AppLogger.debug('📝 Review: Yeterli sipariş yok ($orderCount < $_minOrdersBeforeReview)');
      return false;
    }

    // Son istekten bu yana yeterli zaman geçmediyse sorma
    final lastRequest = prefs.getInt(_lastReviewRequestKey);
    if (lastRequest != null) {
      final lastRequestDate = DateTime.fromMillisecondsSinceEpoch(lastRequest);
      final daysSinceLastRequest = DateTime.now().difference(lastRequestDate).inDays;
      if (daysSinceLastRequest < _daysBetweenRequests) {
        AppLogger.debug('📝 Review: Henüz yeterli zaman geçmedi ($daysSinceLastRequest gün < $_daysBetweenRequests gün)');
        return false;
      }
    }

    // In-app review kullanılabilir mi kontrol et
    final isAvailable = await _inAppReview.isAvailable();
    if (!isAvailable) {
      AppLogger.debug('📝 Review: In-app review kullanılamıyor');
      return false;
    }

    AppLogger.debug('📝 Review: Değerlendirme istenebilir!');
    return true;
  }

  /// Değerlendirme iste
  Future<void> requestReview() async {
    try {
      final shouldRequest = await shouldRequestReview();
      if (!shouldRequest) return;

      AppLogger.debug('📝 Review: Değerlendirme isteniyor...');
      
      // In-app review göster
      await _inAppReview.requestReview();

      // İstek sayısını ve zamanını kaydet
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_reviewRequestCountKey) ?? 0;
      await prefs.setInt(_reviewRequestCountKey, currentCount + 1);
      await prefs.setInt(_lastReviewRequestKey, DateTime.now().millisecondsSinceEpoch);

      AppLogger.debug('📝 Review: Değerlendirme istendi (toplam istek: ${currentCount + 1})');
    } catch (e) {
      AppLogger.debug('📝 Review Error: $e');
    }
  }

  /// Sipariş tamamlandığında çağır
  Future<void> onOrderCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_orderCountKey) ?? 0;
    await prefs.setInt(_orderCountKey, currentCount + 1);
    
    AppLogger.debug('📝 Review: Sipariş tamamlandı (toplam: ${currentCount + 1})');

    // Değerlendirme istemeyi dene (koşullar sağlanıyorsa)
    await requestReview();
  }

  /// Sunucudan gelen teslim edilmiş sipariş sayısıyla mağaza puan penceresini dener.
  /// Pencere yalnızca sipariş sayısı ve süre koşullarına bağlıdır; müşterinin
  /// uygulama içinde verdiği puana göre gösterilmez veya gizlenmez.
  Future<void> requestReviewForDeliveredOrders(int deliveredCount) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_orderCountKey) ?? 0;
    if (deliveredCount > stored) {
      await prefs.setInt(_orderCountKey, deliveredCount);
    }
    await requestReview();
  }

  /// Kullanıcı değerlendirme yaptığını işaretle (opsiyonel - kullanıcı feedback verirse)
  Future<void> markAsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasReviewedKey, true);
    AppLogger.debug('📝 Review: Kullanıcı değerlendirme yaptı olarak işaretlendi');
  }

  /// Mağaza sayfasına yönlendir (fallback için)
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: '6755705908', // App Store ID'niz
        // Google Play için package name otomatik kullanılır
      );
    } catch (e) {
      AppLogger.debug('📝 Review: Store listing açılamadı: $e');
    }
  }

  /// Debug için istatistikleri göster
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'orderCount': prefs.getInt(_orderCountKey) ?? 0,
      'requestCount': prefs.getInt(_reviewRequestCountKey) ?? 0,
      'hasReviewed': prefs.getBool(_hasReviewedKey) ?? false,
      'lastRequest': prefs.getInt(_lastReviewRequestKey),
      'isAvailable': await _inAppReview.isAvailable(),
    };
  }

  /// Test için verileri sıfırla
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReviewRequestKey);
    await prefs.remove(_reviewRequestCountKey);
    await prefs.remove(_hasReviewedKey);
    await prefs.remove(_orderCountKey);
    AppLogger.debug('📝 Review: Test verileri sıfırlandı');
  }
}
