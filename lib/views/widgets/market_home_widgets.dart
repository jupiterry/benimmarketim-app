import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/banner_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import 'flash_sale_widgets.dart';
import 'home_assistant_card.dart';
import 'home_quick_carts.dart';
import 'market_discovery_section.dart';
import 'market_home_header.dart';
import 'market_mascot.dart';
import 'market_products_section.dart';
import 'market_promo_section.dart';
import 'market_ui.dart';
import 'mission_section.dart';

export 'market_bottom_navigation.dart';
export 'market_palette.dart';

/// Ana sayfa akışı.
///
/// Sıra: önce gezinme ve kişisel durum (sipariş, kategoriler), sonra süreli
/// kampanyalar (banner, flash sale), sonra araçlar ve görevler (kısayollar,
/// fırsatlar, görev, asistan), en sonda göz atma ("Senin için seçtik").
/// Arama + asistan bandı başlığın altında, uzun ekranlarda sabit durur.
class ModernMarketHome extends StatelessWidget {
  /// Alt menüde "Ana Sayfa"ya tekrar dokununca başa kaydırmak için.
  final ScrollController? controller;

  const ModernMarketHome({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final gutter = homeGutter(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final offline = _isOffline(context);

    // Üst kısım yeşil (aşağı çekince başlık rengi görünür), geri kalanı
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
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: MarketScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: MarketHomeHeader()),
            SliverPersistentHeader(
              // Kısa ekranlarda sabit bant içeriğe fazla yer bırakmaz;
              // yukarı kaydırınca geri gelir.
              pinned: size.height >= 640,
              floating: size.height < 640,
              delegate: HomeSearchBandDelegate(
                gutter: gutter,
                compactAssistant: size.width < 360 || scale > 1.15,
                reduceMotion: reduceMotion,
              ),
            ),
            if (offline)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: MarketPalette.canvas,
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom),
                    child: MarketEmptyState.error(
                      illustration: const MarketMascot(size: 96),
                      message: 'İnternet bağlantını kontrol edip tekrar dene. '
                          'Sepetin olduğu gibi duruyor.',
                      onRetry: () => _refreshHome(context),
                    ),
                  ),
                ),
              )
            else
              DecoratedSliver(
                decoration: const BoxDecoration(color: MarketPalette.canvas),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeStoreClosedNotice(),
                          HomeOrderSlot(),
                          MarketQuickDiscovery(),
                          MarketPromoSection(),
                          // Panelden girilen süren flash sale'ler (yoksa yer
                          // kaplamaz)
                          FlashSaleShelf(),
                          HomeShortcutsPanel(),
                          MarketDealsSection(),
                          MissionSection(),
                          HomeAssistantCard(),
                        ],
                      ),
                    ),
                    const MarketForYouSliver(),
                    const SliverToBoxAdapter(child: HomeFeedFooter()),
                    // Alt menü yüksekliği (extendBody) dahil boşluk
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).bottom +
                            MarketSpace.xxl,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Hiçbir şey yüklenemediyse (ürün, kategori, kampanya) bölüm bölüm hata
  /// kartı yerine tek bir bağlantı ekranı gösterilir.
  static bool _isOffline(BuildContext context) {
    final products = context.watch<HomePageViewModel>();
    final categories = context.watch<CategoryViewModel>();
    final banners = context.watch<BannerViewModel>();
    final noProducts = products.products.isEmpty &&
        products.featuredProducts.isEmpty &&
        products.personalizedProducts.isEmpty;
    return products.error != null &&
        !products.isLoading &&
        noProducts &&
        !categories.isLoading &&
        categories.getActiveCategories().isEmpty &&
        !banners.isLoading &&
        banners.banners.isEmpty;
  }

  Future<void> _refreshHome(BuildContext context) async {
    // Sipariş kartı, görevler ve teslimat yeri de yenilenir
    homeRefreshSignal.value++;
    await Future.wait([
      context.read<HomePageViewModel>().refreshProducts(),
      context.read<CategoryViewModel>().loadCategories(),
      context.read<BannerViewModel>().loadBanners(),
      context.read<FlashSaleViewModel>().refreshActive(),
    ]);
  }
}

/// Akışın sonu: aradığını bulamayan müşteriye arama ve canlı destek yolu.
class HomeFeedFooter extends StatelessWidget {
  const HomeFeedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, MarketSize.control)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12)),
      textStyle: WidgetStatePropertyAll(MarketText.label(size: 13)),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
      child: MarketCard(
        shadow: false,
        padding: const EdgeInsets.all(MarketSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MarketMascot(size: 48),
                const SizedBox(width: MarketSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aradığını bulamadın mı?',
                          style: MarketText.heading()),
                      const SizedBox(height: 2),
                      Text(
                        'Ara ya da bize yaz; bulmaya çalışalım.',
                        style: MarketText.caption(size: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MarketSpace.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Ürün ara'),
                    style: buttonStyle.merge(FilledButton.styleFrom(
                      backgroundColor: MarketPalette.greenSoft,
                      foregroundColor: MarketPalette.greenDark,
                    )),
                  ),
                ),
                const SizedBox(width: MarketSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/chat'),
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Bize yaz'),
                    style: buttonStyle.merge(OutlinedButton.styleFrom(
                      foregroundColor: MarketPalette.greenDark,
                      side: const BorderSide(color: MarketPalette.lineStrong),
                    )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
