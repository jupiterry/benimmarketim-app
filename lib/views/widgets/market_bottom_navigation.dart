import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/cart_viewmodel.dart';
import 'market_ui.dart';

/// Ana sayfa / Sepet / Hesabım alt menüsü.
///
/// Normalde içeriğin üstünde yüzen yuvarlak bir kart olarak durur; arkasında
/// yalnızca boyanan (dokunuşu etkilemeyen) yumuşak bir zemin geçişi vardır,
/// böylece kayan içerik menünün altında ve çevresinde kesik görünmez.
/// Sepet sekmesinde sepet doluyken ödeme çubuğuyla tek parça bir alt blok
/// oluşturmak için tam genişliğe yapışır ([attached]).
class MarketBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MarketBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Kısa ekranlarda (ör. 320x568) menü daha alçak durur.
  static double barHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640 ? 64 : 70;

  /// Menünün ekranın altında kapladığı toplam yükseklik (alt boşluk ve ev
  /// çubuğu payı dahil). Sayfalar genelde bunun yerine
  /// `MediaQuery.paddingOf(context).bottom` kullanır (extendBody).
  static double occupiedHeight(BuildContext context) =>
      barHeight(context) + math.max(MediaQuery.paddingOf(context).bottom, 12);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartViewModel, int>((c) => c.totalItems);
    final attached = selectedIndex == 1 && cartCount > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final inset = MediaQuery.paddingOf(context).bottom;
    final height = barHeight(context);
    final small = height < 70;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // İçeriğin menünün arkasında yavaşça kaybolduğu zemin geçişi
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: attached ? 0 : 1,
              duration: duration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MarketPalette.canvas.withValues(alpha: 0),
                      MarketPalette.canvas.withValues(alpha: .94),
                      MarketPalette.canvas,
                    ],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          height: attached ? height + inset : height,
          margin: attached
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(16, 0, 16, math.max(inset, 12)),
          padding: attached
              ? EdgeInsets.fromLTRB(10, 6, 10, 6 + inset)
              : const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: MarketPalette.surface,
            border: attached ? null : Border.all(color: MarketPalette.line),
            borderRadius:
                BorderRadius.circular(attached ? 0 : MarketRadius.lg),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep
                    .withValues(alpha: attached ? 0 : .10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Yapışık halde üstte ince ayırıcı çizgi
              Positioned(
                top: -6,
                left: -10,
                right: -10,
                height: 1,
                child: AnimatedOpacity(
                  opacity: attached ? 1 : 0,
                  duration: duration,
                  child: const ColoredBox(color: MarketPalette.line),
                ),
              ),
              AnimatedAlign(
                alignment: Alignment(-1 + selectedIndex.toDouble(), 0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                  ),
                ),
              ),
              Row(children: [
                _NavigationItem(
                  icon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  selected: selectedIndex == 0,
                  small: small,
                  onTap: () => onSelected(0),
                ),
                _NavigationItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Sepet',
                  badgeCount: cartCount,
                  selected: selectedIndex == 1,
                  small: small,
                  onTap: () => onSelected(1),
                ),
                _NavigationItem(
                  icon: Icons.person_rounded,
                  label: 'Hesabım',
                  selected: selectedIndex == 2,
                  small: small,
                  onTap: () => onSelected(2),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool small;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.small,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        onTap: onTap,
        label: badgeCount > 0 ? '$label, $badgeCount ürün' : label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: selected ? MarketPalette.greenDark : MarketPalette.muted,
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, color, _) => SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, color: color, size: 24),
                        if (badgeCount > 0)
                          Positioned(
                            right: -12,
                            top: -9,
                            child: MarketCountBadge(count: badgeCount),
                          ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: small ? 2 : 4),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.15),
                        style: MarketText.body(
                          color: color ?? MarketPalette.muted,
                          size: small ? 11 : 12,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
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
