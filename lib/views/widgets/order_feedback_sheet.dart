import 'package:flutter/material.dart';

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
  final result = await showFeedbackSheet<bool>(
    context,
    _OrderFeedbackSheet(
      milestone: milestone,
      orderId: orderId ?? order?.orderId,
      order: order,
      onSubmitted: () => submitted = true,
    ),
  );
  return result ?? submitted;
}

const _ratingLabels = ['', 'Çok kötü', 'Kötü', 'İdare eder', 'İyi', 'Harika'];
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
  final Set<String> _selectedTags = {};
  Map<String, String> _problems = {};
  int _rating = 0;
  int _deliveryRating = 0;
  bool _sending = false;
  bool _done = false;
  String? _supportChatId;
  String? _error;

  bool get _isLow => _rating > 0 && (_rating <= _lowRating || (_deliveryRating > 0 && _deliveryRating <= 2));
  bool get _showProducts =>
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
        return 'İlk deneyimin bizim için çok değerli. 20 saniyeni ayırır mısın?';
      case 3:
        return 'Bizi düzenli kullanmaya başladın; neyi daha iyi yapabiliriz?';
      default:
        return 'Sadık müşterilerimizdensin. Görüşün bizim için çok önemli.';
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() {
      final wasLow = _isLow;
      _rating = value;
      if (wasLow != _isLow) {
        _selectedTags.clear();
        _problems = {};
      }
      _error = null;
    });
  }

  void _setDeliveryRating(int value) {
    setState(() {
      final wasLow = _isLow;
      _deliveryRating = value;
      if (wasLow != _isLow) {
        _selectedTags.clear();
        _problems = {};
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    final comment = _comment.text.trim();
    if (_rating == 0) {
      setState(() => _error = 'Lütfen ürünlere bir puan ver.');
      return;
    }
    if (_deliveryRating == 0) {
      setState(() => _error = 'Lütfen teslimata da bir puan ver.');
      return;
    }
    if (comment.length < _minComment) {
      setState(() => _error = _isLow
          ? 'Neyi daha iyi yapabileceğimizi kısaca yazar mısın?'
          : 'Deneyimini birkaç kelimeyle yazar mısın?');
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FeedbackSheetHandle(),
        if (_done)
          FeedbackThanks(
            happy: !_isLow && _problems.isEmpty,
            supportChatId: _supportChatId,
          )
        else
          _buildForm(context),
      ],
    );
  }

  Widget _section(String title, Widget child, {String? hint}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: MarketText.heading(size: 15)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: MarketText.caption()),
          ],
          const SizedBox(height: MarketSpace.sm),
          child,
        ],
      );

  Widget _buildForm(BuildContext context) {
    final tags = _isLow ? feedbackNegativeTags : feedbackPositiveTags;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text(_subtitle, style: MarketText.body(color: MarketPalette.muted)),
        const SizedBox(height: MarketSpace.xl),
        _section(
          'Ürünler',
          Column(
            children: [
              FeedbackStars(value: _rating, onChanged: _sending ? null : _setRating),
              SizedBox(
                height: 20,
                child: Text(_ratingLabels[_rating],
                    style: MarketText.label(color: MarketPalette.inkSoft)),
              ),
            ],
          ),
          hint: 'Tazelik, doğru ürün, fiyat',
        ),
        const SizedBox(height: MarketSpace.md),
        _section(
          'Teslimat ve kurye',
          Column(
            children: [
              FeedbackStars(
                value: _deliveryRating,
                size: 34,
                onChanged: _sending ? null : _setDeliveryRating,
              ),
              SizedBox(
                height: 20,
                child: Text(_ratingLabels[_deliveryRating],
                    style: MarketText.label(color: MarketPalette.inkSoft)),
              ),
            ],
          ),
          hint: 'Hız ve kuryenin tavrı',
        ),
        if (_rating > 0) ...[
          const SizedBox(height: MarketSpace.lg),
          Text(_isLow ? 'Ne ters gitti?' : 'En çok neyi beğendin?',
              style: MarketText.heading(size: 15)),
          const SizedBox(height: MarketSpace.md),
          Wrap(
            spacing: MarketSpace.sm,
            runSpacing: MarketSpace.sm,
            children: [
              for (final tag in tags)
                FeedbackChip(
                  label: tag.label,
                  negative: _isLow,
                  selected: _selectedTags.contains(tag.id),
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            if (!_selectedTags.remove(tag.id)) _selectedTags.add(tag.id);
                          }),
                ),
            ],
          ),
          if (_showProducts) ...[
            const SizedBox(height: MarketSpace.lg),
            ProblemItemsPicker(
              products: widget.order!.products,
              selected: _problems,
              enabled: !_sending,
              onChanged: (next) => setState(() => _problems = next),
            ),
          ],
          const SizedBox(height: MarketSpace.lg),
          TextField(
            controller: _comment,
            enabled: !_sending,
            maxLines: 3,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: _isLow
                  ? 'Ne olduğunu kısaca yazar mısın? (zorunlu)'
                  : 'Birkaç kelimeyle deneyimin (zorunlu)',
              counterText: '',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: MarketSpace.md),
          Text(_error!, style: MarketText.label(color: MarketPalette.red)),
        ],
        const SizedBox(height: MarketSpace.xl),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(_sending ? 'Gönderiliyor…' : 'Gönder'),
        ),
        const SizedBox(height: MarketSpace.sm),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Sonra'),
        ),
      ],
    );
  }
}
