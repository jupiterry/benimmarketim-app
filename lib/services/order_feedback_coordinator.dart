import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../views/widgets/order_feedback_sheet.dart';
import 'api_service.dart';
import 'app_logger.dart';
import 'review_service.dart';

/// Sipariş sonrası deneyim anketini (1., 5. ve 15. teslim edilen sipariş) ve
/// mağaza puan penceresini yönetir. Uygulama açılışında, oturum başına bir kez
/// çalışır; ikisi aynı oturumda art arda gösterilmez.
class OrderFeedbackCoordinator {
  OrderFeedbackCoordinator._();

  static const int _maxDismissals = 2; // Aynı anket en fazla 2 kez ertelenebilir
  static const Duration _snooze = Duration(days: 3);
  static String? _checkedForUser;

  static String _snoozeKey(String userId, int milestone) =>
      'order_feedback_snooze_${userId}_$milestone';
  static String _dismissKey(String userId, int milestone) =>
      'order_feedback_dismiss_${userId}_$milestone';

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

      await ReviewService.instance.requestReviewForDeliveredOrders(deliveredCount);
    } catch (e) {
      AppLogger.debug('Sipariş anketi kontrolü hatası: $e');
    }
  }
}
