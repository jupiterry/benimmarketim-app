import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'market_ui.dart';

/// Verilen ürün listesini favori sepet olarak kaydetmek için ad soran
/// pencere. [items] her biri `{productId, quantity}` olan satırlardır.
/// Kaydedildiyse true döner. Alt gezinme çubuğu olan ekranlardan açılıyorsa
/// [aboveNavigation] true verilir ki bildirim çubuğun üstünde görünsün.
Future<bool> showSaveCartDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  bool aboveNavigation = false,
}) async {
  if (!context.read<AuthViewModel>().isLoggedIn) {
    showMarketSnack(
      context,
      'Sepeti kaydetmek için önce giriş yapmalısın.',
      error: true,
      aboveNavigation: aboveNavigation,
    );
    return false;
  }
  if (items.isEmpty) {
    showMarketSnack(
      context,
      'Kaydedilecek ürün yok.',
      error: true,
      aboveNavigation: aboveNavigation,
    );
    return false;
  }

  final savedName = await showDialog<String>(
    context: context,
    builder: (_) => _SaveCartDialog(items: items),
  );
  if (savedName == null || !context.mounted) return false;
  showMarketSnack(
    context,
    '“$savedName” favori sepetlerine kaydedildi',
    icon: Icons.bookmark_added_rounded,
    aboveNavigation: aboveNavigation,
  );
  return true;
}

class _SaveCartDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _SaveCartDialog({required this.items});

  @override
  State<_SaveCartDialog> createState() => _SaveCartDialogState();
}

class _SaveCartDialogState extends State<_SaveCartDialog> {
  static const List<String> _suggestions = [
    'Haftalık alışverişim',
    'Kahvaltılık',
    'Aylık temizlik',
  ];

  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Sepete en az 2 harfli bir ad ver.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ApiService().saveSavedCart(
      name: name,
      items: widget.items,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.of(context).pop(name);
      return;
    }
    setState(() {
      _saving = false;
      _error = (result['message'] ?? 'Sepet kaydedilemedi. Lütfen tekrar dene.')
          .toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const MarketIconTile(
        icon: Icons.bookmark_add_outlined,
        size: 52,
      ),
      title: const Text('Favori sepet olarak kaydet', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.items.length} çeşit ürün kaydedilecek. Aynı adla kayıtlı '
              'bir sepetin varsa yenisiyle değiştirilir.',
              textAlign: TextAlign.center,
              style: MarketText.caption(size: 13),
            ),
            const SizedBox(height: MarketSpace.lg),
            TextField(
              controller: _name,
              enabled: !_saving,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'Örn. Haftalık alışverişim',
                counterText: '',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: MarketSpace.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: MarketSpace.sm,
              runSpacing: MarketSpace.sm,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: MarketText.label(
                          color: MarketPalette.greenDark, size: 12),
                    ),
                    onPressed: _saving
                        ? null
                        : () {
                            _name.text = suggestion;
                            _name.selection = TextSelection.collapsed(
                                offset: suggestion.length);
                            setState(() => _error = null);
                          },
                    backgroundColor: MarketPalette.greenSoft,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    );
  }
}
