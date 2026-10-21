import 'package:flutter/foundation.dart';
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

  /// iOS mu? (Testlerde flutter_test varsayılanı Android'dir.)
  static bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Mağaza adıyla buton metni. Türkçe ek (-de/-da) mağaza adına göre değiştiği
  /// için metinler parça parça birleştirilmez.
  String get storeCta => isIos ? "App Store'da puan ver" : "Google Play'de puan ver";

  /// Mağaza puanı isteyen soru metni.
  String get storeAsk =>
      isIos ? "Bizi App Store'da puanlar mısın?" : "Bizi Google Play'de puanlar mısın?";

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

  /// Sipariş verildiğinde çağır. Yalnızca sayacı artırır: mağaza puan
  /// penceresi ödeme sırasında (sipariş daha teslim edilmeden, onay ekranına
  /// geçilmeden) açılmaz. Pencere, teslimattan sonraki uygulama açılışında
  /// OrderFeedbackCoordinator → [requestReviewForDeliveredOrders] ile denenir.
  Future<void> onOrderCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_orderCountKey) ?? 0;
    await prefs.setInt(_orderCountKey, currentCount + 1);

    AppLogger.debug('📝 Review: Sipariş tamamlandı (toplam: ${currentCount + 1})');
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

  /// Uygulama içinden mağaza puanı önerilebilir mi (teşekkür ekranındaki
  /// kart): kullanıcı zaten puan verdiyse ya da son 30 günde mağaza açıldıysa /
  /// puan penceresi istendiyse önerilmez.
  Future<bool> canSuggestStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_hasReviewedKey) ?? false) return false;
      final lastRequest = prefs.getInt(_lastReviewRequestKey);
      if (lastRequest == null) return true;
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastRequest))
          .inDays;
      return days >= _daysBetweenRequests;
    } catch (_) {
      return false;
    }
  }

  /// Mağaza sayfasına yönlendir (fallback için). Sayfa açıldıysa true,
  /// açılamadıysa false döner. Açıldıysa puan penceresi 30 gün beklenir
  /// (kullanıcı az önce mağazaya gittiyse hemen ardından tekrar sorulmaz).
  Future<bool> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: '6755792336', // App Store Connect Apple ID (codemagic.yaml ile aynı)
        // Google Play için package name otomatik kullanılır
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastReviewRequestKey, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {
        // Bekleme süresi kaydedilemese de mağaza açıldı
      }
      return true;
    } catch (e) {
      AppLogger.debug('📝 Review: Store listing açılamadı: $e');
      return false;
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
