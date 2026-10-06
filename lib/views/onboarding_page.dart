import 'package:flutter/material.dart';
import 'widgets/market_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  static const _items = [
    (
      icon: Icons.shopping_basket_rounded,
      title: 'Marketin artık cebinde',
      description:
          'Aradığını bul, sepetini hazırla, siparişini birkaç dokunuşla ver.',
      color: MarketPalette.lime,
    ),
    (
      icon: Icons.local_shipping_rounded,
      title: 'Siparişini anlık takip et',
      description:
          'Siparişin alındığı andan kapına gelene kadar her adımı tek ekrandan gör.',
      color: MarketPalette.orange,
    ),
    (
      icon: Icons.support_agent_rounded,
      title: 'İhtiyacın olunca bize yaz',
      description:
          'Canlı destek, fotokopi hizmeti ve sana özel fırsatlar hep elinin altında.',
      color: MarketPalette.limeSoft,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 14, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MarketPalette.greenDark,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Benim Marketim',
                      style: MarketText.heading(size: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text('Atla',
                        style: MarketText.label(color: MarketPalette.muted)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: MarketPalette.greenDeep,
                              borderRadius: BorderRadius.circular(MarketRadius.xl),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x180A3F2B),
                                  blurRadius: 30,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  right: -65,
                                  top: -55,
                                  child: Container(
                                    width: 210,
                                    height: 210,
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: .14),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 174,
                                  height: 174,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    borderRadius: BorderRadius.circular(MarketRadius.xl),
                                  ),
                                  child: Icon(item.icon,
                                      size: 82, color: MarketPalette.greenDeep),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(item.title,
                            textAlign: TextAlign.center,
                            style: MarketText.display()),
                        const SizedBox(height: 12),
                        Text(item.description,
                            textAlign: TextAlign.center,
                            style: MarketText.body(color: MarketPalette.muted, height: 1.55)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Row(
                children: [
                  ...List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      width: index == _page ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? MarketPalette.green
                            : MarketPalette.lineStrong,
                        borderRadius: BorderRadius.circular(MarketRadius.sm),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_page == _items.length - 1) {
                        _finish();
                      } else if (reduceMotion) {
                        _controller.jumpToPage(_page + 1);
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 15),
                    ),
                    child: Row(
                      children: [
                        Text(
                            _page == _items.length - 1
                                ? 'Alışverişe başla'
                                : 'Devam'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
