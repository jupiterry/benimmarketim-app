import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

/// 1., 3. ve 5. teslim edilen siparişten sonra sorulan detaylı anket:
/// ürün puanı + teslimat puanı + hazır seçenekler + (sorunlu ürün) + zorunlu yorum.
/// Gönderildiyse true döner.
Future<bool> showOrderFeedbackSheet(
  BuildContext context, {
  required int milestone,
  String? orderId,
  FeedbackOrder? order,
}) async {
  var submitted = false;
  final result = await showMarketSheet<bool>(
    context,
    builder: (_) => _OrderFeedbackSheet(
      milestone: milestone,
      orderId: orderId ?? order?.orderId,
      order: order,
      onSubmitted: () => submitted = true,
    ),
  );
  return result ?? submitted;
}

const _lowRating = 3;
const _minComment = 5;

class _OrderFeedbackSheet extends StatefulWidget {
  final int milestone;
  final String? orderId;
  final FeedbackOrder? order;
  final VoidCallback onSubmitted;

  const _OrderFeedbackSheet({
    required this.milestone,
    required this.onSubmitted,
    this.orderId,
    this.order,
  });

  @override
  State<_OrderFeedbackSheet> createState() => _OrderFeedbackSheetState();
}

class _OrderFeedbackSheetState extends State<_OrderFeedbackSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _comment = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final Set<String> _selectedTags = {};
  final GlobalKey _ratingKey = GlobalKey();
  final GlobalKey _deliveryKey = GlobalKey();
  final GlobalKey _commentKey = GlobalKey();
  Map<String, String> _problems = {};
  int _rating = 0;
  int _deliveryRating = 0;
  bool _sending = false;
  bool _done = false;
  bool _dirty = false;
  String? _supportChatId;
  String? _error; // sunucu hatası
  // Alan hataları ("Gönder"e basılınca işaretlenir)
  bool _ratingMissing = false;
  bool _deliveryMissing = false;
  bool _commentMissing = false;

  bool get _isLow => _rating > 0 && (_rating <= _lowRating || (_deliveryRating > 0 && _deliveryRating <= 2));
  bool get _showDetails => _rating > 0 && _deliveryRating > 0;
  bool get _showProducts =>
      _showDetails &&
      (widget.order?.products.isNotEmpty ?? false) &&
      _selectedTags.any(feedbackProductTags.contains);

  String get _title {
    switch (widget.milestone) {
      case 1:
        return 'İlk siparişin nasıldı?';
      case 3:
        return '3. siparişin tamam! Nasıl gidiyor?';
      default:
        return '5 sipariş oldu! Bizi nasıl buluyorsun?';
    }
  }

  String get _subtitle {
    switch (widget.milestone) {
      case 1:
        return 'Yarım dakikanı ayırır mısın? İlk deneyimin bizim için çok değerli.';
      case 3:
        return 'Bizi düzenli kullanmaya başladın; neyi daha iyi yapabiliriz?';
      default:
        return 'Sadık müşterilerimizdensin. Görüşün bizim için çok önemli.';
    }
  }

  @override
  void initState() {
    super.initState();
    _comment.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final dirty = _comment.text.trim().length >= _minComment;
    if (dirty == _dirty && !(dirty && _commentMissing)) return;
    setState(() {
      _dirty = dirty;
      if (dirty) _commentMissing = false;
    });
  }

  void _setRating(int value) {
    setState(() {
      final wasLow = _isLow;
      _rating = value;
      _ratingMissing = false;
      _resetTagsIfFlipped(wasLow);
      _error = null;
    });
  }

  void _setDeliveryRating(int value) {
    setState(() {
      final wasLow = _isLow;
      _deliveryRating = value;
      _deliveryMissing = false;
      _resetTagsIfFlipped(wasLow);
      _error = null;
    });
  }

  // Olumlu/olumsuz seçenek seti değişince eski seçimler anlamını yitirir
  void _resetTagsIfFlipped(bool wasLow) {
    if (wasLow != _isLow) {
      _selectedTags.clear();
      _problems = {};
    }
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: feedbackMotion(context, const Duration(milliseconds: 300)),
      curve: Curves.easeOutCubic,
      alignment: .2,
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    final comment = _comment.text.trim();
    final ratingMissing = _rating == 0;
    final deliveryMissing = _deliveryRating == 0;
    final commentMissing = !ratingMissing && !deliveryMissing && comment.length < _minComment;
    if (ratingMissing || deliveryMissing || commentMissing) {
      HapticFeedback.mediumImpact();
      setState(() {
        _ratingMissing = ratingMissing;
        _deliveryMissing = deliveryMissing;
        _commentMissing = commentMissing;
      });
      final first = ratingMissing
          ? _ratingKey
          : deliveryMissing
              ? _deliveryKey
              : _commentKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollTo(first);
        if (commentMissing && !ratingMissing && !deliveryMissing) _commentFocus.requestFocus();
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _apiService.submitOrderFeedback(
      rating: _rating,
      deliveryRating: _deliveryRating,
      milestone: widget.milestone,
      tags: _selectedTags.toList(),
      comment: comment,
      problemItems: _showProducts
          ? problemItemsPayload(widget.order!.products, _problems)
          : const [],
      orderId: widget.orderId,
    );
    if (result.ok) widget.onSubmitted();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = result.error;
      _done = result.ok;
      _supportChatId = result.supportChatId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _done
        ? MarketSheetScaffold(
            key: const ValueKey('done'),
            bodyPadding: feedbackThanksPadding,
            body: FeedbackThanks(
              happy: !_isLow && _problems.isEmpty,
              supportChatId: _supportChatId,
            ),
          )
        : _buildForm(context);
    return FeedbackPopGuard(
      busy: _sending,
      dirty: !_done && _dirty,
      child: FeedbackReveal(
        child: AnimatedSwitcher(
          duration: feedbackMotion(context),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final order = widget.order;
    final tags = _isLow ? feedbackNegativeTags : feedbackPositiveTags;
    return MarketSheetScaffold(
      key: const ValueKey('form'),
      busy: _sending,
      header: MarketSheetHeader(
        title: _title,
        subtitle: feedbackShortScreen(context) ? null : _subtitle,
        meta: order == null ? null : FeedbackOrderPill(order: order),
        onClose: _sending ? () {} : () => closeFeedbackSheet(context, dirty: _dirty),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RatingGroup(
            key: _ratingKey,
            title: 'Ürünler',
            hint: 'Tazelik, doğru ürün, fiyat',
            value: _rating,
            missing: _ratingMissing,
            onChanged: _sending ? null : _setRating,
          ),
          const SizedBox(height: 10),
          _RatingGroup(
            key: _deliveryKey,
            title: 'Teslimat ve kurye',
            hint: 'Hız ve kuryenin tavrı',
            value: _deliveryRating,
            missing: _deliveryMissing,
            onChanged: _sending ? null : _setDeliveryRating,
          ),
          FeedbackReveal(
            child: !_showDetails
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: MarketSpace.xl),
                      Semantics(
                        header: true,
                        child: Text(_isLow ? 'Ne ters gitti?' : 'En çok neyi beğendin?',
                            style: MarketText.heading()),
                      ),
                      const SizedBox(height: 2),
                      Text('Birden fazla seçebilirsin', style: MarketText.caption()),
                      const SizedBox(height: MarketSpace.sm),
                      FeedbackChipWrap(
                        children: [
                          for (final tag in tags)
                            FeedbackChip(
                              label: tag.label,
                              negative: _isLow,
                              selected: _selectedTags.contains(tag.id),
                              onTap: _sending
                                  ? null
                                  : () => setState(() {
                                        if (!_selectedTags.remove(tag.id)) {
                                          _selectedTags.add(tag.id);
                                        }
                                      }),
                            ),
                        ],
                      ),
                      FeedbackReveal(
                        child: _showProducts
                            ? Padding(
                                padding: const EdgeInsets.only(top: MarketSpace.xl),
                                child: ProblemItemsPicker(
                                  products: widget.order!.products,
                                  selected: _problems,
                                  enabled: !_sending,
                                  defaultIssue: feedbackDefaultIssue(_selectedTags),
                                  onChanged: (next) => setState(() => _problems = next),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: MarketSpace.xl),
                      FeedbackCommentField(
                        key: _commentKey,
                        controller: _comment,
                        focusNode: _commentFocus,
                        enabled: !_sending,
                        label: 'Birkaç kelimeyle anlat',
                        minChars: _minComment,
                        hint: _isLow
                            ? 'Ne olduğunu kısaca yaz…'
                            : 'Örn. "Ekmek sıcacık geldi, kurye çok nazikti"',
                        errorText: _commentMissing
                            ? (_isLow
                                ? 'Neyi daha iyi yapabileceğimizi kısaca yazar mısın?'
                                : 'Deneyimini birkaç kelimeyle yazar mısın?')
                            : null,
                        minLines: 3,
                        maxLines: 5,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      footer: FeedbackSheetFooter(
        busy: _sending,
        serverError: _error,
        onSubmit: _submit,
        onLater: () => Navigator.of(context).pop(false),
      ),
    );
  }
}

/// Bir puan grubu: başlık + ipucu, sağda canlı etiket, altında sola hizalı yıldızlar.
class _RatingGroup extends StatelessWidget {
  final String title;
  final String hint;
  final int value;
  final bool missing;
  final ValueChanged<int>? onChanged;

  const _RatingGroup({
    super.key,
    required this.title,
    required this.hint,
    required this.value,
    required this.missing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: feedbackMotion(context, const Duration(milliseconds: 160)),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: MarketPalette.canvas,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(
          color: missing ? MarketPalette.red : MarketPalette.line,
          width: missing ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: MarketText.heading()),
                    ),
                    const SizedBox(height: 2),
                    Text(hint, style: MarketText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: MarketSpace.sm),
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: feedbackMotion(context, const Duration(milliseconds: 150)),
                  child: value <= 0
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(value),
                          padding: const EdgeInsets.only(right: 6),
                          child: MarketPill(
                            label: feedbackRatingLabels[value],
                            background: MarketPalette.orangeSoft,
                            foreground: MarketPalette.orangeInk,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Transform.translate(
            // İlk yıldızın görseli başlıkla aynı hizada dursun (48 pt hücrenin iç boşluğu)
            offset: const Offset(-6, 0),
            child: FeedbackStars(
              value: value,
              onChanged: onChanged,
              size: 36,
              showLabel: false,
              alignment: MainAxisAlignment.start,
            ),
          ),
          if (missing)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: FeedbackFieldError('Bir puan seç'),
            ),
        ],
      ),
    );
  }
}
