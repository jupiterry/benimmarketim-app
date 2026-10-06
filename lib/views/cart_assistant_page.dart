import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/cart_proposal_card.dart';
import 'widgets/market_mascot.dart';
import 'widgets/market_ui.dart';

/// Benim Asistanım: müşteri ne istediğini (ve isterse bütçesini) yazar,
/// sistem katalogdaki ürünlerden bir sepet önerir. Ürünler ancak müşteri
/// "Sepete ekle"ye dokununca sepete girer.
class CartAssistantPage extends StatefulWidget {
  /// Ana sayfadaki kısayollardan gelindiğinde hazır gelen istek; ekran
  /// açılır açılmaz bu istekle sepet hazırlanır.
  final String? initialPrompt;

  const CartAssistantPage({super.key, this.initialPrompt});

  @override
  State<CartAssistantPage> createState() => _CartAssistantPageState();
}

class _CartAssistantPageState extends State<CartAssistantPage> {
  static const List<String> _examples = [
    'Kahvaltılık hazırla',
    'Akşam yemeği için alışveriş',
    'Misafir geliyor, ikramlık hazırla',
    '4 kişilik makarna yapacağım',
    'Haftalık temel alışveriş',
    'Film gecesi için atıştırmalık',
    'Temizlik malzemeleri',
  ];
  static const List<int> _budgets = [200, 300, 500, 750];

  final ApiService _apiService = ApiService();
  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _budget = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  bool _loading = false;
  String? _message;
  bool _isError = false;
  Map<String, dynamic>? _proposal;
  int _resultVersion = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPrompt?.trim() ?? '';
    if (initial.length >= 3) {
      _prompt.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _budget.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  double? get _budgetValue {
    final text = _budget.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    if (_loading) return;
    final prompt = _prompt.text.trim();
    final budget = _budgetValue;

    if (!context.read<AuthViewModel>().isLoggedIn) {
      setState(() {
        _isError = true;
        _message = 'Sepet hazırlayabilmem için önce giriş yapmalısın.';
        _proposal = null;
      });
      return;
    }
    if (prompt.length < 3 && budget == null) {
      setState(() {
        _isError = true;
        _message = 'Ne lazım olduğunu ya da bütçeni yazar mısın?';
        _proposal = null;
      });
      return;
    }
    if (_budget.text.trim().isNotEmpty && (budget == null || budget < 20)) {
      setState(() {
        _isError = true;
        _message = 'Bütçe en az 20 TL olmalı.';
        _proposal = null;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _isError = false;
      _proposal = null;
    });

    final result = await _apiService.suggestCart(
      // Yalnızca bütçe girildiyse temel ihtiyaç sepeti istenir
      prompt: prompt.length >= 3 ? prompt : 'Bütçeme göre temel ihtiyaç sepeti',
      budget: budget,
    );
    if (!mounted) return;

    final proposal = result['proposal'];
    setState(() {
      _loading = false;
      _resultVersion++;
      _proposal = proposal is Map ? Map<String, dynamic>.from(proposal) : null;
      _message = (result['message'] ?? '').toString();
      _isError = result['success'] != true;
      if (_message!.isEmpty) {
        _message = _proposal == null
            ? 'Sepet şu anda hazırlanamadı. Lütfen tekrar dene.'
            : null;
      }
    });
  }

  void _useExample(String example) {
    _prompt.text = example;
    _prompt.selection = TextSelection.collapsed(offset: example.length);
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const MarketHeader(
            title: 'Benim Asistanım',
            subtitle: 'Ne lazım olduğunu yaz, sepetini hazırlayayım',
            icon: Icons.auto_awesome_rounded,
            compact: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                MarketSpace.xl, MarketSpace.xl, MarketSpace.xl, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const MarketMascot(size: 86),
                    const SizedBox(width: MarketSpace.sm),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(MarketSpace.md),
                        decoration: const BoxDecoration(
                          color: MarketPalette.surface,
                          border: Border.fromBorderSide(
                              BorderSide(color: MarketPalette.line)),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(MarketRadius.md),
                            topRight: Radius.circular(MarketRadius.md),
                            bottomRight: Radius.circular(MarketRadius.md),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Merhaba! Ne lazım olduğunu ya da bütçeni yaz, sepetini ben hazırlayayım.',
                          style: MarketText.body(
                              color: MarketPalette.inkSoft, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MarketSpace.lg),
                Text('Ne lazım?', style: MarketText.heading()),
                const SizedBox(height: MarketSpace.sm),
                TextField(
                  controller: _prompt,
                  focusNode: _promptFocus,
                  enabled: !_loading,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText:
                        'Örn. 4 kişilik makarna yapacağım, kahvaltılık lazım…',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: MarketSpace.md),
                Wrap(
                  spacing: MarketSpace.sm,
                  runSpacing: MarketSpace.sm,
                  children: [
                    for (final example in _examples)
                      ActionChip(
                        label: Text(
                          example,
                          style: MarketText.label(
                              color: MarketPalette.greenDark, size: 12),
                        ),
                        onPressed: _loading ? null : () => _useExample(example),
                        backgroundColor: MarketPalette.greenSoft,
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: MarketSpace.xxl),
                Text('Bütçen (isteğe bağlı)', style: MarketText.heading()),
                const SizedBox(height: MarketSpace.sm),
                TextField(
                  controller: _budget,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Örn. 600',
                    suffixText: 'TL',
                  ),
                ),
                const SizedBox(height: MarketSpace.md),
                Wrap(
                  spacing: MarketSpace.sm,
                  runSpacing: MarketSpace.sm,
                  children: [
                    for (final amount in _budgets)
                      ChoiceChip(
                        label: Text('$amount TL'),
                        selected: _budget.text.trim() == '$amount',
                        onSelected: _loading
                            ? null
                            : (selected) => setState(() {
                                  _budget.text = selected ? '$amount' : '';
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: MarketSpace.xxl),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(_loading ? 'Sepetin hazırlanıyor…' : 'Sepetimi hazırla'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                ),
                if (_message != null) ...[
                  const SizedBox(height: MarketSpace.xl),
                  Container(
                    padding: const EdgeInsets.all(MarketSpace.lg),
                    decoration: BoxDecoration(
                      color: _isError
                          ? MarketPalette.redSoft
                          : MarketPalette.surface,
                      border: Border.all(
                        color: _isError
                            ? MarketPalette.redLine
                            : MarketPalette.line,
                      ),
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                    child: Text(
                      _message!,
                      style: MarketText.body(
                        color: _isError ? MarketPalette.red : MarketPalette.inkSoft,
                      ),
                    ),
                  ),
                ],
                if (_message != null &&
                    _isError &&
                    !context.watch<AuthViewModel>().isLoggedIn) ...[
                  const SizedBox(height: MarketSpace.md),
                  OutlinedButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Giriş yap'),
                  ),
                ],
                if (_proposal != null)
                  CartProposalCard(
                    key: ValueKey('assistant-$_resultVersion'),
                    proposal: _proposal!,
                  ),
                const SizedBox(height: MarketSpace.xl),
                Text(
                  'Ürünler ve fiyatlar marketin güncel kataloğundan gelir. '
                  'Önerilen sepet, sen onaylamadan sepetine eklenmez.',
                  textAlign: TextAlign.center,
                  style: MarketText.caption(size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
