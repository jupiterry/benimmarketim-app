import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

// Sunucudaki ABANDON_REASONS ile aynı kimlikler (backend/lib/feedbackOptions.js)
const _reasons = [
  FeedbackOption('fiyat', 'Fiyatlar yüksek'),
  FeedbackOption('teslimat', 'Teslimat süresi uzun'),
  FeedbackOption('urun_yok', 'Aradığım ürün yok'),
  FeedbackOption('minimum', 'Minimum sepet tutarı yüksek'),
  FeedbackOption('sonra', 'Sonra sipariş vereceğim'),
  FeedbackOption('diger', 'Diğer'),
];
const _interval = Duration(days: 7);

/// Sepetini boşaltan müşteriye tek soru: "Sepetini neden boşalttın?".
/// Haftada en fazla bir kez, yalnızca giriş yapmış kullanıcıya sorulur.
Future<void> maybeAskAbandonReason(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final userId = auth.user?.id;
  if (!auth.isLoggedIn || userId == null || userId.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'abandon_asked_$userId';
  final last = prefs.getInt(key) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - last < _interval.inMilliseconds) return;
  await prefs.setInt(key, now);
  if (!context.mounted) return;
  await showMarketSheet<void>(context, builder: (_) => const _AbandonReasonSheet());
}

class _AbandonReasonSheet extends StatefulWidget {
  const _AbandonReasonSheet();

  @override
  State<_AbandonReasonSheet> createState() => _AbandonReasonSheetState();
}

class _AbandonReasonSheetState extends State<_AbandonReasonSheet> {
  final TextEditingController _note = TextEditingController();
  String? _picked;
  bool _sent = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _pick(String reason) {
    if (_sent || _timer != null) return;
    if (reason == 'diger') {
      // "Diğer": kısa açıklama yazılabilsin diye hemen gönderilmez
      setState(() => _picked = _picked == 'diger' ? null : 'diger');
      return;
    }
    // Seçim kısa bir an görünsün, sonra teşekkür
    setState(() => _picked = reason);
    _timer = Timer(const Duration(milliseconds: 250), () => _send(reason));
  }

  void _send(String reason) {
    if (!mounted || _sent) return;
    // Yanıt beklenmeden teşekkür edilir; gönderim hatası kullanıcıyı ilgilendirmez
    unawaited(ApiService().submitAbandonReason(
      reason: reason,
      note: reason == 'diger' ? _note.text : '',
    ));
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() => _sent = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _sent
        ? MarketSheetScaffold(
            key: const ValueKey('sent'),
            bodyPadding: feedbackThanksPadding,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: MarketIconTile(
                    icon: Icons.favorite_rounded,
                    size: 52,
                    background: MarketPalette.greenSoft,
                    foreground: MarketPalette.green,
                  ),
                ),
                const SizedBox(height: MarketSpace.lg),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text('Teşekkürler, not aldık!',
                      textAlign: TextAlign.center, style: MarketText.title()),
                ),
                const SizedBox(height: MarketSpace.sm),
                Text(
                  'Yanıtın daha iyi bir market olmamıza yardım ediyor.',
                  textAlign: TextAlign.center,
                  style: MarketText.body(color: MarketPalette.muted, size: 14),
                ),
                const SizedBox(height: MarketSpace.lg),
              ],
            ),
          )
        : _buildAsk();
    return FeedbackReveal(
      child: AnimatedSwitcher(
        duration: feedbackMotion(context),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: content,
      ),
    );
  }

  Widget _buildAsk() {
    final other = _picked == 'diger';
    return FeedbackFormScaffold(
      key: const ValueKey('ask'),
      header: MarketSheetHeader(
        title: 'Sepetini neden boşalttın?',
        // Kısa ekranda alt yazı yok: seçeneklere (ve "Diğer" notuna) yer kalsın
        subtitle: feedbackShortScreen(context)
            ? null
            : 'Tek dokunuş yeter; daha iyisini yapmamıza yardım eder.',
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FeedbackChipWrap(
            children: [
              for (final reason in _reasons)
                FeedbackChip(
                  label: reason.label,
                  selected: _picked == reason.id,
                  onTap: () => _pick(reason.id),
                ),
            ],
          ),
          FeedbackReveal(
            child: !other
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: MarketSpace.md),
                    child: FeedbackCommentField(
                      controller: _note,
                      hint: 'Kısaca yazar mısın? (isteğe bağlı)',
                      maxLength: 200,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
          ),
          if (!other) ...[
            const SizedBox(height: MarketSpace.sm),
            Center(child: FeedbackLaterButton(onPressed: () => Navigator.of(context).pop())),
          ],
        ],
      ),
      // "Diğer" seçiliyken "Gönder" sabit alt kısımda: klavye açıkken de görünür
      footer: other
          ? FeedbackSheetFooter(
              busy: false,
              onSubmit: () => _send('diger'),
              onLater: () => Navigator.of(context).pop(),
            )
          : null,
    );
  }
}
