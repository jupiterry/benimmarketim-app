import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import 'widgets/browse_cart_bar.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/market_ui.dart';
import 'widgets/market_product_card.dart';

/// Favoriler: stoktakiler önce, stokta olmayanlar sonda. Kalpten çıkarılan
/// ürün ve "Tümünü kaldır" bildirimdeki "Geri al" ile geri gelir. Altta
/// stoktaki favorileri tek dokunuşla sepete ekleme ve sepet çubuğu durur.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      // Gövde sepet çubuğunun arkasına uzanır; alt boşluk paddingOf'tan gelir.
      extendBody: true,
      bottomNavigationBar: const BrowseCartBar(),
      body: Consumer<FavoritesViewModel>(
        builder: (context, favorites, _) {
          final all = favorites.favorites;
          final count = all.length;
          // Stokta olanlar kaydedilme sırasıyla önce, olmayanlar sona.
          final sorted = [
            ...all.where((p) => !p.isOutOfStock),
            ...all.where((p) => p.isOutOfStock),
          ];
          final outOfStock = count - all.where((p) => !p.isOutOfStock).length;
          final gutter = MarketSpace.gutterOf(context);
          final bottomGap = MediaQuery.paddingOf(context).bottom + 24;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: MarketScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: MarketHeader(
                  title: 'Favorilerim',
                  subtitle: count == 0
                      ? 'Beğendiklerini burada biriktir'
                      : outOfStock > 0
                          ? '$count ürün · $outOfStock tanesi stokta yok'
                          : '$count ürün seni bekliyor',
                  icon: Icons.favorite_rounded,
                  compact: true,
                  actions: [
                    if (all.isNotEmpty)
                      MarketHeaderButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Tümünü kaldır',
                        onTap: () => _confirmClear(favorites),
                      ),
                  ],
                ),
              ),
              if (favorites.isLoading)
                const SliverToBoxAdapter(child: MarketProductGridSkeleton())
              else if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomGap),
                    child: MarketEmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Favori listen henüz boş',
                      message:
                          'Beğendiğin ürünlerdeki kalbe dokun, hepsine buradan kolayca ulaş.',
                      actionLabel: 'Ürünleri keşfet',
                      actionIcon: Icons.explore_rounded,
                      onAction: _goShopping,
                      tint: MarketPalette.pink,
                      tintSoft: MarketPalette.pinkSoft,
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _RestockBar(
                    favorites: sorted,
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, bottomGap),
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
                          mainAxisExtent: marketProductCardExtent(context),
                          crossAxisSpacing: MarketSpace.md,
                          mainAxisSpacing: MarketSpace.md,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = sorted[index];
                            return MarketProductCard(
                              key: ValueKey(product.id),
                              product: product,
                              onFavoriteChanged: (isFavorite) {
                                if (!isFavorite) _onRemoved(product);
                              },
                            );
                          },
                          childCount: sorted.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Tek ürün kalpten çıkarıldı: kart hemen kaybolur, "Geri al" ile döner.
  void _onRemoved(Product product) {
    if (!mounted) return;
    final favorites = context.read<FavoritesViewModel>();
    showMarketSnack(
      context,
      '${productDisplayName(product.name)} favorilerden çıkarıldı',
      icon: Icons.heart_broken_rounded,
      actionLabel: 'Geri al',
      onAction: () {
        if (!favorites.isFavorite(product.id)) {
          favorites.toggleFavorite(product);
        }
      },
    );
  }

  void _goShopping() {
    context.go('/home', extra: <String, dynamic>{'initialTabIndex': 0});
  }

  Future<void> _confirmClear(FavoritesViewModel favorites) async {
    final confirmed = await showMarketConfirm(
      context,
      icon: Icons.heart_broken_rounded,
      title: 'Favori listen temizlensin mi?',
      message: 'Kaydettiğin tüm ürünler favori listenden kaldırılacak.',
      confirmLabel: 'Tümünü kaldır',
      tone: MarketTone.danger,
    );
    if (!confirmed || !mounted) return;
    final removed = List<Product>.of(favorites.favorites);
    await favorites.clearFavorites();
    if (!mounted) return;
    showMarketSnack(
      context,
      'Favori listen temizlendi',
      icon: Icons.heart_broken_rounded,
      actionLabel: 'Geri al',
      onAction: () async {
        for (final product in removed) {
          if (!favorites.isFavorite(product.id)) {
            await favorites.toggleFavorite(product);
          }
        }
      },
    );
  }
}

/// "Stoktakileri sepete ekle (n)": sepette olmayan, stoktaki favorileri tek
/// dokunuşla sepete ekler. Eklenecek ürün yoksa görünmez.
class _RestockBar extends StatelessWidget {
  final List<Product> favorites;
  final EdgeInsetsGeometry padding;

  const _RestockBar({required this.favorites, required this.padding});

  @override
  Widget build(BuildContext context) {
    // Yalnızca sepette olup olmama değişince yeniden çizilir.
    final inCart = context.select<CartViewModel, String>(
      (cart) => [
        for (final product in favorites)
          if (cart.getProductQuantity(product.id) > 0) product.id,
      ].join(','),
    );
    final inCartIds =
        inCart.isEmpty ? const <String>{} : inCart.split(',').toSet();
    final missing = [
      for (final product in favorites)
        if (!product.isOutOfStock && !inCartIds.contains(product.id)) product,
    ];
    if (missing.isEmpty) return const SizedBox.shrink();
    final n = missing.length;

    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            final cart = context.read<CartViewModel>();
            for (final product in missing) {
              cart.addToCart(product);
            }
            showMarketSnack(
              context,
              n == 1 ? '1 ürün sepete eklendi' : '$n ürün sepete eklendi',
              icon: Icons.add_shopping_cart_rounded,
            );
          },
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: LayoutBuilder(
            builder: (context, box) {
              // Dar ekranda / büyük yazıda kısa etiket: iki satıra inmez.
              final full = 'Stoktakileri sepete ekle ($n)';
              final style = MarketText.label(size: 14);
              final painter = TextPainter(
                text: TextSpan(text: full, style: style),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              final fits = painter.width <= box.maxWidth;
              painter.dispose();
              return Text(
                fits ? full : 'Stoktakileri ekle ($n)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: full,
              );
            },
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: MarketPalette.greenDark,
            backgroundColor: MarketPalette.surface,
            minimumSize: const Size.fromHeight(MarketSize.buttonSm + 4),
            side: const BorderSide(color: MarketPalette.greenLine, width: 1.5),
            textStyle: MarketText.label(size: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}
