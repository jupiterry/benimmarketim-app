import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/home_page_viewmodel.dart';
import 'market_discovery_section.dart';
import 'market_palette.dart';
import 'market_product_card.dart';

class MarketProductsSection extends StatelessWidget {
  const MarketProductsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomePageViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading && viewModel.products.isEmpty) {
          return const _ProductsLoadingState();
        }

        if (viewModel.error != null && viewModel.products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
            child: MarketEmptyInlineCard(
              icon: Icons.wifi_off_rounded,
              text: 'Ürünlere şu anda ulaşılamıyor.',
              onRetry: viewModel.refreshProducts,
            ),
          );
        }

        final products = viewModel.products
            .where((product) => !product.isHidden)
            .take(20)
            .toList();
        final featured = viewModel.featuredProducts
            .where((product) => !product.isHidden)
            .take(8)
            .toList();
        final discounted =
            products.where((product) => product.isDiscounted).take(8).toList();
        final spotlight = discounted.isNotEmpty ? discounted : featured;
        final personalized = viewModel.personalizedProducts
            .where((product) => !product.isHidden)
            .take(20)
            .toList();
        final shelfProducts = personalized.isNotEmpty ? personalized : products;

        if (products.isEmpty && spotlight.isEmpty) {
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
                    child: MarketProductCard(product: spotlight[index]),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: MarketSectionHeader(
                eyebrow: 'MARKET RAFI',
                title: 'Senin için seçtik',
                subtitle: personalized.isNotEmpty
                    ? 'Sipariş alışkanlıklarına göre seçildi'
                    : 'Günlük ihtiyaçların tek bir yerde',
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
