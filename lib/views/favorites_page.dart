import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/favorites_viewmodel.dart';
import 'widgets/market_ui.dart';
import 'widgets/market_product_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer<FavoritesViewModel>(
        builder: (context, favorites, _) {
          final count = favorites.favoritesCount;
          return CustomScrollView(
            physics: const MarketScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: MarketHeader(
                  title: 'Favorilerim',
                  subtitle: count == 0
                      ? 'Beğendiklerini burada biriktir'
                      : '$count ürün seni bekliyor',
                  icon: Icons.favorite_rounded,
                  compact: true,
                  actions: [
                    if (favorites.favorites.isNotEmpty)
                      MarketHeaderButton(
                        icon: Icons.delete_sweep_outlined,
                        tooltip: 'Favorileri temizle',
                        onTap: () => _showClearDialog(context, favorites),
                      ),
                  ],
                ),
              ),
              if (favorites.isLoading)
                const SliverToBoxAdapter(child: MarketProductGridSkeleton())
              else if (favorites.favorites.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MarketEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Favori listen henüz boş',
                    message:
                        'Beğendiğin ürünlerdeki kalp simgesine dokun. Sonra hepsine buradan ulaş.',
                    actionLabel: 'Ürünleri keşfet',
                    actionIcon: Icons.explore_rounded,
                    onAction: () => _goShopping(context),
                    tint: MarketPalette.pink,
                    tintSoft: MarketPalette.pinkSoft,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 920
                          ? 4
                          : width >= 620
                              ? 3
                              : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: marketProductCardHeight,
                          crossAxisSpacing: 13,
                          mainAxisSpacing: 13,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => MarketProductCard(
                            product: favorites.favorites[index],
                          ),
                          childCount: favorites.favorites.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _goShopping(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showClearDialog(
    BuildContext context,
    FavoritesViewModel favorites,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.heart_broken_rounded,
          size: 54,
          background: MarketPalette.pinkSoft,
          foreground: MarketPalette.pink,
        ),
        title: const Text(
          'Favoriler temizlensin mi?',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Kaydettiğin tüm ürünler favori listenden kaldırılacak.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              favorites.clearFavorites();
              Navigator.pop(dialogContext);
              showMarketSnack(context, 'Favori listen temizlendi');
            },
            style: FilledButton.styleFrom(
              backgroundColor: MarketPalette.red,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}
