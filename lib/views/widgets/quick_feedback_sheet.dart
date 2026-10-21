import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

/// Her teslim edilen siparişten sonra tek dokunuşluk soru: "Siparişin nasıldı? 👍 / 👎".
/// 👍 hemen gönderilir; 👎'de "Ne oldu?" açılır (seçenek, sorunlu ürün, açıklama).
/// Yanıtlandıysa true döner.
Future<bool> showQuickFeedbackSheet(BuildContext context, {required FeedbackOrder order}) async {
  var submitted = false;
  final result = await showMarketSheet<bool>(
    context,
    builder: (_) => _QuickFeedbackSheet(order: order, onSubmitted: () => submitted = true),
  );
  return result ?? submitted;
}

enum _Step { ask, whatHappened, done }

class _QuickFeedbackSheet extends StatefulWidget {
  final FeedbackOrder order;
  final VoidCallback onSubmitted;

  const _QuickFeedbackSheet({required this.order, required this.onSubmitted});

  @override
  State<_QuickFeedbackSheet> createState() => _QuickFeedbackSheetState();
}

class _QuickFeedbackSheetState extends State<_QuickFeedbackSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _comment = TextEditingController();
  final Set<String> _tags = {};
  Map<String, String> _problems = {};
  _Step _step = _Step.ask;
  bool _happy = true;
  bool _sending = false;
  String? _sendingThumb;
  String? _error; // sunucu hatası
  bool _missing = false; // 👎: ne olduğu seçilmedi
  bool _dirty = false;
  String? _supportChatId;

  bool get _showProducts =>
      widget.order.products.isNotEmpty && _tags.any(feedbackProductTags.contains);

  @override
  void initState() {
    super.initState();
    _comment.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    // 5+ karakter yazıldıysa kapatmadan önce sorulur ve "seç ya da yaz" uyarısı kalkar
    final dirty = _comment.text.trim().length >= 5;
    if (dirty == _dirty && !(dirty && _missing)) return;
    setState(() {
      _dirty = dirty;
      if (dirty) _missing = false;
    });
  }

  void _toAsk() => setState(() {
        _step = _Step.ask;
        _error = null;
        _missing = false;
      });

  Future<void> _send({required String thumb}) async {
    if (_sending) return;
    final problems = thumb == 'down' && _showProducts
        ? problemItemsPayload(widget.order.products, _problems)
        : const <Map<String, String>>[];
    if (thumb == 'down' && _tags.isEmpty && problems.isEmpty && _comment.text.trim().length < 5) {
      HapticFeedback.mediumImpact();
      setState(() => _missing = true);
      return;
    }
    setState(() {
      _sending = true;
      _sendingThumb = thumb;
      _error = null;
      _missing = false;
    });
    final result = await _api.submitQuickFeedback(
      orderId: widget.order.orderId,
      thumb: thumb,
      tags: thumb == 'down' ? _tags.toList() : const [],
      comment: _comment.text,
      problemItems: problems,
    );
    if (result.ok) widget.onSubmitted();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendingThumb = null;
      _error = result.error;
      _supportChatId = result.supportChatId;
      if (result.ok) {
        _happy = thumb == 'up';
        _step = _Step.done;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget step = switch (_step) {
      _Step.ask => _buildAsk(),
      _Step.whatHappened => _buildWhatHappened(),
      _Step.done => MarketSheetScaffold(
          key: const ValueKey(_Step.done),
          bodyPadding: feedbackThanksPadding,
          body: FeedbackThanks(
            happy: _happy,
            supportChatId: _supportChatId,
            wroteComment: _comment.text.trim().isNotEmpty,
          ),
        ),
    };
    return FeedbackPopGuard(
      busy: _sending,
      dirty: _step == _Step.whatHappened && _dirty,
      onBack: _step == _Step.whatHappened && !_sending ? _toAsk : null,
      child: FeedbackReveal(
        child: AnimatedSwitcher(
          duration: feedbackMotion(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: step,
        ),
      ),
    );
  }

  Widget _buildAsk() {
    final order = widget.order;
    return MarketSheetScaffold(
      key: const ValueKey(_Step.ask),
      busy: _sending,
      header: MarketSheetHeader(
        title: 'Siparişin nasıldı?',
        subtitle: 'Tek dokunuşla söyle; sorun varsa hemen ilgilenelim.',
        meta: FeedbackOrderPill(order: order),
        onClose: _sending ? () {} : () => Navigator.of(context).pop(false),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.products.isNotEmpty) ...[
            _ProductStrip(products: order.products),
            const SizedBox(height: MarketSpace.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ThumbButton(
                  emoji: '👍',
                  label: 'İyiydi',
                  color: MarketPalette.green,
                  ink: MarketPalette.greenDark,
                  soft: MarketPalette.greenSoft,
                  busy: _sendingThumb == 'up',
                  dimmed: _sending && _sendingThumb != 'up',
                  onTap: _sending ? null : () => _send(thumb: 'up'),
                ),
              ),
              const SizedBox(width: MarketSpace.md),
              Expanded(
                child: _ThumbButton(
                  emoji: '👎',
                  label: 'Sorun vardı',
                  color: MarketPalette.red,
                  ink: MarketPalette.red,
                  soft: MarketPalette.redSoft,
                  busy: false,
                  dimmed: _sending,
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            _step = _Step.whatHappened;
                            _error = null;
                          }),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: MarketSpace.md),
            FeedbackErrorNotice(text: _error!),
          ],
          const SizedBox(height: MarketSpace.sm),
          Center(
            child: FeedbackLaterButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatHappened() {
    return MarketSheetScaffold(
      key: const ValueKey(_Step.whatHappened),
      busy: _sending,
      header: MarketSheetHeader(
        title: 'Ne oldu?',
        subtitle: feedbackShortScreen(context)
            ? null
            : 'Üzgünüz. Ne olduğunu seç, hemen ilgilenelim.',
        onBack: _sending ? () {} : _toAsk,
        onClose: _sending ? () {} : () => closeFeedbackSheet(context, dirty: _dirty),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FeedbackChipWrap(
            children: [
              for (final tag in feedbackNegativeTags)
                FeedbackChip(
                  label: tag.label,
                  negative: true,
                  selected: _tags.contains(tag.id),
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            if (!_tags.remove(tag.id)) _tags.add(tag.id);
                            _missing = false;
                          }),
                ),
            ],
          ),
          if (_missing) ...[
            const SizedBox(height: MarketSpace.sm),
            const FeedbackFieldError('Ne olduğunu seç ya da kısaca yaz.'),
          ],
          FeedbackReveal(
            child: _showProducts
                ? Padding(
                    padding: const EdgeInsets.only(top: MarketSpace.xl),
                    child: ProblemItemsPicker(
                      products: widget.order.products,
                      selected: _problems,
                      enabled: !_sending,
                      defaultIssue: feedbackDefaultIssue(_tags),
                      onChanged: (next) => setState(() => _problems = next),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: MarketSpace.xl),
          FeedbackCommentField(
            controller: _comment,
            enabled: !_sending,
            label: 'Eklemek istediğin bir şey var mı?',
            hint: 'İsteğe bağlı; ör. "Süt eksik geldi"',
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      footer: FeedbackSheetFooter(
        busy: _sending,
        serverError: _error,
        onSubmit: () => _send(thumb: 'down'),
      ),
    );
  }
}

/// Siparişteki ürünlerin üst üste binen küçük resimleri (en fazla 4, sonra "+N").
class _ProductStrip extends StatelessWidget {
  final List<FeedbackOrderProduct> products;
  const _ProductStrip({required this.products});

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    const step = 30.0;
    final shown = products.take(4).toList();
    final extra = products.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final names = products.map((p) => productDisplayName(p.name)).join(', ');
    return Semantics(
      label: 'Siparişteki ürünler: $names',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: size + step * (count - 1),
              height: size,
              child: Stack(
                children: [
                  for (var i = 0; i < count; i++)
                    Positioned(
                      left: step * i,
                      child: Container(
                        width: size,
                        height: size,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: MarketPalette.greenDeep.withValues(alpha: .08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: i < shown.length
                            ? FeedbackProductThumb(image: shown[i].image, size: size - 4)
                            : Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: MarketPalette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('+$extra', style: MarketText.label(size: 13)),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: MarketSpace.md),
            Expanded(
              child: Text(
                names,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MarketText.caption(color: MarketPalette.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final Color ink;
  final Color soft;
  final bool busy;
  final bool dimmed;
  final VoidCallback? onTap;

  const _ThumbButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.ink,
    required this.soft,
    required this.busy,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(MarketRadius.lg);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: busy ? '$label, gönderiliyor' : label,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: feedbackMotion(context, const Duration(milliseconds: 160)),
          opacity: dimmed ? .5 : 1,
          child: Material(
            color: soft,
            borderRadius: shape,
            child: InkWell(
              borderRadius: shape,
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onTap!();
                    },
              child: Container(
                constraints: const BoxConstraints(minHeight: 112),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: color.withValues(alpha: .35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Center(
                        child: busy
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 3, color: color),
                              )
                            : Text(
                                emoji,
                                textScaler: TextScaler.noScaling,
                                style: MarketText.emoji(40),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      busy ? 'Gönderiliyor…' : label,
                      textAlign: TextAlign.center,
                      style: MarketText.label(color: ink, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
