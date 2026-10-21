import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import 'category_presentation.dart';
import 'market_discovery_section.dart';
import 'market_product_card.dart';
import 'market_ui.dart';

/// Ana sayfa raflarının içeriği. [deals] "Bugünün fırsatları" rafı (ya da
/// indirim yoksa öne çıkanlar), [allDeals] fırsatlar sayfasının tamamı,
/// [forYou] "Senin için seçtik" ızgarası.
typedef HomeShelves = ({
  List<Product> deals,
  List<Product> allDeals,
  bool dealsAreDiscounts,
  List<Product> forYou,
});

const int _dealsShelfSize = 10;
const int _forYouSize = 20;
const int _maxPerCategory = 4;

/// Rafların yüklendiği anda sepette olan ürünler (akış listesinin kimliğine
/// bağlı).
/// Rafta tekrar önerilmezler; kullanıcı raftan ekledikçe kart yerinden
/// kaybolmasın diye her sepet değişiminde değil, raflar yenilendiğinde
/// hesaplanır. İki raf da aynı anlık görüntüyü kullanır.
final Expando<Set<String>> _inCartAtLoad = Expando('home-in-cart-at-load');

/// Ana sayfa raflarını hesaplar (yan etkisiz; yalnızca sepet anlık görüntüsü
/// ilk çağrıda alınır).
HomeShelves computeHomeShelves(
  HomePageViewModel viewModel,
  FlashSaleViewModel flash,
  CartViewModel cart,
) {
  // Flash sale ürünleri kendi bandında; diğer raflarda tekrar gösterilmez.
  // Fiyatlar flash sale başlayıp bittiyse günceldir.
  final flashIds = {
    for (final sale in flash.activeFlashSales) sale.productId,
  };
  final candidates = viewModel.featuredProducts
      .map(flash.latest)
      .where((p) => !p.isHidden && !flashIds.contains(p.id))
      .toList();
  final allDiscounted =
      candidates.where((p) => p.isDiscounted && !p.isOutOfStock).toList();
  final dealsAreDiscounts = allDiscounted.isNotEmpty;
  final deals = dealsAreDiscounts
      ? allDiscounted.take(_dealsShelfSize).toList()
      : candidates.where((p) => !p.isOutOfStock).take(8).toList();

  // Akış her yüklendiğinde yeni bir `products` listesi gelir; anlık görüntü
  // bu listeye bağlanır.
  final inCart = _inCartAtLoad[viewModel.products] ??= {
    for (final item in cart.items) item.product.id,
  };
  final shown = {...flashIds, for (final p in deals) p.id};
  bool fresh(Product p) =>
      !p.isHidden && !shown.contains(p.id) && !inCart.contains(p.id);
  final seen = <String>{};
  final forYou = _diverse(
    [
      ...viewModel.personalizedProducts,
      // Öneriler kısa kalırsa genel listeyle tamamlanır
      ...viewModel.products,
    ].where(fresh).where((p) => seen.add(p.id)),
    _forYouSize,
  );

  return (
    deals: deals,
    allDeals: allDiscounted,
    dealsAreDiscounts: dealsAreDiscounts,
    forYou: forYou,
  );
}

/// Sırayı koruyarak aynı kategoriden en çok [_maxPerCategory] ürün alır;
/// raf dolmazsa ayrılanlar sona eklenir.
List<Product> _diverse(Iterable<Product> products, int size) {
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

bool _hasAnyProducts(HomePageViewModel viewModel) =>
    viewModel.products.isNotEmpty ||
    viewModel.featuredProducts.isNotEmpty ||
    viewModel.personalizedProducts.isNotEmpty;

/// Yatay raflardaki kart genişliği (dar telefonda 140).
double homeShelfCardWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 360 ? 140 : 156;

// ---------------------------------------------------------------------------
// Bugünün fırsatları
// ---------------------------------------------------------------------------

class MarketDealsSection extends StatelessWidget {
  const MarketDealsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    return Consumer2<HomePageViewModel, FlashSaleViewModel>(
      builder: (context, viewModel, flash, _) {
        if (viewModel.isLoading && !_hasAnyProducts(viewModel)) {
          return const _ShelfSkeleton();
        }
        final shelves = computeHomeShelves(
          viewModel,
          flash,
          Provider.of<CartViewModel>(context, listen: false),
        );
        final deals = shelves.deals;
        if (deals.isEmpty) return const SizedBox.shrink();
        final all = shelves.allDeals;
        final showAll = shelves.dealsAreDiscounts && all.length >= 4;
        final cardWidth = homeShelfCardWidth(context);

        return Padding(
          padding: const EdgeInsets.only(top: MarketSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: MarketSectionHeader(
                  title: shelves.dealsAreDiscounts
                      ? 'Bugünün fırsatları'
                      : 'Öne çıkanlar',
                  subtitle: shelves.dealsAreDiscounts
                      ? '${all.length} üründe indirim'
                      : null,
                  actionLabel: showAll ? 'Tümü' : null,
                  onAction: showAll ? () => _showDeals(context, all) : null,
                ),
              ),
              const SizedBox(height: MarketSpace.md),
              SizedBox(
                height: marketProductCardExtent(context),
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemCount: deals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: MarketSpace.md),
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: MarketProductCard(
                      product: deals[index],
                      hero: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeals(BuildContext pageContext, List<Product> products) {
    showMarketSheet<void>(
      pageContext,
      backgroundColor: MarketPalette.canvas,
      builder: (sheetContext) => _DealsSheet(
        products: products,
        // Alt sayfa ürün sayfasının altında açık kalmaz: ürün sayfasından
        // "Sepete git" ile ana sayfaya dönülünce sepetin üstünde kalıyordu.
        onOpen: (product) {
          Navigator.pop(sheetContext);
          pageContext.push('/product', extra: product);
        },
      ),
    );
  }
}

/// İndirimli ürünlerin tamamı (rafta en çok 10 gösterilir).
class _DealsSheet extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onOpen;

  const _DealsSheet({required this.products, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return MarketSheetScaffold(
      scrollable: false,
      bodyPadding: EdgeInsets.zero,
      header: MarketSheetHeader(
        title: 'Bugünün fırsatları',
        subtitle: '${products.length} indirimli ürün',
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 3 : 2;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: marketProductCardExtent(context),
              crossAxisSpacing: MarketSpace.md,
              mainAxisSpacing: MarketSpace.md,
            ),
            itemBuilder: (context, index) => MarketProductCard(
              product: products[index],
              hero: false,
              onOpen: onOpen,
            ),
          );
        },
      ),
    );
  }
}

class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    final cardWidth = homeShelfCardWidth(context);
    return Padding(
      padding: const EdgeInsets.only(top: MarketSpace.xxl),
      child: MarketSkeletonPulse(
        semanticLabel: 'Fırsatlar yükleniyor',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: const MarketSkeleton(
                  width: 160, height: 18, radius: MarketRadius.xs),
            ),
            const SizedBox(height: MarketSpace.md),
            SizedBox(
              height: marketProductCardExtent(context),
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: MarketSpace.md),
                itemBuilder: (_, __) => SizedBox(
                  width: cardWidth,
                  child: const MarketProductCardSkeleton(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Senin için seçtik
// ---------------------------------------------------------------------------

/// "Senin için seçtik" başlığı ve ürün ızgarası (sliver: kartlar ekrana
/// geldikçe kurulur).
class MarketForYouSliver extends StatelessWidget {
  const MarketForYouSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    return Consumer2<HomePageViewModel, FlashSaleViewModel>(
      builder: (context, viewModel, flash, _) {
        final hasAny = _hasAnyProducts(viewModel);
        if (viewModel.isLoading && !hasAny) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.section, gutter, 0),
              child: MarketSkeletonPulse(
                semanticLabel: 'Ürünler yükleniyor',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MarketSkeleton(
                        width: 140, height: 18, radius: MarketRadius.xs),
                    MarketProductGridSkeleton(
                      count: 4,
                      padding: const EdgeInsets.only(top: MarketSpace.md),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (viewModel.error != null && !hasAny) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
              child: MarketEmptyInlineCard(
                icon: Icons.wifi_off_rounded,
                text: 'Ürünler yüklenemedi.',
                onRetry: viewModel.refreshProducts,
              ),
            ),
          );
        }

        final shelves = computeHomeShelves(
          viewModel,
          flash,
          Provider.of<CartViewModel>(context, listen: false),
        );
        final products = shelves.forYou;
        if (products.isEmpty) {
          if (shelves.deals.isNotEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
              child: MarketEmptyInlineCard(
                icon: Icons.inventory_2_outlined,
                text: 'Şu an gösterecek ürün yok.',
                onRetry: viewModel.refreshProducts,
              ),
            ),
          );
        }

        final subtitle = switch (viewModel.forYouStrategy) {
          'personal' => 'Sipariş alışkanlıklarına göre seçildi',
          'popular' => 'Bu aralar en çok tercih edilenler',
          _ => 'Günlük ihtiyaçların tek bir yerde',
        };

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    gutter, MarketSpace.section, gutter, MarketSpace.md),
                child: MarketSectionHeader(
                  title: 'Senin için seçtik',
                  subtitle: subtitle,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = width >= 920 ? 4 : (width >= 620 ? 3 : 2);
                  return SliverGrid.builder(
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: marketProductCardExtent(context),
                      crossAxisSpacing: MarketSpace.md,
                      mainAxisSpacing: MarketSpace.md,
                    ),
                    itemBuilder: (context, index) =>
                        MarketProductCard(product: products[index]),
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
