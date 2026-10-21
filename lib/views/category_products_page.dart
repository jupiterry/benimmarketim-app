import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/turkish_text.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/category_products_viewmodel.dart';
import '../viewmodels/flash_sale_viewmodel.dart';
import 'widgets/category_presentation.dart';
import 'widgets/flash_sale_widgets.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';
import '../services/image_url.dart';

/// Kategori (reyon) sayfası.
///
/// Üstte reyon tabelası gibi koyu yeşil başlık: büyük kategori simgesi,
/// ürün/indirim sayıları ve başlığın altına taşan arama kutusu. Filtre
/// yokken önce reyonun flash sale ve indirim rafları, ardından tüm ürünler
/// gelir; ürünler ızgara ya da liste olarak gösterilebilir.
class CategoryProductsPage extends StatefulWidget {
  final Category category;

  const CategoryProductsPage({super.key, required this.category});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

enum _Sort { recommended, priceLow, priceHigh, discountHigh }

const _sortLabels = {
  _Sort.recommended: 'Önerilen',
  _Sort.priceLow: 'En düşük fiyat',
  _Sort.priceHigh: 'En yüksek fiyat',
  _Sort.discountHigh: 'En çok indirim',
};

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _Sort _sort = _Sort.recommended;
  bool _onlyDiscounted = false;
  bool _onlyInStock = false;
  bool _listView = false;

  String get _categoryTitle => categoryDisplayName(widget.category.name);

  bool get _hasFilters =>
      _searchQuery.isNotEmpty ||
      _onlyDiscounted ||
      _onlyInStock ||
      _sort != _Sort.recommended;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<CategoryProductsViewModel>()
          .loadCategoryProducts(widget.category.id);
    });
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _sort = _Sort.recommended;
      _onlyDiscounted = false;
      _onlyInStock = false;
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context
          .read<CategoryProductsViewModel>()
          .refreshCategoryProducts(widget.category.id),
      context.read<FlashSaleViewModel>().refreshActive(),
    ]);
  }

  List<Product> _visible(List<Product> products) {
    final list = products
        .where((p) => TurkishText.contains(p.name, _searchQuery))
        .where((p) => !_onlyDiscounted || p.isDiscounted)
        .where((p) => !_onlyInStock || !p.isOutOfStock)
        .toList();
    switch (_sort) {
      case _Sort.recommended:
        break;
      case _Sort.priceLow:
        list.sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
      case _Sort.priceHigh:
        list.sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
      case _Sort.discountHigh:
        list.sort(
          (a, b) => b.discountPercentage.compareTo(a.discountPercentage),
        );
    }
    // Stokta olmayanlar her sıralamada sona.
    return [
      ...list.where((p) => !p.isOutOfStock),
      ...list.where((p) => p.isOutOfStock),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer2<CategoryProductsViewModel, FlashSaleViewModel>(
        builder: (context, viewModel, flash, _) {
          // Fiyatlar flash sale başlayıp bittiyse güncel haliyle kullanılır.
          final all = viewModel.products.map(flash.latest).toList();
          final products = _visible(all);
          // İlk sayfa gösterilip kalanı yüklenirken sayılar henüz kesin değil.
          final loaded = !viewModel.isLoading &&
              !viewModel.isLoadingMore &&
              viewModel.error == null;
          final ids = {for (final p in all) p.id};
          final flashCount =
              ids.where((id) => flash.saleFor(id) != null).length;
          // Flash sale rafında olanlar indirim rafında tekrar görünmez.
          final deals = all
              .where((p) =>
                  p.isDiscounted &&
                  !p.isOutOfStock &&
                  flash.saleFor(p.id) == null)
              .toList()
            ..sort(
              (a, b) => b.discountPercentage.compareTo(a.discountPercentage),
            );
          final discountedCount = all.where((p) => p.isDiscounted).length;

          return RefreshIndicator(
            color: MarketPalette.greenDeep,
            backgroundColor: MarketPalette.lime,
            onRefresh: _refresh,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: MarketScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _AisleHeader(
                    title: _categoryTitle,
                    emoji: categoryEmoji(widget.category.name),
                    loaded: loaded,
                    total: all.length,
                    discounted: discountedCount,
                    flash: flashCount,
                    search: _buildSearchField(),
                  ),
                ),
                if (viewModel.isLoading)
                  const SliverToBoxAdapter(child: MarketProductGridSkeleton())
                else if (viewModel.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MarketEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Ürünler yüklenemedi',
                      message: viewModel.error!,
                      actionLabel: 'Tekrar dene',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () =>
                          viewModel.loadCategoryProducts(widget.category.id),
                      tint: MarketPalette.red,
                      tintSoft: MarketPalette.redSoft,
                    ),
                  )
                else ...[
                  if (!_hasFilters) ...[
                    SliverToBoxAdapter(
                      child: FlashSaleShelf(
                        productIds: ids,
                        padding: const EdgeInsets.only(top: 18),
                      ),
                    ),
                    if (deals.isNotEmpty)
                      SliverToBoxAdapter(child: _DealsShelf(products: deals)),
                  ],
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterBarDelegate(
                      child: _buildFilterBar(discountedCount),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildResultLine(products.length)),
                  if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(),
                    )
                  else if (_listView)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _ProductRow(product: products[index]),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns =
                              width >= 920 ? 4 : width >= 620 ? 3 : 2;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisExtent: marketProductCardHeight,
                              crossAxisSpacing: 13,
                              mainAxisSpacing: 13,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  MarketProductCard(product: products[index]),
                              childCount: products.length,
                            ),
                          );
                        },
                      ),
                    ),
                  if (viewModel.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: MarketPalette.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Material(
      color: MarketPalette.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(MarketRadius.lg),
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withValues(alpha: .14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          style: MarketText.body(size: 16),
          decoration: InputDecoration(
            hintText: '$_categoryTitle reyonunda ara',
            filled: true,
            fillColor: MarketPalette.surface,
            prefixIcon:
                const Icon(Icons.search_rounded, color: MarketPalette.green),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _searchController.clear,
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              borderSide: const BorderSide(color: MarketPalette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              borderSide:
                  const BorderSide(color: MarketPalette.green, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(int discountedCount) {
    return Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
            children: [
              _FilterChoice(
                label: discountedCount > 0
                    ? 'İndirimli ($discountedCount)'
                    : 'İndirimli',
                icon: Icons.local_offer_rounded,
                selected: _onlyDiscounted,
                accent: MarketPalette.red,
                onTap: () =>
                    setState(() => _onlyDiscounted = !_onlyDiscounted),
              ),
              const SizedBox(width: 8),
              _FilterChoice(
                label: 'Stoktakiler',
                icon: Icons.check_circle_rounded,
                selected: _onlyInStock,
                onTap: () => setState(() => _onlyInStock = !_onlyInStock),
              ),
              Container(
                width: 1,
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: MarketPalette.lineStrong,
              ),
              for (final entry in _sortLabels.entries) ...[
                _FilterChoice(
                  label: entry.value,
                  selected: _sort == entry.key,
                  onTap: () => setState(() => _sort = entry.key),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _ViewToggle(
            listView: _listView,
            onChanged: (value) => setState(() => _listView = value),
          ),
        ),
      ],
    );
  }

  Widget _buildResultLine(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _hasFilters ? '$count ürün bulundu' : 'Tüm ürünler',
              style: MarketText.heading(size: 17),
            ),
          ),
          if (_hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Filtreleri temizle'),
              style: TextButton.styleFrom(
                foregroundColor: MarketPalette.greenDark,
                textStyle: MarketText.label(size: 13),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$count ürün', style: MarketText.caption(size: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    if (_hasFilters) {
      return MarketEmptyState(
        icon: Icons.search_off_rounded,
        title: _searchQuery.isNotEmpty
            ? '"$_searchQuery" bulunamadı'
            : 'Bu filtrelere uyan ürün yok',
        message: 'Filtreleri temizleyip tekrar dene.',
        actionLabel: 'Filtreleri temizle',
        actionIcon: Icons.filter_alt_off_rounded,
        onAction: _clearFilters,
      );
    }
    return const MarketEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Bu reyonda ürün yok',
      message: 'Yeni ürünler eklendiğinde burada göreceksin.',
    );
  }
}

// ---------------------------------------------------------------------------
// Reyon tabelası
// ---------------------------------------------------------------------------

class _AisleHeader extends StatelessWidget {
  final String title;
  final String emoji;
  final bool loaded;
  final int total;
  final int discounted;
  final int flash;
  final Widget search;

  const _AisleHeader({
    required this.title,
    required this.emoji,
    required this.loaded,
    required this.total,
    required this.discounted,
    required this.flash,
    required this.search,
  });

  static const double _searchOverlap = 30;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _searchOverlap),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: MarketPalette.headerGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Reyon simgesi: sağ üstte büyük, yarısı taşan lime daire
                Positioned(
                  right: -34,
                  top: 18,
                  child: Container(
                    width: 168,
                    height: 168,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MarketPalette.lime.withValues(alpha: .16),
                    ),
                    child: Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: MarketPalette.lime,
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 54, height: 1),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22 + _searchOverlap + 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarketHeaderButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Geri',
                        onTap: () => _pop(context),
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.only(right: 130),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.display(color: Colors.white)
                              .copyWith(fontSize: 30),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeaderTag(
                            icon: Icons.inventory_2_outlined,
                            label: loaded ? '$total ürün' : 'Yükleniyor',
                          ),
                          if (loaded && discounted > 0)
                            _HeaderTag(
                              icon: Icons.local_offer_outlined,
                              label: '$discounted indirimde',
                            ),
                          if (loaded && flash > 0)
                            _HeaderTag(
                              icon: Icons.bolt_rounded,
                              label: '$flash flash sale',
                              highlight: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          child: search,
        ),
      ],
    );
  }

  static void _pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }
}

class _HeaderTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _HeaderTag({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? MarketPalette.greenDeep : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: highlight
            ? MarketPalette.lime
            : Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(MarketRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(label, style: MarketText.label(color: foreground, size: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reyondaki indirimler rafı
// ---------------------------------------------------------------------------

class _DealsShelf extends StatelessWidget {
  final List<Product> products;

  const _DealsShelf({required this.products});

  @override
  Widget build(BuildContext context) {
    final shown = products.take(10).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MarketSectionTitle(
              title: 'Reyonun fırsatları',
              subtitle: 'En çok indirimli olanlar önce',
              trailing: MarketPill(
                label: '${products.length} ürün',
                background: MarketPalette.redSoft,
                foreground: MarketPalette.red,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: marketProductCardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (context, index) => SizedBox(
                width: 172,
                child: MarketProductCard(product: shown[index], hero: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste görünümündeki ürün satırı
// ---------------------------------------------------------------------------

class _ProductRow extends StatelessWidget {
  final Product product;

  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartViewModel, FlashSaleViewModel>(
      builder: (context, cart, flash, _) {
        final item = flash.latest(product);
        final sale = flash.saleFor(item.id);
        final quantity = cart.getProductQuantity(item.id);
        final hasSavings = item.price > item.actualPrice;

        return Material(
          color: MarketPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            side: const BorderSide(color: MarketPalette.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/product', extra: item),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MarketPalette.canvas,
                          borderRadius: BorderRadius.circular(MarketRadius.md),
                        ),
                        child: item.image.isNotEmpty
                            ? Image.network(
                                optimizedImageUrl(
                                  item.image,
                                  width: MarketImageSize.thumb,
                                ),
                                fit: BoxFit.contain,
                                cacheWidth: 240,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_outlined,
                                  color: MarketPalette.subtle,
                                ),
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                color: MarketPalette.subtle,
                              ),
                      ),
                      if (sale != null)
                        Positioned(
                          left: -4,
                          top: -4,
                          child: FlashBadge(
                            discountPercentage: hasSavings
                                ? item.discountPercentage
                                : sale.discountPercentage,
                          ),
                        )
                      else if (hasSavings)
                        Positioned(
                          left: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MarketPalette.red,
                              borderRadius:
                                  BorderRadius.circular(MarketRadius.xs),
                            ),
                            child: Text(
                              '%${item.discountPercentage.round()}',
                              style: MarketText.label(
                                color: Colors.white,
                                size: 11,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.label(size: 14, weight: FontWeight.w600)
                              .copyWith(height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        if (sale != null) ...[
                          FlashTimerChip(endDate: sale.endDate),
                          const SizedBox(height: 6),
                        ] else if (item.isOutOfStock) ...[
                          Text(
                            'Stokta yok',
                            style: MarketText.caption(
                              color: MarketPalette.red,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTl(item.actualPrice),
                              style: MarketText.price(
                                color: hasSavings
                                    ? MarketPalette.red
                                    : MarketPalette.ink,
                                size: 17,
                              ),
                            ),
                            if (hasSavings) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  formatTl(item.price),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MarketText.caption(size: 12).copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: MarketPalette.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.isOutOfStock)
                    const SizedBox(width: 4)
                  else if (quantity > 0)
                    MarketStepper(
                      quantity: quantity,
                      compact: true,
                      onMinus: () => cart.removeFromCart(item),
                      onPlus: () => cart.addToCart(item),
                    )
                  else
                    Semantics(
                      button: true,
                      label: '${item.name} sepete ekle',
                      excludeSemantics: true,
                      child: Material(
                        color: MarketPalette.green,
                        borderRadius: BorderRadius.circular(MarketRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(MarketRadius.md),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            cart.addToCart(item);
                            showMarketSnack(
                              context,
                              '${item.name} sepete eklendi',
                              aboveNavigation: true,
                            );
                          },
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre çubuğu
// ---------------------------------------------------------------------------

/// Filtre ve sıralama çipi: seçiliyken koyu yeşil (indirim filtresi kırmızı)
/// zemin.
class _FilterChoice extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = MarketPalette.greenDeep,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : MarketPalette.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? accent : MarketPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.pill),
          side: BorderSide(color: selected ? accent : MarketPalette.line),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(icon == null ? 14 : 10, 0, 14, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? Colors.white : accent),
                  const SizedBox(width: 6),
                ],
                Text(label, style: MarketText.label(color: foreground, size: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Izgara / liste görünümü seçimi.
class _ViewToggle extends StatelessWidget {
  final bool listView;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.listView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, IconData icon, String tooltip) {
      final selected = listView == value;
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: selected,
          label: tooltip,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(MarketRadius.sm),
            child: Container(
              width: 36,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? MarketPalette.greenDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? MarketPalette.lime : MarketPalette.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(false, Icons.grid_view_rounded, 'Izgara görünümü'),
          option(true, Icons.view_agenda_outlined, 'Liste görünümü'),
        ],
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _FilterBarDelegate({required this.child});

  static const double _height = 58;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final raised = overlapsContent || shrinkOffset > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MarketPalette.canvas,
        boxShadow: raised
            ? [
                BoxShadow(
                  color: MarketPalette.greenDeep.withValues(alpha: .08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: SizedBox(height: _height, child: child),
    );
  }

  // Çipler her yeniden çizimde yeni durumla gelir.
  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => true;
}
