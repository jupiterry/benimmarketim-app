import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'market_ui.dart';

/// Sipariş tutarını kişi sayısına bölen hızlı hesap. Ödeme almaz; yalnızca
/// kişi başı tutarı gösterir ve arkadaşlarla paylaşmak için metni kopyalar.
Future<void> showBillSplitSheet(BuildContext context, {required double total}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MarketPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
    ),
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

  String get _shareText =>
      'Benim Marketim siparişi: toplam ${formatTl(widget.total)}. '
      '$_people kişiye bölününce kişi başı ${formatTl(_perPerson)}.';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    showMarketSnack(context, 'Kopyalandı. Arkadaşlarına gönderebilirsin.');
    Navigator.of(context).pop();
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap, String tooltip) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: MarketPalette.greenSoft,
        foregroundColor: MarketPalette.greenDark,
        minimumSize: const Size(48, 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MarketSpace.xl, MarketSpace.md, MarketSpace.xl, MarketSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: MarketSpace.lg),
                decoration: BoxDecoration(
                  color: MarketPalette.lineStrong,
                  borderRadius: BorderRadius.circular(MarketRadius.pill),
                ),
              ),
            ),
            Text('Hesabı böl', style: MarketText.title()),
            const SizedBox(height: MarketSpace.sm),
            Text(
              'Sipariş toplamı ${formatTl(widget.total)}. Kaç kişi paylaşıyorsunuz?',
              style: MarketText.body(color: MarketPalette.muted),
            ),
            const SizedBox(height: MarketSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepButton(
                  Icons.remove_rounded,
                  _people > _minPeople ? () => setState(() => _people--) : null,
                  'Kişi azalt',
                ),
                SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Text('$_people', style: MarketText.display()),
                      Text('kişi', style: MarketText.caption(size: 13)),
                    ],
                  ),
                ),
                _stepButton(
                  Icons.add_rounded,
                  _people < _maxPeople ? () => setState(() => _people++) : null,
                  'Kişi artır',
                ),
              ],
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
            const SizedBox(height: MarketSpace.xl),
            FilledButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Metni kopyala'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
            const SizedBox(height: MarketSpace.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}
