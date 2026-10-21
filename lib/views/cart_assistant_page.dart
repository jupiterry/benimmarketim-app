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
  final ScrollController _scroll = ScrollController();

  /// Sonuç alanı (öneri, hata ya da yükleniyor kartı): hazır olunca
  /// görünür alana kaydırılır.
  final GlobalKey _resultKey = GlobalKey();

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
    _scroll.dispose();
    super.dispose();
  }

  double? get _budgetValue {
    final text = _budget.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  void _revealResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .05,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showError(String message) {
    setState(() {
      _isError = true;
      _message = message;
      _proposal = null;
    });
    _revealResult();
  }

  /// Misafir önce giriş yapar; giriş yapınca istek kaldığı yerden gönderilir.
  Future<void> _loginAndSubmit() async {
    await context.push<bool>('/login');
    if (!mounted) return;
    if (context.read<AuthViewModel>().isLoggedIn) {
      setState(() {
        _message = null;
        _isError = false;
      });
      final hasInput = _prompt.text.trim().length >= 3 || _budgetValue != null;
      if (hasInput) _submit();
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    final prompt = _prompt.text.trim();
    final budget = _budgetValue;

    if (!context.read<AuthViewModel>().isLoggedIn) {
      _showError('Sepet hazırlayabilmem için önce giriş yapmalısın.');
      return;
    }
    if (prompt.length < 3 && budget == null) {
      _showError('Ne lazım olduğunu ya da bütçeni yazar mısın?');
      return;
    }
    if (_budget.text.trim().isNotEmpty && (budget == null || budget < 20)) {
      _showError('Bütçe en az ₺20 olmalı.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _isError = false;
      _proposal = null;
    });
    _revealResult();

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
    _revealResult();
  }

  void _useExample(String example) {
    _prompt.text = example;
    _prompt.selection = TextSelection.collapsed(offset: example.length);
    if (context.read<AuthViewModel>().isLoggedIn) {
      _submit();
    } else {
      _loginAndSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthViewModel>().isLoggedIn;
    final gutter = MarketSpace.gutterOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const MarketHeader(
            title: 'Benim Asistanım',
            subtitle: 'Ne lazım olduğunu yaz, sepetini hazırlayayım',
            icon: Icons.auto_awesome_rounded,
            compact: true,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xl, gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!loggedIn) ...[
                  MarketNotice(
                    icon: Icons.lock_outline_rounded,
                    text: 'Sepet hazırlayabilmem için giriş yapmalısın.',
                    trailing: TextButton(
                      onPressed: _loginAndSubmit,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, MarketSize.control),
                      ),
                      child: const Text('Giriş yap'),
                    ),
                  ),
                  const SizedBox(height: MarketSpace.lg),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const MarketMascot(size: 76),
                    const SizedBox(width: MarketSpace.sm),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                Semantics(
                  header: true,
                  child: Text('Ne lazım?', style: MarketText.heading()),
                ),
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
              ],
            ),
          ),
          const SizedBox(height: MarketSpace.sm),
          // Örnek istekler tek satırda kayar: form kısalır.
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: _examples.length,
              separatorBuilder: (_, __) => const SizedBox(width: MarketSpace.sm),
              itemBuilder: (_, index) => MarketChip(
                label: _examples[index],
                icon: Icons.auto_awesome_outlined,
                onTap: _loading ? null : () => _useExample(_examples[index]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xl, gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Bütçen (isteğe bağlı)',
                      style: MarketText.heading()),
                ),
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
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                  ),
                ),
                const SizedBox(height: MarketSpace.xs),
                Wrap(
                  spacing: MarketSpace.sm,
                  children: [
                    for (final amount in _budgets)
                      MarketChip(
                        label: '₺$amount',
                        selected: _budget.text.trim() == '$amount',
                        onTap: _loading
                            ? null
                            : () => setState(() {
                                  final selected =
                                      _budget.text.trim() == '$amount';
                                  _budget.text = selected ? '' : '$amount';
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: MarketSpace.xl),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : loggedIn
                          ? _submit
                          : _loginAndSubmit,
                  icon: Icon(
                    loggedIn ? Icons.auto_awesome_rounded : Icons.login_rounded,
                    size: 18,
                  ),
                  label: Text(_loading
                      ? 'Sepetin hazırlanıyor…'
                      : loggedIn
                          ? 'Sepetimi hazırla'
                          : 'Giriş yap ve başla'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(MarketSize.button),
                    disabledBackgroundColor:
                        _loading ? MarketPalette.green : null,
                    disabledForegroundColor: _loading ? Colors.white : null,
                  ),
                ),
                KeyedSubtree(
                  key: _resultKey,
                  child: _buildResult(),
                ),
                const SizedBox(height: MarketSpace.xl),
                Text(
                  'Ürünler ve fiyatlar marketin güncel kataloğundan gelir. '
                  'Önerilen sepet, sen onaylamadan sepetine eklenmez.',
                  textAlign: TextAlign.center,
                  style: MarketText.caption(size: 12),
                ),
                SizedBox(height: 40 + bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sonuç alanı: hazırlanırken iskelet kart, sonra mesaj ve öneri.
  Widget _buildResult() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: MarketSpace.xl),
        child: MarketSkeletonPulse(
          semanticLabel: 'Sepetin hazırlanıyor',
          child: Container(
            padding: const EdgeInsets.all(MarketSpace.md),
            decoration: BoxDecoration(
              color: MarketPalette.greenSoft,
              border: Border.all(color: MarketPalette.greenLine),
              borderRadius: BorderRadius.circular(MarketRadius.md),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarketSkeleton(width: 160, height: 14),
                SizedBox(height: 12),
                MarketSkeleton(height: 14),
                SizedBox(height: 10),
                MarketSkeleton(height: 14),
                SizedBox(height: 10),
                MarketSkeleton(width: 220, height: 14),
                SizedBox(height: 16),
                MarketSkeleton(height: 44, radius: MarketRadius.md),
              ],
            ),
          ),
        ),
      );
    }
    final message = _message;
    final proposal = _proposal;
    if (message == null && proposal == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          const SizedBox(height: MarketSpace.xl),
          _isError
              ? MarketNotice(
                  icon: Icons.error_outline_rounded,
                  text: message,
                  background: MarketPalette.redSoft,
                  foreground: MarketPalette.red,
                )
              : MarketNotice.success(
                  icon: Icons.auto_awesome_rounded,
                  text: message,
                ),
        ],
        if (proposal != null)
          CartProposalCard(
            key: ValueKey('assistant-$_resultVersion'),
            proposal: proposal,
          ),
      ],
    );
  }
}
