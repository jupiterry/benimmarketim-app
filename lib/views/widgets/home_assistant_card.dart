import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'market_mascot.dart';
import 'market_ui.dart';

/// Ana sayfada "Benim Asistanım" ekranına götüren giriş kartı. Alttaki
/// kısayollar, asistanı hazır bir istekle açıp sepeti hemen hazırlatır.
class HomeAssistantCard extends StatelessWidget {
  const HomeAssistantCard({super.key});

  static const List<_Shortcut> _shortcuts = [
    _Shortcut('Kahvaltılık', Icons.free_breakfast_outlined, 'Kahvaltılık hazırla'),
    _Shortcut('Akşam yemeği', Icons.restaurant_outlined, 'Akşam yemeği için alışveriş'),
    _Shortcut('Misafir geliyor', Icons.celebration_outlined, 'Misafir geliyor, ikramlık hazırla'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MarketSpace.xl, MarketSpace.lg, MarketSpace.xl, 0),
      child: Material(
        color: MarketPalette.greenDeep,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.push('/cart-assistant'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(MarketSpace.lg,
                    MarketSpace.lg, MarketSpace.lg, MarketSpace.md),
                child: Row(
                  children: [
                    const MarketMascot(size: 68),
                    const SizedBox(width: MarketSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Benim Asistanım',
                            style: MarketText.heading(color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Bütçeni ya da ne pişireceğini yaz, sepetini ben hazırlayayım.',
                            style: MarketText.caption(
                                color: const Color(0xFFCFE6D8), size: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MarketSpace.sm),
                    const Icon(Icons.arrow_forward_rounded,
                        color: MarketPalette.lime, size: 22),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MarketSpace.lg, 0, MarketSpace.lg, MarketSpace.lg),
              child: Wrap(
                spacing: MarketSpace.sm,
                runSpacing: MarketSpace.sm,
                children: [
                  for (final shortcut in _shortcuts)
                    _ShortcutChip(shortcut: shortcut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana sayfanın sağ alt köşesinde duran maskotlu düğme: sayfanın neresinde
/// olunursa olunsun asistanı tek dokunuşla açar.
class HomeAssistantButton extends StatelessWidget {
  const HomeAssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Benim Asistanım',
      child: Tooltip(
        message: 'Benim Asistanım',
        child: SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: MarketPalette.greenDeep.withValues(alpha: .45),
                  shape: const CircleBorder(
                    side: BorderSide(color: MarketPalette.lime, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/cart-assistant'),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: MarketMascot(size: 54),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -3,
                right: -3,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MarketPalette.greenDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 12, color: MarketPalette.lime),
                  ),
                ),
              ),
            ],
          ),
        ),
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

class _ShortcutChip extends StatelessWidget {
  final _Shortcut shortcut;

  const _ShortcutChip({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(MarketRadius.pill),
      child: InkWell(
        onTap: () => context.push('/cart-assistant', extra: shortcut.prompt),
        borderRadius: BorderRadius.circular(MarketRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(shortcut.icon, size: 16, color: MarketPalette.lime),
              const SizedBox(width: 6),
              Text(
                shortcut.label,
                style: MarketText.label(color: Colors.white, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
