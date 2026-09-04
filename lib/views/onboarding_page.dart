import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      eyebrow: 'KOLAY ALIŞVERİŞ',
      title: 'Marketin artık cebinde',
      description:
          'Aradığını hızla bul, sepetini kolayca hazırla ve siparişini birkaç dokunuşla tamamla.',
      color: Color(0xFFB9EB67),
    ),
    (
      icon: Icons.local_shipping_rounded,
      eyebrow: 'HIZLI TESLİMAT',
      title: 'Siparişini anlık takip et',
      description:
          'Siparişinin alındığı andan teslimata kadar tüm adımları tek ekrandan gör.',
      color: Color(0xFFFFA14A),
    ),
    (
      icon: Icons.support_agent_rounded,
      eyebrow: 'YANINDAYIZ',
      title: 'İhtiyacında bize yaz',
      description:
          'Canlı destek, fotokopi hizmeti ve sana özel fırsatlar her zaman kolayca ulaşabileceğin yerde.',
      color: Color(0xFF75D7C1),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F4),
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
                      color: const Color(0xFF0B6541),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Benim Marketim',
                      style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF153126))),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text('Atla',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF557064),
                            fontWeight: FontWeight.w700)),
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
                              color: const Color(0xFF073F2C),
                              borderRadius: BorderRadius.circular(34),
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
                                    borderRadius: BorderRadius.circular(52),
                                  ),
                                  child: Icon(item.icon,
                                      size: 82, color: const Color(0xFF073F2C)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(item.eyebrow,
                            style: GoogleFonts.inter(
                                color: const Color(0xFF168454),
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text(item.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                                color: const Color(0xFF12271E),
                                fontSize: 29,
                                height: 1.1,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        Text(item.description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: const Color(0xFF718078),
                                fontSize: 14,
                                height: 1.55)),
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
                      duration: const Duration(milliseconds: 250),
                      width: index == _page ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? const Color(0xFF0B7549)
                            : const Color(0xFFD5DDD8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_page == _items.length - 1) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B7549),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Text(
                            _page == _items.length - 1
                                ? 'Alışverişe başla'
                                : 'Devam',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w800)),
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
