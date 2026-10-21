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
  final result = await showFeedbackSheet<bool>(
    context,
    _QuickFeedbackSheet(order: order, onSubmitted: () => submitted = true),
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
  String? _error;
  String? _supportChatId;

  bool get _showProducts =>
      widget.order.products.isNotEmpty && _tags.any(feedbackProductTags.contains);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send({required String thumb}) async {
    if (_sending) return;
    final problems = thumb == 'down' && _showProducts
        ? problemItemsPayload(widget.order.products, _problems)
        : const <Map<String, String>>[];
    if (thumb == 'down' && _tags.isEmpty && problems.isEmpty && _comment.text.trim().length < 5) {
      setState(() => _error = 'Ne olduğunu seç ya da kısaca yaz.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FeedbackSheetHandle(),
        switch (_step) {
          _Step.ask => _buildAsk(),
          _Step.whatHappened => _buildWhatHappened(),
          _Step.done => FeedbackThanks(happy: _happy, supportChatId: _supportChatId),
        },
      ],
    );
  }

  Widget _buildAsk() {
    final order = widget.order;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Siparişin nasıldı?', textAlign: TextAlign.center, style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text(
          [
            if (order.shortId.isNotEmpty) '#${order.shortId}',
            '${order.products.length} ürün',
            if (order.deliveryPointName.isNotEmpty) order.deliveryPointName,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: MarketText.caption(),
        ),
        const SizedBox(height: MarketSpace.xl),
        Row(
          children: [
            Expanded(
              child: _ThumbButton(
                emoji: '👍',
                label: 'İyiydi',
                color: MarketPalette.green,
                soft: MarketPalette.greenSoft,
                busy: _sending,
                onTap: () => _send(thumb: 'up'),
              ),
            ),
            const SizedBox(width: MarketSpace.md),
            Expanded(
              child: _ThumbButton(
                emoji: '👎',
                label: 'Sorun vardı',
                color: MarketPalette.red,
                soft: MarketPalette.redSoft,
                busy: _sending,
                onTap: () => setState(() {
                  _step = _Step.whatHappened;
                  _error = null;
                }),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: MarketSpace.md),
          Text(_error!, textAlign: TextAlign.center, style: MarketText.label(color: MarketPalette.red)),
        ],
        const SizedBox(height: MarketSpace.md),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Şimdi değil'),
        ),
      ],
    );
  }

  Widget _buildWhatHappened() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ne oldu?', style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text('Üzgünüz. Ne olduğunu anlat, hemen ilgilenelim.',
            style: MarketText.body(color: MarketPalette.muted)),
        const SizedBox(height: MarketSpace.lg),
        Wrap(
          spacing: MarketSpace.sm,
          runSpacing: MarketSpace.sm,
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
                          _error = null;
                        }),
              ),
          ],
        ),
        if (_showProducts) ...[
          const SizedBox(height: MarketSpace.lg),
          ProblemItemsPicker(
            products: widget.order.products,
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
          decoration: const InputDecoration(
            hintText: 'Eklemek istediğin bir şey var mı?',
            counterText: '',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: MarketSpace.sm),
          Text(_error!, style: MarketText.label(color: MarketPalette.red)),
        ],
        const SizedBox(height: MarketSpace.lg),
        FilledButton(
          onPressed: _sending ? null : () => _send(thumb: 'down'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(_sending ? 'Gönderiliyor…' : 'Gönder'),
        ),
        const SizedBox(height: MarketSpace.sm),
        TextButton(
          onPressed: _sending ? null : () => setState(() => _step = _Step.ask),
          child: const Text('Geri'),
        ),
      ],
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final Color soft;
  final bool busy;
  final VoidCallback onTap;

  const _ThumbButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.soft,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: soft,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          onTap: busy
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onTap();
                },
          child: Container(
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              border: Border.all(color: color.withValues(alpha: .35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(label, style: MarketText.label(color: color, size: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
