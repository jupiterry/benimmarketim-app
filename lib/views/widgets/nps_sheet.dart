import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

/// Ayda en fazla bir kez: "Benim Marketim'i bir arkadaşına ne kadar önerirsin?"
/// (0-10, NPS). Yanıtlandıysa true döner.
Future<bool> showNpsSheet(BuildContext context) async {
  var submitted = false;
  final result = await showMarketSheet<bool>(
    context,
    builder: (_) => _NpsSheet(onSubmitted: () => submitted = true),
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
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() {
      final dirty = _comment.text.trim().length >= 5;
      if (dirty != _dirty) setState(() => _dirty = dirty);
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || _score == null) return;
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

  String _commentLabel(int score) => score <= 6
      ? 'Neyi daha iyi yapabiliriz?'
      : score <= 8
          ? '10 vermen için ne eksik?'
          : 'En çok neyi seviyorsun?';

  @override
  Widget build(BuildContext context) {
    final score = _score ?? 0;
    final Widget content = _done
        ? MarketSheetScaffold(
            key: const ValueKey('done'),
            bodyPadding: feedbackThanksPadding,
            body: FeedbackThanks(
              happy: score >= 9,
              mood: score >= 9
                  ? FeedbackMood.happy
                  : score >= 7
                      ? FeedbackMood.neutral
                      : FeedbackMood.unhappy,
              wroteComment: _comment.text.trim().isNotEmpty,
              promoter: score >= 9,
            ),
          )
        : _buildForm();
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

  Widget _buildForm() {
    final score = _score;
    return MarketSheetScaffold(
      key: const ValueKey('form'),
      busy: _sending,
      header: MarketSheetHeader(
        title: "Benim Marketim'i bir arkadaşına ne kadar önerirsin?",
        onClose: _sending ? () {} : () => closeFeedbackSheet(context, dirty: _dirty),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NpsScale(
            value: score,
            onChanged: _sending
                ? null
                : (value) => setState(() {
                      _score = value;
                      _error = null;
                    }),
          ),
          const SizedBox(height: MarketSpace.sm),
          Text('0 = Hiç önermem · 10 = Kesinlikle öneririm',
              style: MarketText.caption(color: MarketPalette.muted)),
          FeedbackReveal(
            child: score == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: MarketSpace.xl),
                    child: FeedbackCommentField(
                      controller: _comment,
                      enabled: !_sending,
                      label: _commentLabel(score),
                      hint: 'İsteğe bağlı',
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 3,
                    ),
                  ),
          ),
        ],
      ),
      footer: FeedbackSheetFooter(
        busy: _sending,
        serverError: _error,
        onSubmit: score == null ? null : _submit,
        onLater: () => Navigator.of(context).pop(false),
      ),
    );
  }
}

/// 0-10 ölçeği: iki satır (0-5, 6-10), aynı genişlikte hücreler, sola hizalı.
/// Seçili puan her değerde aynı yeşil görünür (cevap "kötü" diye boyanmaz).
class _NpsScale extends StatelessWidget {
  final int? value;
  final ValueChanged<int>? onChanged;

  const _NpsScale({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cell = ((constraints.maxWidth - 5 * gap) / 6).clamp(36.0, 56.0);
        Widget row(int from, int to) => Row(
              children: [
                for (var v = from; v <= to; v++) ...[
                  if (v > from) const SizedBox(width: gap),
                  _NpsCell(
                    value: v,
                    width: cell,
                    selected: value == v,
                    onTap: onChanged == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onChanged!(v);
                          },
                  ),
                ],
              ],
            );
        return Semantics(
          label: '0 ile 10 arasında puan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(0, 5),
              const SizedBox(height: gap),
              row(6, 10),
            ],
          ),
        );
      },
    );
  }
}

class _NpsCell extends StatelessWidget {
  final int value;
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  const _NpsCell({required this.value, required this.width, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(MarketRadius.sm);
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '$value puan',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: MarketSize.tapTarget,
          child: Material(
            color: selected ? MarketPalette.green : MarketPalette.surfaceMuted,
            shape: RoundedRectangleBorder(
              borderRadius: shape,
              side: BorderSide(color: selected ? MarketPalette.green : MarketPalette.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Text(
                  '$value',
                  style: MarketText.heading(
                    size: 16,
                    color: selected ? Colors.white : MarketPalette.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
