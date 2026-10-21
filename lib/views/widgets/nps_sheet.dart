import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

/// Ayda en fazla bir kez: "Bizi bir arkadaşına önerir misin?" (0-10, NPS).
/// Yanıtlandıysa true döner.
Future<bool> showNpsSheet(BuildContext context) async {
  var submitted = false;
  final result = await showFeedbackSheet<bool>(
    context,
    _NpsSheet(onSubmitted: () => submitted = true),
  );
  return result ?? submitted;
}

class _NpsSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _NpsSheet({required this.onSubmitted});

  @override
  State<_NpsSheet> createState() => _NpsSheetState();
}

class _NpsSheetState extends State<_NpsSheet> {
  final TextEditingController _comment = TextEditingController();
  int? _score;
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_score == null) {
      setState(() => _error = 'Lütfen 0 ile 10 arasında bir puan seç.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ApiService().submitNps(score: _score!, comment: _comment.text);
    if (result.ok) widget.onSubmitted();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = result.error;
      _done = result.ok;
    });
  }

  Color _tone(int value) => value <= 6
      ? MarketPalette.red
      : value <= 8
          ? MarketPalette.orange
          : MarketPalette.green;

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FeedbackSheetHandle(),
          FeedbackThanks(happy: (_score ?? 0) >= 9),
        ],
      );
    }
    final score = _score;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FeedbackSheetHandle(),
        Text('Bizi bir arkadaşına önerir misin?', style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text('0: hiç önermem · 10: kesinlikle öneririm',
            style: MarketText.body(color: MarketPalette.muted)),
        const SizedBox(height: MarketSpace.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = ((constraints.maxWidth - 5 * 8) / 6).clamp(36.0, 52.0);
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var value = 0; value <= 10; value++)
                  SizedBox(
                    width: size,
                    height: size,
                    child: Material(
                      color: score == value ? _tone(value) : MarketPalette.surfaceMuted,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(MarketRadius.sm),
                        onTap: _sending
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _score = value;
                                  _error = null;
                                });
                              },
                        child: Center(
                          child: Text(
                            '$value',
                            style: MarketText.heading(
                              size: 16,
                              color: score == value ? Colors.white : MarketPalette.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (score != null) ...[
          const SizedBox(height: MarketSpace.lg),
          TextField(
            controller: _comment,
            enabled: !_sending,
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: score <= 6
                  ? 'Seni ne memnun ederdi? (isteğe bağlı)'
                  : score <= 8
                      ? '10 vermen için neyi daha iyi yapmalıyız? (isteğe bağlı)'
                      : 'En çok neyi seviyorsun? (isteğe bağlı)',
              counterText: '',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: MarketSpace.sm),
          Text(_error!, style: MarketText.label(color: MarketPalette.red)),
        ],
        const SizedBox(height: MarketSpace.lg),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(_sending ? 'Gönderiliyor…' : 'Gönder'),
        ),
        const SizedBox(height: MarketSpace.sm),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Şimdi değil'),
        ),
      ],
    );
  }
}
