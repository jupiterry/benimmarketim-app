import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'market_mascot.dart';
import 'market_ui.dart';

/// Ana sayfada "Benim Asistanım" ekranına götüren giriş kartı. Alttaki
/// kısayollar, asistanı hazır bir istekle açıp sepeti hemen hazırlatır.
/// (Asistana sayfanın her yerinden, arama bandındaki "Asistan" düğmesiyle de
/// ulaşılır.)
class HomeAssistantCard extends StatelessWidget {
  const HomeAssistantCard({super.key});

  static const List<_Shortcut> _shortcuts = [
    _Shortcut(
        'Kahvaltılık', Icons.free_breakfast_outlined, 'Kahvaltılık hazırla'),
    _Shortcut('Akşam yemeği', Icons.restaurant_outlined,
        'Akşam yemeği için alışveriş'),
    _Shortcut('Misafir geliyor', Icons.celebration_outlined,
        'Misafir geliyor, ikramlık hazırla'),
  ];

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
      child: Material(
        color: MarketPalette.greenDeep,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned(
              right: -46,
              top: -60,
              child: _Glow(size: 150),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  label: 'Benim Asistanım. Bütçeni ya da ne pişireceğini yaz, '
                      'sepetini hazırlayayım.',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => context.push('/cart-assistant'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          const MarketMascot(size: 56),
                          const SizedBox(width: MarketSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Benim Asistanım',
                                  style:
                                      MarketText.heading(color: Colors.white),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Bütçeni ya da ne pişireceğini yaz, sepetini hazırlayayım.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: MarketText.caption(
                                    color: Colors.white.withValues(alpha: .78),
                                    size: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: MarketSpace.sm),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: MarketPalette.lime,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: MarketPalette.greenDeep, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MarketSize.tapTarget,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _shortcuts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: MarketSpace.sm),
                    itemBuilder: (context, index) =>
                        _ShortcutChip(shortcut: _shortcuts[index]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;

  const _Glow({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .05),
      ),
    );
  }
}

class _Shortcut {
  final String label;
  final IconData icon;
  final String prompt;

  const _Shortcut(this.label, this.icon, this.prompt);
}

/// Asistanı hazır bir istekle açan çip: görünen 40 pt, dokunma alanı 48 pt.
class _ShortcutChip extends StatelessWidget {
  final _Shortcut shortcut;

  const _ShortcutChip({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/cart-assistant', extra: shortcut.prompt);
    // Görünen çipin üst/altındaki 4'er pt'lik pay da dokunuşu yakalar
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: open,
      excludeFromSemantics: true,
      child: Center(
        child: Material(
          color: Colors.white.withValues(alpha: .12),
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: .10)),
          ),
          child: InkWell(
            onTap: open,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(shortcut.icon, size: 16, color: MarketPalette.lime),
                    const SizedBox(width: 6),
                    Text(
                      shortcut.label,
                      style: MarketText.label(color: Colors.white, size: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
