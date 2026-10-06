import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/cart_fill.dart';
import '../../viewmodels/cart_viewmodel.dart';
import 'market_ui.dart';
import 'save_cart_dialog.dart';

/// Asistanın önerdiği sepet. Müşteri sepete eklemeden önce bir ürünü
/// dengiyle değiştirebilir, çıkarabilir ve bütçesinden artan tutara önerilen
/// ürünleri ekleyebilir. Ürünler, "Sepete ekle"ye dokununca güncel fiyat ve
/// stokla sepete girer.
class CartProposalCard extends StatefulWidget {
  final Map<String, dynamic> proposal;

  const CartProposalCard({super.key, required this.proposal});

  @override
  State<CartProposalCard> createState() => _CartProposalCardState();
}

class _Option {
  final String productId;
  final String name;
  final double price;

  const _Option({
    required this.productId,
    required this.name,
    required this.price,
  });

  static _Option? parse(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['productId'] ?? '').toString();
    final name = (raw['name'] ?? '').toString();
    final price = raw['price'];
    if (id.isEmpty || name.isEmpty || price is! num) return null;
    return _Option(productId: id, name: name, price: price.toDouble());
  }
}

class _Line {
  String productId;
  String name;
  double price;
  final int quantity;
  final List<_Option> alternatives;

  _Line({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.alternatives,
  });

  double get total => price * quantity;
}

class _CartProposalCardState extends State<CartProposalCard> {
  late final List<_Line> _lines = _parseLines();
  late final List<_Option> _extras = _parseOptions(widget.proposal['extras']);
  bool _adding = false;
  bool _added = false;

  static int _quantityOf(dynamic raw) {
    final quantity = raw is num ? raw.toInt() : 1;
    return quantity < 1 ? 1 : (quantity > 20 ? 20 : quantity);
  }

  static List<_Option> _parseOptions(dynamic raw) {
    if (raw is! List) return [];
    return raw.map(_Option.parse).whereType<_Option>().toList();
  }

  List<_Line> _parseLines() {
    final raw = widget.proposal['items'];
    if (raw is! List) return [];
    final lines = <_Line>[];
    for (final item in raw.whereType<Map>()) {
      final id = (item['productId'] ?? '').toString();
      if (id.isEmpty) continue;
      final quantity = _quantityOf(item['quantity']);
      final price = item['price'];
      final lineTotal = item['lineTotal'];
      lines.add(_Line(
        productId: id,
        name: (item['name'] ?? '').toString(),
        // Eski yanıtlarda yalnızca satır toplamı bulunabilir
        price: price is num
            ? price.toDouble()
            : (lineTotal is num ? lineTotal.toDouble() / quantity : 0),
        quantity: quantity,
        alternatives: _parseOptions(item['alternatives']),
      ));
    }
    return lines;
  }

  double get _total => _lines.fold(0.0, (sum, line) => sum + line.total);

  double? get _budget {
    final budget = widget.proposal['budget'];
    return budget is num && budget > 0 ? budget.toDouble() : null;
  }

  bool _inCart(String productId) =>
      _lines.any((line) => line.productId == productId);

  /// Satırdaki ürünü sıradaki dengiyle değiştirir; eski ürün listenin sonuna
  /// alınır, böylece müşteri dokunmaya devam ederek geri dönebilir.
  void _swap(_Line line) {
    final index =
        line.alternatives.indexWhere((option) => !_inCart(option.productId));
    if (index < 0) {
      showMarketSnack(context, 'Bu ürün için başka seçenek kalmadı.',
          icon: Icons.info_outline_rounded);
      return;
    }
    setState(() {
      final next = line.alternatives.removeAt(index);
      line.alternatives.add(_Option(
        productId: line.productId,
        name: line.name,
        price: line.price,
      ));
      line.productId = next.productId;
      line.name = next.name;
      line.price = next.price;
    });
  }

  void _remove(_Line line) => setState(() => _lines.remove(line));

  void _addExtra(_Option extra) {
    if (_inCart(extra.productId)) return;
    setState(() {
      _extras.remove(extra);
      _lines.add(_Line(
        productId: extra.productId,
        name: extra.name,
        price: extra.price,
        quantity: 1,
        alternatives: [],
      ));
    });
  }

  Future<void> _addToCart() async {
    if (_adding || _lines.isEmpty) return;
    setState(() => _adding = true);
    final result = await addItemsToCart(
      context.read<CartViewModel>(),
      [
        for (final line in _lines)
          CartFillItem(
            productId: line.productId,
            name: line.name,
            quantity: line.quantity,
          ),
      ],
    );

    if (!mounted) return;
    setState(() {
      _adding = false;
      _added = result.added > 0;
    });
    if (result.added == 0) {
      showMarketSnack(context, 'Bu ürünler şu an satışta değil.', error: true);
      return;
    }
    showMarketSnack(context, cartFillMessage(result));
  }

  Future<void> _saveAsFavorite() => showSaveCartDialog(
        context,
        items: [
          for (final line in _lines)
            {'productId': line.productId, 'quantity': line.quantity},
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Sunucudan hiç ürün gelmediyse kart gösterilmez
    final raw = widget.proposal['items'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final total = _total;
    final budget = _budget;
    final left = budget == null ? 0.0 : budget - total;
    final editable = !_added && !_adding;
    final extras = budget == null || !editable
        ? const <_Option>[]
        : _extras
            .where((extra) =>
                extra.price <= left + 0.001 && !_inCart(extra.productId))
            .toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        border: Border.all(color: MarketPalette.greenLine),
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_basket_outlined,
                  size: 17, color: MarketPalette.greenDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Önerilen sepet · ${_lines.length} ürün',
                  style: MarketText.label(color: MarketPalette.greenDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Önerideki tüm ürünleri çıkardın. Yeni bir sepet hazırlatabilirsin.',
                style: MarketText.caption(size: 13),
              ),
            ),
          for (final line in _lines) _buildLine(line, editable),
          if (editable && _lines.any((line) => line.alternatives.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Beğenmediğin ürünü oklara dokunarak benzeriyle değiştirebilir, çarpıya dokunarak çıkarabilirsin.',
                style: MarketText.caption(size: 11),
              ),
            ),
          const Divider(height: 16, color: MarketPalette.greenLine),
          Row(
            children: [
              Expanded(
                child: Text(
                  budget != null
                      ? 'Toplam (bütçe ${formatTlShort(budget)})'
                      : 'Toplam',
                  style: MarketText.caption(size: 12),
                ),
              ),
              Text(
                formatTl(total),
                style: MarketText.price(
                  color: budget != null && left < -0.001
                      ? MarketPalette.red
                      : MarketPalette.greenDark,
                  size: 16,
                ),
              ),
            ],
          ),
          if (budget != null && left < -0.001)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Bütçeni ${formatTl(-left)} aşıyor.',
                textAlign: TextAlign.right,
                style: MarketText.caption(color: MarketPalette.red, size: 12),
              ),
            ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.proposal['extrasSource'] == 'frequent'
                  ? 'Kalan ${formatTlShort(left)} ile sık aldıkların'
                  : 'Kalan ${formatTlShort(left)} ile ekleyebileceklerin',
              style: MarketText.label(color: MarketPalette.greenDark, size: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: MarketSpace.sm,
              runSpacing: MarketSpace.sm,
              children: [
                for (final extra in extras)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded,
                        size: 16, color: MarketPalette.greenDark),
                    label: Text(
                      '${extra.name} · ${formatTlShort(extra.price)}',
                      style: MarketText.label(
                          color: MarketPalette.greenDark, size: 12),
                    ),
                    onPressed: () => _addExtra(extra),
                    backgroundColor: MarketPalette.surface,
                    side: const BorderSide(color: MarketPalette.greenLine),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (_added)
            OutlinedButton.icon(
              onPressed: () => context.go(
                '/home',
                extra: <String, dynamic>{'initialTabIndex': 1},
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Sepete eklendi · Sepete git'),
            )
          else
            FilledButton.icon(
              onPressed: _adding || _lines.isEmpty ? null : _addToCart,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: Text(_adding ? 'Ekleniyor…' : 'Sepete ekle'),
            ),
          if (_lines.isNotEmpty && !_adding)
            TextButton.icon(
              onPressed: _saveAsFavorite,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Favori sepet olarak kaydet'),
            ),
          const SizedBox(height: 4),
          Text(
            'Fiyat ve stok, eklerken yeniden kontrol edilir.',
            textAlign: TextAlign.center,
            style: MarketText.caption(size: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(_Line line, bool editable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('${line.quantity}×',
              style: MarketText.label(color: MarketPalette.inkSoft)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(line.name, style: MarketText.body(size: 13)),
          ),
          const SizedBox(width: 8),
          Text(
            formatTl(line.total),
            style: MarketText.label(color: MarketPalette.inkSoft),
          ),
          if (editable) ...[
            const SizedBox(width: 2),
            if (line.alternatives.isNotEmpty)
              _lineButton(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'Benzeriyle değiştir',
                color: MarketPalette.greenDark,
                onTap: () => _swap(line),
              )
            else
              const SizedBox(width: 34),
            _lineButton(
              icon: Icons.close_rounded,
              tooltip: 'Öneriden çıkar',
              color: MarketPalette.muted,
              onTap: () => _remove(line),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lineButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 19),
        color: color,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
