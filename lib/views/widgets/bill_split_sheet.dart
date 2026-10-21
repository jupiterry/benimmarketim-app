import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'market_ui.dart';

/// Sipariş tutarını kişi sayısına bölen hızlı hesap. Ödeme almaz; yalnızca
/// kişi başı tutarı gösterir ve metni arkadaşlarla paylaşır ya da kopyalar.
Future<void> showBillSplitSheet(BuildContext context, {required double total}) {
  return showMarketSheet<void>(
    context,
    builder: (_) => _BillSplitSheet(total: total),
  );
}

class _BillSplitSheet extends StatefulWidget {
  final double total;

  const _BillSplitSheet({required this.total});

  @override
  State<_BillSplitSheet> createState() => _BillSplitSheetState();
}

class _BillSplitSheetState extends State<_BillSplitSheet> {
  static const int _minPeople = 2;
  static const int _maxPeople = 12;
  int _people = 2;

  /// Kuruş kaybı olmasın diye yukarı yuvarlanır (toplam eksik kalmaz).
  double get _perPerson => (widget.total * 100 / _people).ceil() / 100;

  /// Yuvarlama yüzünden kişi başı toplam, sipariş tutarını aşıyor mu.
  bool get _roundedUp => _perPerson * _people - widget.total > 0.004;

  String get _shareText =>
      'Benim Marketim siparişi: toplam ${formatTl(widget.total)}. '
      '$_people kişiye bölününce kişi başı ${formatTl(_perPerson)}.';

  Future<void> _share() async {
    try {
      await Share.share(_shareText);
    } catch (_) {
      // Paylaşım açılamazsa metin kopyalanır.
      await _copy();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    showMarketSnack(context, 'Kopyalandı. Arkadaşlarına gönderebilirsin.',
        icon: Icons.copy_rounded);
    Navigator.of(context).pop();
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap, String tooltip) {
    return IconButton.filledTonal(
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: MarketPalette.greenSoft,
        foregroundColor: MarketPalette.greenDark,
        minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MarketSheetScaffold(
      header: MarketSheetHeader(
        title: 'Hesabı böl',
        subtitle:
            'Sipariş toplamı ${formatTl(widget.total)}. Kaç kişi paylaşıyorsunuz?',
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: MarketSpace.sm),
          Semantics(
            container: true,
            label: 'Kişi sayısı',
            value: '$_people',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepButton(
                  Icons.remove_rounded,
                  _people > _minPeople ? () => setState(() => _people--) : null,
                  'Kişi azalt',
                ),
                SizedBox(
                  width: 120,
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text('$_people', style: MarketText.display()),
                        Text('kişi', style: MarketText.caption(size: 13)),
                      ],
                    ),
                  ),
                ),
                _stepButton(
                  Icons.add_rounded,
                  _people < _maxPeople ? () => setState(() => _people++) : null,
                  'Kişi artır',
                ),
              ],
            ),
          ),
          const SizedBox(height: MarketSpace.xl),
          Container(
            padding: const EdgeInsets.all(MarketSpace.lg),
            decoration: BoxDecoration(
              color: MarketPalette.greenSoft,
              border: Border.all(color: MarketPalette.greenLine),
              borderRadius: BorderRadius.circular(MarketRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Kişi başı', style: MarketText.heading()),
                ),
                Text(
                  formatTl(_perPerson),
                  style: MarketText.price(color: MarketPalette.greenDark, size: 24),
                ),
              ],
            ),
          ),
          if (_roundedUp) ...[
            const SizedBox(height: MarketSpace.sm),
            Text(
              'Kuruş farkı yukarı yuvarlandı; toplam eksik kalmaz.',
              textAlign: TextAlign.center,
              style: MarketText.caption(size: 12),
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Kopyala'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.button),
              ),
            ),
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Paylaş'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
