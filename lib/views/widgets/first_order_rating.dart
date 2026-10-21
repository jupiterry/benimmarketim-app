import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

/// İlk siparişten sonra sipariş onay ekranında gösterilen puanlama isteği.
///
/// Akış:
/// * order_page, sipariş BAŞARIYLA oluşturulduktan sonra (siparişi asla
///   bekletmeden / engellemeden) kullanıcı daha önce hiç geri bildirim
///   vermediyse [FirstOrderRating.pending] değerini true yapar ve onay
///   ekranına geçer.
/// * Sipariş onay ekranı [FirstOrderRatingCard]'ı gösterir; kart
///   [FirstOrderRating.pending] false ise hiçbir şey çizmez.
/// * Kart gösterildiğinde (gönderilse de, geçilse de) [FirstOrderRating.pending]
///   değerini false yapar; istek bir kez görünür.
/// * Kart kullanıcı başına yalnızca BİR kez gösterilir (cihazda saklanır).
///   Sipariş artık puan vermeden de verilebildiği için kartı kapatan ya da
///   geçen kullanıcı sunucuda hâlâ "geri bildirim vermedi" görünür; kayıt
///   olmasa sonraki her siparişte "İlk siparişin geliyor!" yeniden çıkardı.
abstract final class FirstOrderRating {
  static bool _pending = false;
  static SharedPreferences? _prefs;

  /// Onay ekranında ilk sipariş puan kartı gösterilecek mi.
  static bool get pending => _pending;
  static set pending(bool value) {
    _pending = value;
    _prefs = null;
    // "Daha önce gösterildi" kaydı onay ekranı açılmadan okunsun: kart ilk
    // karede doğru çizilir (sonradan belirip düğmeleri kaydırmaz).
    if (value) {
      SharedPreferences.getInstance().then<void>(
        (prefs) => _prefs = prefs,
        onError: (Object _) {},
      );
    }
  }

  static String _shownKey(String userId) => 'first_order_rating_shown_$userId';

  /// Bu kullanıcıya kart daha önce gösterilmediyse gösterildi diye kaydeder
  /// ve true döner.
  static bool _claim(SharedPreferences prefs, String userId) {
    final key = _shownKey(userId);
    if (prefs.getBool(key) ?? false) return false;
    prefs.setBool(key, true).catchError((Object _) => false);
    return true;
  }
}

/// Sipariş onay ekranındaki ilk sipariş puan kartı (sayfanın içinde, engellemez).
///
/// Yıldızlar boş başlar (önceden seçili puan yok). İlk yıldıza dokununca
/// isteğe bağlı yorum alanı ve "Gönder" açılır. Gönderim eski ilk sipariş
/// penceresiyle aynıdır (POST /feedback, "Genel Değerlendirme"). Sağ üstteki
/// ✕ kartı kapatır. Sözleşme: `const FirstOrderRatingCard()` olarak eklenir,
/// [FirstOrderRating.pending] false ise boş kalır.
class FirstOrderRatingCard extends StatefulWidget {
  const FirstOrderRatingCard({super.key});

  @override
  State<FirstOrderRatingCard> createState() => _FirstOrderRatingCardState();
}

enum _CardState { asking, sending, sent, hidden }

class _FirstOrderRatingCardState extends State<FirstOrderRatingCard> {
  final TextEditingController _message = TextEditingController();
  late _CardState _state;
  int _rating = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Bir kez gösterilir: bayrak hemen sıfırlanır (sayfa yeniden kurulsa da
    // ikinci kez çıkmaz, ek istek atılmaz).
    final wanted = FirstOrderRating._pending;
    final prefs = FirstOrderRating._prefs;
    FirstOrderRating._pending = false;
    FirstOrderRating._prefs = null;
    _state = _CardState.hidden;
    if (!wanted) return;
    final userId = _userId();
    if (prefs != null) {
      if (FirstOrderRating._claim(prefs, userId)) _state = _CardState.asking;
    } else {
      _claimLater(userId);
    }
  }

  String _userId() {
    try {
      return context.read<AuthViewModel>().user?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Kayıt henüz okunmadıysa: okununca gösterilir. Okunamazsa kart yine
  /// gösterilir (eski davranış).
  Future<void> _claimLater(String userId) async {
    var show = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      show = FirstOrderRating._claim(prefs, userId);
    } catch (_) {}
    if (mounted && show) setState(() => _state = _CardState.asking);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() {
      _rating = value;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_state == _CardState.sending || _rating == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _state = _CardState.sending;
      _error = null;
    });
    try {
      await ApiService().createFeedback(
        rating: _rating,
        ratings: {'overall': _rating},
        title: 'Genel Değerlendirme',
        message: _message.text.trim(),
        category: 'Genel',
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _state = _CardState.sent);
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _state = _CardState.asking;
        _error = 'Gönderilemedi. Bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  void _close() {
    FocusScope.of(context).unfocus();
    setState(() => _state = _CardState.hidden);
  }

  @override
  Widget build(BuildContext context) {
    final duration = feedbackMotion(context);
    final asking = _state != _CardState.sent;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _state == _CardState.hidden
          ? const SizedBox(width: double.infinity)
          : MarketCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(MarketSpace.lg),
                    child: AnimatedSwitcher(
                      duration: duration,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                      child: asking ? _buildAsk() : _buildThanks(),
                    ),
                  ),
                  // Kapat (✕) kartın köşesinde durur; başlık yazısı altına girmez,
                  // dar ekranlarda alt yazı tüm genişliği kullanır.
                  if (asking)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message: 'Kapat',
                        child: InkResponse(
                          onTap: _state == _CardState.sending ? null : _close,
                          radius: 22,
                          child: const SizedBox(
                            width: MarketSize.tapTarget,
                            height: MarketSize.tapTarget,
                            child: Icon(Icons.close_rounded, size: 20, color: MarketPalette.muted),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildThanks() {
    return KeyedSubtree(
      key: const ValueKey('sent'),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const MarketIconTile(
              icon: Icons.check_circle_rounded,
              size: 44,
              background: MarketPalette.greenSoft,
              foreground: MarketPalette.green,
            ),
            const SizedBox(width: MarketSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teşekkürler!', style: MarketText.heading(size: 16)),
                  const SizedBox(height: 2),
                  Text(
                    'Puanın bize ulaştı. İyi alışverişler!',
                    style: MarketText.body(color: MarketPalette.greenDark, size: 13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsk() {
    final sending = _state == _CardState.sending;
    // Dar ekranlarda (320 pt) simge küçülür, yazıya yer kalır
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Column(
      key: const ValueKey('ask'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarketIconTile(
              icon: Icons.celebration_rounded,
              size: narrow ? 40 : 44,
              background: MarketPalette.lime,
              foreground: MarketPalette.greenDeep,
            ),
            const SizedBox(width: MarketSpace.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // Köşedeki ✕ için yer
                      padding: const EdgeInsets.only(right: 28),
                      child: Semantics(
                        header: true,
                        child: Text('İlk siparişin geliyor! 🎉', style: MarketText.heading(size: 16)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sipariş vermek nasıldı? Puanın bizi geliştiriyor.',
                      style: MarketText.caption(color: MarketPalette.muted, size: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MarketSpace.sm),
        FeedbackStars(
          value: _rating,
          onChanged: sending ? null : _setRating,
          size: 36,
        ),
        FeedbackReveal(
          child: _rating == 0
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: MarketSpace.md),
                    TextField(
                      controller: _message,
                      enabled: !sending,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      // Klavye açılınca "Gönder" de görünsün
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      style: MarketText.body(size: 14),
                      decoration: const InputDecoration(
                        hintText: 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
                        counterText: '',
                        fillColor: MarketPalette.canvas,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: MarketSpace.sm),
                      FeedbackFieldError(_error!),
                    ],
                    const SizedBox(height: MarketSpace.md),
                    FeedbackSubmitButton(
                      label: _error != null ? 'Tekrar dene' : 'Gönder',
                      busy: sending,
                      height: MarketSize.tapTarget,
                      onPressed: _submit,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
