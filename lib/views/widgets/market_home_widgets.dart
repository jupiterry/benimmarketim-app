import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/banner_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import 'market_discovery_section.dart';
import 'market_home_header.dart';
import 'market_palette.dart';
import 'market_products_section.dart';
import 'market_promo_section.dart';

export 'market_palette.dart';

class ModernMarketHome extends StatelessWidget {
  const ModernMarketHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF063F2B),
            Color(0xFF075B39),
            Color(0xFF117A48),
          ],
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
            parent: BouncingScrollPhysics(),
          ),
          slivers: const [
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: MarketHomeHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: MarketPromoSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: MarketQuickActions(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: MarketQuickDiscovery(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: MarketProductsSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: MarketPalette.canvas,
                child: SizedBox(height: 120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshHome(BuildContext context) async {
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
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Container(
            height: 76,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MarketPalette.line),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: MarketPalette.ink.withValues(alpha: .11),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
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
                        borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
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
                          size: 23,
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -9,
                            top: -8,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: MarketPalette.orange,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                badgeCount > 99 ? '99+' : '$badgeCount',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
