import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/banner_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import 'home_assistant_card.dart';
import 'home_quick_carts.dart';
import 'market_discovery_section.dart';
import 'market_home_header.dart';
import 'market_products_section.dart';
import 'market_promo_section.dart';
import 'market_ui.dart';
import 'mission_section.dart';

export 'market_palette.dart';

class ModernMarketHome extends StatelessWidget {
  const ModernMarketHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Üst kısım yeşil (aşağı çekince header rengi görünür), geri kalanı
    // zemin rengi: bölümler arasında kesirli piksellerden çizgi sızmaz.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MarketPalette.greenDeep,
            MarketPalette.greenDeep,
            MarketPalette.canvas,
            MarketPalette.canvas,
          ],
          stops: [0, .3, .3, 1],
        ),
      ),
      child: RefreshIndicator(
        color: MarketPalette.greenDeep,
        backgroundColor: MarketPalette.lime,
        displacement: 110,
        onRefresh: () => _refreshHome(context),
        child: CustomScrollView(
          key: const PageStorageKey('modern-market-home'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: MarketScrollPhysics(),
          ),
          // Tek, kesintisiz zemin: bölümler arasında piksel çizgisi oluşmaz.
          slivers: const [
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MarketHomeHeader(),
                    MarketPromoSection(),
                    MissionSection(),
                    MarketQuickActions(),
                    MarketQuickDiscovery(),
                    // Asistan ve hızlı sepetler üst kısmı kalabalıklaştırmasın
                    // diye keşif bölümünün altında durur; asistana her yerden
                    // sağ alttaki maskot düğmesiyle de ulaşılır.
                    HomeAssistantCard(),
                    HomeQuickCarts(),
                    MarketProductsSection(),
                    SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshHome(BuildContext context) async {
    // Son sipariş ve favori sepet kısayolları da yenilenir
    homeQuickCartsRefresh.value++;
    await Future.wait([
      context.read<HomePageViewModel>().refreshProducts(),
      context.read<CategoryViewModel>().loadCategories(),
      context.read<BannerViewModel>().loadBanners(),
    ]);
  }
}

class MarketBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MarketBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartViewModel>(
      builder: (context, cart, _) {
        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MarketPalette.line),
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MarketPalette.greenDeep.withValues(alpha: .10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedAlign(
                  alignment: Alignment(-1 + selectedIndex.toDouble(), 0),
                  duration: MediaQuery.disableAnimationsOf(context)
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
                    onTap: () => onSelected(0),
                  ),
                  _NavigationItem(
                    icon: Icons.shopping_bag_rounded,
                    label: 'Sepet',
                    badgeCount: cart.totalItems,
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _NavigationItem(
                    icon: Icons.person_rounded,
                    label: 'Hesabım',
                    selected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
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
                        Icon(
                          icon,
                          color: color,
                          size: 24,
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -12,
                            top: -9,
                            child: MarketCountBadge(count: badgeCount),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.body(color: color ?? MarketPalette.muted, size: 12, weight: selected ? FontWeight.w800 : FontWeight.w600),
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
