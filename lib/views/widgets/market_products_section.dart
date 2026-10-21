import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import 'category_presentation.dart';
import 'market_discovery_section.dart';
import 'market_palette.dart';
import 'market_product_card.dart';

class MarketProductsSection extends StatefulWidget {
  const MarketProductsSection({super.key});

  @override
  State<MarketProductsSection> createState() => _MarketProductsSectionState();
}

class _MarketProductsSectionState extends State<MarketProductsSection> {
  static const int _shelfSize = 20;
  static const int _maxPerCategory = 4;

  /// Raflar yüklendiği anda sepette olan ürünler. Rafta tekrar önerilmezler;
  /// kullanıcı raftan ekledikçe kart yerinden kaybolmasın diye liste her
  /// sepet değişiminde değil, raflar yenilendiğinde hesaplanır.
  Set<String> _inCartAtLoad = const {};
  List<Product>? _snapshotFor;

  Set<String> _cartSnapshot(List<Product> source) {
    if (!identical(source, _snapshotFor)) {
      _snapshotFor = source;
      _inCartAtLoad = {
        // build sırasında okunur; context.read build içinde kullanılamaz.
        for (final item in Provider.of<CartViewModel>(context, listen: false).items)
          item.product.id,
      };
    }
    return _inCartAtLoad;
  }

  /// Sırayı koruyarak aynı kategoriden en çok [_maxPerCategory] ürün alır;
  /// raf dolmazsa ayrılanlar sona eklenir.
  static List<Product> _diverse(Iterable<Product> products, int size) {
    final picked = <Product>[];
    final overflow = <Product>[];
    final perCategory = <String, int>{};
    for (final product in products) {
      final key = normalizedCategoryKey(product.category);
      final count = perCategory[key] ?? 0;
      if (count < _maxPerCategory) {
        perCategory[key] = count + 1;
        picked.add(product);
      } else {
        overflow.add(product);
      }
      if (picked.length >= size) return picked;
    }
    return [...picked, ...overflow].take(size).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomePageViewModel, FlashSaleViewModel>(
      builder: (context, viewModel, flash, _) {
        final hasAny = viewModel.products.isNotEmpty ||
            viewModel.featuredProducts.isNotEmpty ||
            viewModel.personalizedProducts.isNotEmpty;
        if (viewModel.isLoading && !hasAny) {
          return const _ProductsLoadingState();
        }

        if (viewModel.error != null && !hasAny) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
            child: MarketEmptyInlineCard(
              icon: Icons.wifi_off_rounded,
              text: 'Ürünlere şu anda ulaşılamıyor.',
              onRetry: viewModel.refreshProducts,
            ),
          );
        }

        // Flash sale ürünleri kendi rafında; diğer raflarda tekrar
        // gösterilmez. Fiyatlar flash sale başlayıp bittiyse günceldir.
        final flashIds = {
          for (final sale in flash.activeFlashSales) sale.productId,
        };
        final candidates = viewModel.featuredProducts
            .map(flash.latest)
            .where((p) => !p.isHidden && !flashIds.contains(p.id))
            .toList();
        final discounted =
            candidates.where((p) => p.isDiscounted).take(10).toList();
        final spotlight = discounted.isNotEmpty
            ? discounted
            : candidates.where((p) => !p.isOutOfStock).take(8).toList();

        final inCart = _cartSnapshot(viewModel.personalizedProducts);
        final shown = {...flashIds, for (final p in spotlight) p.id};
        bool fresh(Product p) =>
            !p.isHidden && !shown.contains(p.id) && !inCart.contains(p.id);
        final seen = <String>{};
        final shelfProducts = _diverse(
          [
            ...viewModel.personalizedProducts,
            // Öneriler kısa kalırsa genel listeyle tamamlanır
            ...viewModel.products,
          ].where(fresh).where((p) => seen.add(p.id)),
          _shelfSize,
        );
        final shelfSubtitle = switch (viewModel.forYouStrategy) {
          'personal' => 'Sipariş alışkanlıklarına göre seçildi',
          'popular' => 'Bu aralar en çok tercih edilenler',
          _ => 'Günlük ihtiyaçların tek bir yerde',
        };

        if (shelfProducts.isEmpty && spotlight.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
            child: MarketEmptyInlineCard(
              icon: Icons.inventory_2_outlined,
              text: 'Henüz gösterilecek ürün bulunmuyor.',
              onRetry: viewModel.refreshProducts,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spotlight.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: MarketSectionHeader(
                  eyebrow: discounted.isNotEmpty
                      ? 'AVANTAJLI FİYATLAR'
                      : 'ÖNE ÇIKANLAR',
                  title: discounted.isNotEmpty
                      ? 'Bugünün fırsatları'
                      : 'Öne çıkan ürünler',
                  subtitle: discounted.isNotEmpty
                      ? 'Sepetine iyi gelecek fırsatları kaçırma'
                      : 'Senin için özenle seçtik',
                  actionLabel: 'Tümü',
                  onAction: () => context.push('/search'),
                ),
              ),
              SizedBox(
                height: marketProductCardHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: spotlight.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 13),
                  itemBuilder: (context, index) => SizedBox(
                    width: 172,
                    child: MarketProductCard(
                      product: spotlight[index],
                      hero: false,
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: MarketSectionHeader(
                eyebrow: 'MARKET RAFI',
                title: 'Senin için seçtik',
                subtitle: shelfSubtitle,
                actionLabel: 'Ara',
                onAction: () => context.push('/search'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 920
                      ? 4
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shelfProducts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: marketProductCardHeight,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 13,
                    ),
                    itemBuilder: (context, index) {
                      return MarketProductCard(product: shelfProducts[index]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductsLoadingState extends StatelessWidget {
  const _ProductsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 20,
            decoration: BoxDecoration(
              color: MarketPalette.fill,
              borderRadius: BorderRadius.circular(MarketRadius.xs),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: marketProductCardHeight,
              crossAxisSpacing: 13,
              mainAxisSpacing: 13,
            ),
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(MarketRadius.lg),
                border: Border.all(color: MarketPalette.line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
