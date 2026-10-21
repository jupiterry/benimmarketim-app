import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'custom_dialog.dart';
import 'market_ui.dart';

/// Verilen ürün listesini favori sepet olarak kaydetmek için ad soran alt
/// sayfa. [items] her biri `{productId, quantity}` olan satırlardır.
/// Kaydedildiyse true döner. Sayfanın altında Scaffold'un bilmediği bir çubuk
/// varsa (ör. sepetteki ödeme çubuğu) bildirim [bottomGap] kadar yukarıda
/// görünür.
///
/// Giriş yapılmamışsa önce giriş önerilir; giriş yapılınca kaydetmeye
/// kalınan yerden devam edilir.
Future<bool> showSaveCartDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  double bottomGap = 0,
}) async {
  if (items.isEmpty) {
    showMarketSnack(
      context,
      'Kaydedilecek ürün yok.',
      error: true,
      bottomGap: bottomGap,
    );
    return false;
  }

  if (!context.read<AuthViewModel>().isLoggedIn) {
    final wantsLogin = await showMarketConfirm(
      context,
      icon: Icons.lock_outline_rounded,
      title: 'Giriş yapman gerekiyor',
      message:
          'Favori sepetlerin hesabına kaydedilir; böylece her cihazda tek dokunuşla sepetine ekleyebilirsin.',
      confirmLabel: 'Giriş yap',
    );
    if (!wantsLogin || !context.mounted) return false;
    await context.push<bool>('/login');
    if (!context.mounted || !context.read<AuthViewModel>().isLoggedIn) {
      return false;
    }
  }

  final savedName = await showMarketSheet<String>(
    context,
    builder: (_) => _SaveCartSheet(items: items),
  );
  if (savedName == null || !context.mounted) return false;
  showMarketSnack(
    context,
    '“$savedName” favori sepetlerine kaydedildi',
    icon: Icons.bookmark_added_rounded,
    bottomGap: bottomGap,
  );
  return true;
}

class _SaveCartSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _SaveCartSheet({required this.items});

  @override
  State<_SaveCartSheet> createState() => _SaveCartSheetState();
}

class _SaveCartSheetState extends State<_SaveCartSheet> {
  static const List<String> _suggestions = [
    'Haftalık alışverişim',
    'Kahvaltılık',
    'Film gecesi',
    'Sınav dönemi',
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

  void _useSuggestion(String suggestion) {
    _name.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return MarketSheetScaffold(
      busy: _saving,
      header: MarketSheetHeader(
        title: 'Sepetini kaydet',
        subtitle: '${widget.items.length} çeşit ürün kaydedilecek. Aynı adla '
            'kayıtlı bir sepetin varsa yenisiyle değiştirilir.',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            enabled: !_saving,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Sepetin adı',
              hintText: 'Örn. Haftalık alışverişim',
              prefixIcon: const Icon(Icons.bookmark_border_rounded),
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: MarketSpace.sm),
          Wrap(
            spacing: MarketSpace.sm,
            children: [
              for (final suggestion in _suggestions)
                MarketChip(
                  label: suggestion,
                  selected: _name.text.trim() == suggestion,
                  onTap: _saving ? null : () => _useSuggestion(suggestion),
                ),
            ],
          ),
        ],
      ),
      footer: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.button),
          disabledBackgroundColor: _saving ? MarketPalette.green : null,
          disabledForegroundColor: _saving ? Colors.white : null,
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : const Text('Kaydet'),
      ),
    );
  }
}
