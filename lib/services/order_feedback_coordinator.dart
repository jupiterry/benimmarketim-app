import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../views/widgets/feedback_parts.dart';
import '../views/widgets/meta_consent_sheet.dart';
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
/// 3) ayda bir "Benim Marketim'i bir arkadaşına ne kadar önerirsin?" (NPS)
/// Hiçbiri yoksa mağaza puan penceresi denenir.
///
/// Sorular yalnızca ana sayfa en üstteyken açılır (ürün detayı, ödeme gibi bir
/// sayfa, başka bir pencere ya da klavye açıkken araya girilmez). Aynı açılışta
/// reklam ölçümü izni sorulduysa ikinci bir pencere açılmaz.
class OrderFeedbackCoordinator {
  OrderFeedbackCoordinator._();

  static const int _maxDismissals = 2; // Aynı anket en fazla 2 kez ertelenebilir
  static const Duration _snooze = Duration(days: 3);
  static String? _checkedForUser;

  // Ana sayfanın en üstte kalmasını bekleme ayarları
  static const Duration _pollEvery = Duration(milliseconds: 500);
  static const Duration _settleFor = Duration(milliseconds: 1200);
  static const Duration _giveUpAfter = Duration(minutes: 2);

  static String _snoozeKey(String userId, int milestone) =>
      'order_feedback_snooze_${userId}_$milestone';
  static String _dismissKey(String userId, int milestone) =>
      'order_feedback_dismiss_${userId}_$milestone';
  // "Şimdi değil" denen hızlı soru o sipariş için bir daha sorulmaz
  static String _quickSkipKey(String userId, String orderId) =>
      'quick_feedback_skip_${userId}_$orderId';
  static String _npsSkipKey(String userId) => 'nps_skip_until_$userId';
  static const Duration _npsSnooze = Duration(days: 14);

  /// Ana sayfa sekmesi görünür mü (run'a verilir; verilmezse hep görünür sayılır).
  static bool Function()? _isVisible;

  /// Ana sayfanın (context'in sayfası) üstünde başka sayfa, pencere ya da klavye yok mu.
  static bool _homeIsTop(BuildContext context) {
    if (!context.mounted) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    if (!(_isVisible?.call() ?? true)) return false;
    return MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  /// Ana sayfa [_settleFor] boyunca kesintisiz en üstte kalana kadar bekler.
  /// [_giveUpAfter] içinde olmazsa ya da sayfa kapanırsa false döner (o zaman
  /// erteleme/atlama kaydı yazılmaz; soru bir sonraki açılışta yeniden gelir).
  static Future<bool> _waitUntilHomeIsTop(BuildContext context) async {
    final needed = (_settleFor.inMilliseconds / _pollEvery.inMilliseconds).ceil();
    final maxPolls = _giveUpAfter.inMilliseconds ~/ _pollEvery.inMilliseconds;
    var stablePolls = 0;
    for (var poll = 0; poll < maxPolls; poll++) {
      await Future<void>.delayed(_pollEvery);
      if (!context.mounted) return false;
      stablePolls = _homeIsTop(context) ? stablePolls + 1 : 0;
      if (stablePolls >= needed) return context.read<AuthViewModel>().isLoggedIn;
    }
    return false;
  }

  /// [isVisible]: ana sayfa sekmesi şu an seçili mi (ör. sepet sekmesindeyken
  /// soru açılmasın diye). Verilmezse yalnızca sayfa / pencere / klavye kontrol edilir.
  static Future<void> run(BuildContext context, {bool Function()? isVisible}) async {
    _isVisible = isVisible;
    try {
      // Reklam ölçümü izni bu açılışta sorulduysa ikinci pencere açma
      if (metaConsentPromptedThisSession) return;
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
          if (!context.mounted || !await _waitUntilHomeIsTop(context)) return;
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
          if (!context.mounted || !await _waitUntilHomeIsTop(context)) return;
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
          if (!context.mounted || !await _waitUntilHomeIsTop(context)) return;
          if (!context.mounted) return;
          final answered = await showNpsSheet(context);
          if (!answered) {
            await prefs.setInt(_npsSkipKey(userId),
                DateTime.now().add(_npsSnooze).millisecondsSinceEpoch);
          }
          return;
        }
      }

      // Mağaza puan penceresi de yalnızca ana sayfa en üstteyken denenir;
      // değilse bu açılışta atlanır (koşullar bir sonraki açılışta yine bakılır).
      if (!context.mounted || !_homeIsTop(context)) return;
      await ReviewService.instance.requestReviewForDeliveredOrders(deliveredCount);
    } catch (e) {
      AppLogger.debug('Sipariş anketi kontrolü hatası: $e');
    } finally {
      _isVisible = null;
    }
  }
}
