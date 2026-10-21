import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../views/widgets/feedback_parts.dart';
import '../views/widgets/nps_sheet.dart';
import '../views/widgets/order_feedback_sheet.dart';
import '../views/widgets/quick_feedback_sheet.dart';
import 'api_service.dart';
import 'app_logger.dart';
import 'review_service.dart';

/// Sipariş sonrası geri bildirimi yönetir. Uygulama açılışında, oturum başına bir kez
/// çalışır ve en fazla BİR soru gösterir (müşteri anketten bıkmasın):
/// 1) 1., 3. ve 5. teslim edilen siparişte detaylı anket
/// 2) diğer siparişlerde tek dokunuşluk 👍/👎
/// 3) ayda bir "Bizi bir arkadaşına önerir misin?" (NPS)
/// Hiçbiri yoksa mağaza puan penceresi denenir.
class OrderFeedbackCoordinator {
  OrderFeedbackCoordinator._();

  static const int _maxDismissals = 2; // Aynı anket en fazla 2 kez ertelenebilir
  static const Duration _snooze = Duration(days: 3);
  static String? _checkedForUser;

  static String _snoozeKey(String userId, int milestone) =>
      'order_feedback_snooze_${userId}_$milestone';
  static String _dismissKey(String userId, int milestone) =>
      'order_feedback_dismiss_${userId}_$milestone';
  // "Şimdi değil" denen hızlı soru o sipariş için bir daha sorulmaz
  static String _quickSkipKey(String userId, String orderId) =>
      'quick_feedback_skip_${userId}_$orderId';
  static String _npsSkipKey(String userId) => 'nps_skip_until_$userId';
  static const Duration _npsSnooze = Duration(days: 14);

  static Future<void> run(BuildContext context) async {
    try {
      final auth = context.read<AuthViewModel>();
      if (!auth.isLoggedIn) return;
      // Profil açılışta arka planda yüklenir; kullanıcı bilgisi gelene kadar kısa süre bekle
      for (var attempt = 0; attempt < 20 && auth.user == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      final userId = auth.user?.id;
      if (!auth.isLoggedIn || userId == null || userId.isEmpty) return;
      if (_checkedForUser == userId) return;
      _checkedForUser = userId;

      final data = await ApiService().getOrderFeedbackPrompt();
      if (data == null) return;
      final deliveredCount = (data['deliveredCount'] as num?)?.toInt() ?? 0;
      final prompt = data['prompt'];

      if (prompt is Map && prompt['milestone'] is num) {
        final milestone = (prompt['milestone'] as num).toInt();
        final prefs = await SharedPreferences.getInstance();
        final dismissals = prefs.getInt(_dismissKey(userId, milestone)) ?? 0;
        final snoozedUntil = prefs.getInt(_snoozeKey(userId, milestone)) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (dismissals < _maxDismissals && now >= snoozedUntil) {
          // Ana sayfa yerleşsin diye kısa bir bekleme
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (!context.mounted) return;
          final submitted = await showOrderFeedbackSheet(
            context,
            milestone: milestone,
            orderId: prompt['orderId'] as String?,
            order: FeedbackOrder.fromJson(prompt['order']),
          );
          if (!submitted) {
            await prefs.setInt(_dismissKey(userId, milestone), dismissals + 1);
            await prefs.setInt(
              _snoozeKey(userId, milestone),
              DateTime.now().add(_snooze).millisecondsSinceEpoch,
            );
          }
          return; // Anket gösterilen oturumda mağaza penceresi açılmaz
        }
        if (now < snoozedUntil) return; // Ertelenmiş anket varken rahatsız etme
      }

      // Hızlı soru: son teslim edilen sipariş
      final quick = FeedbackOrder.fromJson(data['quick']);
      if (quick != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_quickSkipKey(userId, quick.orderId)) ?? false)) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (!context.mounted) return;
          final answered = await showQuickFeedbackSheet(context, order: quick);
          if (!answered) await prefs.setBool(_quickSkipKey(userId, quick.orderId), true);
          return;
        }
      }

      // Aylık tavsiye sorusu
      if (data['nps'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now >= (prefs.getInt(_npsSkipKey(userId)) ?? 0)) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (!context.mounted) return;
          final answered = await showNpsSheet(context);
          if (!answered) {
            await prefs.setInt(_npsSkipKey(userId),
                DateTime.now().add(_npsSnooze).millisecondsSinceEpoch);
          }
          return;
        }
      }

      await ReviewService.instance.requestReviewForDeliveredOrders(deliveredCount);
    } catch (e) {
      AppLogger.debug('Sipariş anketi kontrolü hatası: $e');
    }
  }
}
