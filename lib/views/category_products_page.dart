import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/app_logger.dart';
import '../services/turkish_text.dart';
import '../viewmodels/category_products_viewmodel.dart';
import '../viewmodels/flash_sale_viewmodel.dart';
import 'widgets/browse_cart_bar.dart';
import 'widgets/browse_controls.dart';
import 'widgets/category_presentation.dart';
import 'widgets/flash_sale_widgets.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';
import '../services/image_url.dart';

/// Kategori (reyon) sayfası.
///
/// Üstte reyon tabelası gibi koyu yeşil başlık: büyük kategori simgesi,
/// ürün/indirim sayıları ve başlığın altına taşan arama kutusu. Filtre
/// yokken önce reyonun flash sale ve (büyük reyonlarda) indirim rafları,
/// ardından tüm ürünler gelir; ürünler ızgara ya da liste olarak
/// gösterilebilir. Altta sepet doluyken "Sepete git" çubuğu durur.
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

const _sortSubtitles = {
  _Sort.priceLow: 'En düşük fiyata göre',
  _Sort.priceHigh: 'En yüksek fiyata göre',
  _Sort.discountHigh: 'En çok indirime göre',
};

/// Izgara / liste tercihi reyonlar arasında hatırlanır.
const _listViewPrefsKey = 'category_list_view';

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _filterBarKey = GlobalKey(debugLabel: 'category-filter-bar');
  final GlobalKey _sortChipKey = GlobalKey(debugLabel: 'category-sort-chip');
  final GlobalKey _discountChipKey =
      GlobalKey(debugLabel: 'category-discount-chip');
  final GlobalKey _stockChipKey = GlobalKey(debugLabel: 'category-stock-chip');

  String _searchQuery = '';
  _Sort _sort = _Sort.recommended;
  bool _onlyDiscounted = false;
  bool _onlyInStock = false;
  bool _listView = false;

  String get _categoryTitle => categoryDisplayName(widget.category.name);

  String get _query => _searchQuery.trim();

  /// Ürünleri gerçekten daraltan bir şey var mı (sıralama daraltmaz).
  bool get _isFiltered => _query.isNotEmpty || _onlyDiscounted || _onlyInStock;

  bool get _hasChipFilters => _onlyDiscounted || _onlyInStock;

  bool get _isSorted => _sort != _Sort.recommended;

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
    _restoreViewMode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listView = prefs.getBool(_listViewPrefsKey) ?? false;
      if (mounted && listView != _listView) {
        setState(() => _listView = listView);
      }
    } catch (e) {
      AppLogger.debug('Görünüm tercihi okunamadı: $e');
    }
  }

  Future<void> _setListView(bool value) async {
    if (value == _listView) return;
    HapticFeedback.selectionClick();
    setState(() => _listView = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_listViewPrefsKey, value);
    } catch (e) {
      AppLogger.debug('Görünüm tercihi kaydedilemedi: $e');
    }
  }

  // --- Filtre ve sıralama ---------------------------------------------------

  Future<void> _openSortSheet() async {
    final picked = await showBrowseSortSheet<_Sort>(
      context,
      options: _sortLabels,
      selected: _sort,
    );
    if (picked == null || picked == _sort || !mounted) return;
    setState(() => _sort = picked);
    _afterFilterChange(_sortChipKey);
  }

  void _toggleDiscounted() {
    setState(() => _onlyDiscounted = !_onlyDiscounted);
    _afterFilterChange(_discountChipKey);
  }

  void _toggleInStock() {
    setState(() => _onlyInStock = !_onlyInStock);
    _afterFilterChange(_stockChipKey);
  }

  /// Başlıktaki "N indirimde" etiketinden: yalnızca indirimlileri göster.
  void _showDiscounted() {
    if (_onlyDiscounted) {
      _revealResults();
      return;
    }
    _toggleDiscounted();
  }

  /// Çipleri ve sıralamayı sıfırlar; arama kutusuna dokunmaz.
  void _clearChipFilters() {
    setState(() {
      _sort = _Sort.recommended;
      _onlyDiscounted = false;
      _onlyInStock = false;
    });
    _afterFilterChange(null);
  }

  void _searchEverywhere() {
    final query = _query;
    context.push('/search', extra: query.isEmpty ? null : query);
  }

  /// Filtre/sıralama değişince: dokunulan çipi görünür yap ve filtre çubuğunu
  /// en üste getirip sonuçları hemen altında göster. Raflar gizlenip içerik
  /// kısaldığında sayfa parmağın altında zıplamaz.
  void _afterFilterChange(GlobalKey? chipKey) {
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (chipKey != null) _revealChip(chipKey);
      _revealResults();
    });
  }

  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 250);

  /// Dokunulan çip kesik ya da kenardaki solgunluğun altında kalıyorsa satırı
  /// yalnızca gerektiği kadar kaydırır.
  void _revealChip(GlobalKey key) {
    final chipContext = key.currentContext;
    final chip = chipContext?.findRenderObject();
    if (chipContext == null || chip == null) return;
    final position = Scrollable.maybeOf(chipContext)?.position;
    final viewport = RenderAbstractViewport.maybeOf(chip);
    if (position == null ||
        viewport == null ||
        position.axis != Axis.horizontal) {
      return;
    }
    const margin = 28.0;
    final toStart = viewport.getOffsetToReveal(chip, 0).offset - margin;
    final toEnd = viewport.getOffsetToReveal(chip, 1).offset + margin;
    double? target;
    if (position.pixels > toStart) {
      target = toStart;
    } else if (position.pixels < toEnd) {
      target = toEnd;
    }
    if (target == null) return;
    _scrollTo(position, target);
  }

  /// Filtre çubuğunu en üste (sabitlendiği yere) getirir; sonuçlar hemen
  /// altından başlar.
  void _revealResults() {
    final barContext = _filterBarKey.currentContext;
    if (barContext == null) return;
    final sliver = barContext.findAncestorRenderObjectOfType<RenderSliver>();
    final position = Scrollable.maybeOf(barContext)?.position;
    if (sliver == null || position == null || !position.hasContentDimensions) {
      return;
    }
    _scrollTo(position, sliver.constraints.precedingScrollExtent);
  }

  void _scrollTo(ScrollPosition position, double target) {
    final clamped = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - clamped).abs() < 1) return;
    final duration = _motion;
    if (duration == Duration.zero) {
      position.jumpTo(clamped);
    } else {
      position.animateTo(clamped,
          duration: duration, curve: Curves.easeOutCubic);
    }
  }

  // --- Veri -----------------------------------------------------------------

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
        .where((p) => TurkishText.contains(p.name, _query))
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
      // Gövde sepet çubuğunun arkasına uzanır; alt boşluk paddingOf'tan gelir.
      extendBody: true,
      bottomNavigationBar: const BrowseCartBar(),
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
          // Çipteki sayı, çip açılınca kaç ürün kalacağını söyler (arama ve
          // stok filtresi hesaba katılır).
          final matching =
              all.where((p) => TurkishText.contains(p.name, _query)).toList();
          final discountedMatching = matching
              .where(
                  (p) => p.isDiscounted && (!_onlyInStock || !p.isOutOfStock))
              .length;
          final hasOutOfStock = matching.any((p) => p.isOutOfStock);
          // Küçük reyonda fırsat rafı aynı ürünleri iki kez gösterir; indirimli
          // ürünler ızgarada kırmızı rozetleriyle zaten öne çıkar.
          final showDeals = all.length >= 8 && deals.length >= 2;
          final gutter = MarketSpace.gutterOf(context);
          final bottomGap = MediaQuery.paddingOf(context).bottom + 24;

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
                    failed: viewModel.error != null && all.isEmpty,
                    total: all.length,
                    discounted: discountedCount,
                    flash: flashCount,
                    onDiscountedTap: _showDiscounted,
                    search: _buildSearchField(),
                  ),
                ),
                if (viewModel.isLoading)
                  const SliverToBoxAdapter(child: MarketProductGridSkeleton())
                else if (viewModel.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomGap),
                      child: MarketEmptyState.error(
                        title: 'Ürünler yüklenemedi',
                        onRetry: () =>
                            viewModel.loadCategoryProducts(widget.category.id),
                      ),
                    ),
                  )
                else if (all.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomGap),
                      child: MarketEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Bu reyonda henüz ürün yok',
                        message: 'Yeni ürünler eklendiğinde burada göreceksin.',
                        actionLabel: 'Tüm markette ara',
                        actionIcon: Icons.search_rounded,
                        onAction: _searchEverywhere,
                      ),
                    ),
                  )
                else ...[
                  if (!_isFiltered) ...[
                    SliverToBoxAdapter(
                      child: FlashSaleShelf(
                        productIds: ids,
                        padding: const EdgeInsets.only(top: 18),
                      ),
                    ),
                    if (showDeals)
                      SliverToBoxAdapter(child: _DealsShelf(products: deals)),
                  ],
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterBarDelegate(
                      child: KeyedSubtree(
                        key: _filterBarKey,
                        child: _buildFilterBar(
                          discountedCount: discountedMatching,
                          hasOutOfStock: hasOutOfStock,
                        ),
                      ),
                    ),
                  ),
                  if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomGap),
                        child: _buildEmpty(),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _buildResultLine(
                        products.length,
                        loadingMore: viewModel.isLoadingMore,
                        gutter: gutter,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        0,
                        gutter,
                        viewModel.isLoadingMore ? 20 : bottomGap,
                      ),
                      sliver: _listView
                          ? SliverList.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _ProductRow(product: products[index]),
                            )
                          : SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.crossAxisExtent;
                                final columns = width >= 920
                                    ? 4
                                    : width >= 620
                                        ? 3
                                        : 2;
                                return SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent:
                                        marketProductCardExtent(context),
                                    crossAxisSpacing: MarketSpace.md,
                                    mainAxisSpacing: MarketSpace.md,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => MarketProductCard(
                                      product: products[index],
                                      showCategory: false,
                                    ),
                                    childCount: products.length,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                  if (viewModel.isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomGap),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: MarketPalette.green,
                              semanticsLabel: 'Ürünler yükleniyor',
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
    return Container(
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
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                  tooltip: 'Aramayı temizle',
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
            borderSide: const BorderSide(color: MarketPalette.green, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar({
    required int discountedCount,
    required bool hasOutOfStock,
  }) {
    return BrowseChipRow(
      padding: EdgeInsets.symmetric(horizontal: MarketSpace.gutterOf(context)),
      children: [
        MarketChip(
          key: _sortChipKey,
          label: _isSorted ? _sortLabels[_sort]! : 'Sırala',
          icon: Icons.swap_vert_rounded,
          dropdown: true,
          selected: _isSorted,
          onTap: _openSortSheet,
          semanticLabel: 'Sırala, ${_sortLabels[_sort]}',
        ),
        // İndirimli ürün yoksa çip bir işe yaramaz; açıkken kapatılabilsin
        // diye yine de gösterilir.
        if (discountedCount > 0 || _onlyDiscounted)
          MarketChip(
            key: _discountChipKey,
            label: discountedCount > 0
                ? 'İndirimli ($discountedCount)'
                : 'İndirimli',
            leading: const Icon(
              Icons.local_offer_rounded,
              size: 18,
              color: MarketPalette.red,
            ),
            tone: MarketChipTone.danger,
            selected: _onlyDiscounted,
            onTap: _toggleDiscounted,
          ),
        if (hasOutOfStock || _onlyInStock)
          MarketChip(
            key: _stockChipKey,
            label: 'Stoktakiler',
            icon: Icons.inventory_2_outlined,
            selected: _onlyInStock,
            onTap: _toggleInStock,
          ),
        if (_hasChipFilters || _isSorted)
          BrowseClearButton(onPressed: _clearChipFilters),
      ],
    );
  }

  Widget _buildResultLine(
    int count, {
    required bool loadingMore,
    required double gutter,
  }) {
    // Sayı ile "ürün" aynı satırda kalır (bölünmez boşluk).
    final countText = loadingMore ? '$count+\u00A0ürün' : '$count\u00A0ürün';
    final Widget title;
    if (_query.isNotEmpty) {
      title = Text(
        '“$_query” için $countText',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: MarketText.heading(size: 17),
      );
    } else if (_hasChipFilters) {
      title = Text(
        '$countText bulundu',
        style: MarketText.heading(size: 17),
      );
    } else {
      title = Text.rich(
        TextSpan(
          text: 'Tüm ürünler',
          children: [
            TextSpan(
              text: '  ·  $countText',
              style: MarketText.caption(size: 13, weight: FontWeight.w600),
            ),
          ],
        ),
        style: MarketText.heading(size: 17),
      );
    }
    final subtitle = _sortSubtitles[_sort];

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter - 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: title),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: MarketText.caption(size: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ViewToggle(listView: _listView, onChanged: _setListView),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    if (_query.isNotEmpty && _hasChipFilters) {
      return MarketEmptyState(
        icon: Icons.search_off_rounded,
        title: '“$_query” için uygun ürün yok',
        message: 'Filtreleri kaldırıp tekrar bak ya da tüm markette ara.',
        actionLabel: 'Filtreleri temizle',
        actionIcon: Icons.filter_alt_off_rounded,
        onAction: _clearChipFilters,
        secondaryLabel: 'Tüm markette ara',
        onSecondary: _searchEverywhere,
      );
    }
    if (_query.isNotEmpty) {
      return MarketEmptyState(
        icon: Icons.search_off_rounded,
        title: '“$_query” bu reyonda yok',
        message: 'Yazımı kontrol et ya da tüm markette ara.',
        actionLabel: 'Tüm markette ara',
        actionIcon: Icons.search_rounded,
        onAction: _searchEverywhere,
        secondaryLabel: 'Aramayı temizle',
        onSecondary: _searchController.clear,
      );
    }
    return MarketEmptyState(
      icon: Icons.filter_alt_off_rounded,
      title: 'Bu filtrelere uyan ürün yok',
      message: 'Filtreleri kaldırıp reyonun tamamına göz at.',
      actionLabel: 'Filtreleri temizle',
      actionIcon: Icons.filter_alt_off_rounded,
      onAction: _clearChipFilters,
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
  final bool failed;
  final int total;
  final int discounted;
  final int flash;
  final VoidCallback onDiscountedTap;
  final Widget search;

  const _AisleHeader({
    required this.title,
    required this.emoji,
    required this.loaded,
    required this.failed,
    required this.total,
    required this.discounted,
    required this.flash,
    required this.onDiscountedTap,
    required this.search,
  });

  static const double _searchOverlap = 30;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dar telefonda (320 pt) simge ve başlık küçülür; başlık + arama
        // ekranın yarısını kaplamaz.
        final narrow = constraints.maxWidth < 360;
        final gutter = narrow ? MarketSpace.gutterCompact : MarketSpace.xl;
        final outer = narrow ? 120.0 : 168.0;
        final inner = narrow ? 84.0 : 112.0;

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
                      right: narrow ? -30 : -34,
                      top: narrow ? 14 : 18,
                      child: ExcludeSemantics(
                        child: Container(
                          width: outer,
                          height: outer,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MarketPalette.lime.withValues(alpha: .16),
                          ),
                          child: Container(
                            width: inner,
                            height: inner,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: MarketPalette.lime,
                            ),
                            child: Text(
                              emoji,
                              style: MarketText.emoji(narrow ? 40 : 54),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        12,
                        gutter,
                        (narrow ? 16 : 22) + _searchOverlap + (narrow ? 8 : 10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarketHeaderButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Geri',
                            onTap: () => _pop(context),
                          ),
                          SizedBox(height: narrow ? 14 : 22),
                          Padding(
                            padding: EdgeInsets.only(right: narrow ? 96 : 130),
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: MarketText.display(color: Colors.white)
                                    .copyWith(fontSize: narrow ? 26 : 30),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Etiketler sağdaki lime dairenin altına girmez.
                          Padding(
                            padding: EdgeInsets.only(right: narrow ? 56 : 70),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (!failed)
                                  _HeaderTag(
                                    icon: Icons.inventory_2_outlined,
                                    label:
                                        loaded ? '$total ürün' : 'Yükleniyor',
                                  ),
                                if (loaded && discounted > 0)
                                  _HeaderTag(
                                    icon: Icons.local_offer_outlined,
                                    label: '$discounted indirimde',
                                    semanticLabel: 'İndirimli ürünleri göster',
                                    onTap: onDiscountedTap,
                                  ),
                                if (loaded && flash > 0)
                                  _HeaderTag(
                                    icon: Icons.bolt_rounded,
                                    label: '$flash flash sale',
                                    highlight: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: gutter,
              right: gutter,
              bottom: 0,
              child: search,
            ),
          ],
        );
      },
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
  final VoidCallback? onTap;
  final String? semanticLabel;

  const _HeaderTag({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? MarketPalette.greenDeep : Colors.white;
    final tag = Material(
      color:
          highlight ? MarketPalette.lime : Colors.white.withValues(alpha: .12),
      shape: StadiumBorder(
        side: onTap == null
            ? BorderSide.none
            : BorderSide(color: Colors.white.withValues(alpha: .28)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 5, onTap == null ? 10 : 6, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 5),
              Text(label, style: MarketText.label(color: foreground, size: 12)),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return tag;
    // Görünen etiket küçük; dokunma alanı 44 pt yüksekliğe tamamlanır.
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MarketSize.control),
          child: Align(widthFactor: 1, heightFactor: 1, child: tag),
        ),
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
    final gutter = MarketSpace.gutterOf(context);
    final cardWidth = MediaQuery.sizeOf(context).width < 360 ? 140.0 : 156.0;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: MarketSectionTitle(
              title: 'Reyonun fırsatları',
              subtitle: 'En çok indirimli olanlar önce',
              dense: true,
              trailing: MarketPill(
                label: '${products.length} ürün',
                background: MarketPalette.redSoft,
                foreground: MarketPalette.red,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: marketProductCardExtent(context),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: shown.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: MarketSpace.md),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: MarketProductCard(
                  product: shown[index],
                  hero: false,
                  showCategory: false,
                ),
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
    return Consumer<FlashSaleViewModel>(
      builder: (context, flash, _) {
        final item = flash.latest(product);
        final sale = flash.saleFor(item.id);
        final hasSavings = item.price > item.actualPrice;
        final outOfStock = item.isOutOfStock;
        final name = productDisplayName(item.name);

        final label = StringBuffer('$name, ${formatTl(item.actualPrice)}');
        if (hasSavings) {
          label.write(', eski fiyat ${formatTl(item.price)}');
          label.write(', %${item.discountPercentage.round()} indirim');
        }
        if (outOfStock) label.write(', stokta yok');

        final price = Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          children: [
            Text(
              formatTl(item.actualPrice),
              maxLines: 1,
              softWrap: false,
              style: MarketText.price(
                color: hasSavings ? MarketPalette.red : MarketPalette.ink,
                size: 17,
              ),
            ),
            if (hasSavings)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  formatTl(item.price),
                  maxLines: 1,
                  softWrap: false,
                  style: MarketText.oldPrice(),
                ),
              ),
          ],
        );

        final action = outOfStock
            // Izgaradaki kart gibi: stokta yoksa sepet düğmesi yerine pasif
            // kutu (sağ taraf boş kalmaz).
            ? Tooltip(
                message: 'Stokta yok',
                excludeFromSemantics: true,
                child: Container(
                  width: MarketSize.control,
                  height: MarketSize.control,
                  decoration: BoxDecoration(
                    color: MarketPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(MarketRadius.sm),
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    color: MarketPalette.subtle,
                    size: 19,
                  ),
                ),
              )
            // Izgaradaki kartla aynı "+" → adet seçici düğmesi
            : MarketCartButton(product: item);

        return Material(
          color: MarketPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            side: const BorderSide(color: MarketPalette.line),
          ),
          clipBehavior: Clip.antiAlias,
          // Ekran okuyucu satırı tek cümle okur; sepet düğmesi ayrıca seçilir.
          child: Semantics(
            container: true,
            label: label.toString(),
            child: InkWell(
              onTap: () => context.push('/product', extra: item),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Dar satırda (küçük telefon / büyük yazı) görsel küçülür ve
                    // sepet düğmesi fiyatın altına iner; ad ve fiyat kırpılmaz.
                    final imageSize = box.maxWidth < 300 ? 76.0 : 92.0;
                    final textWidth = box.maxWidth - imageSize - 12;
                    final stacked = textWidth < 210;

                    return Row(
                      children: [
                        ExcludeSemantics(
                          child: _RowImage(
                            item: item,
                            size: imageSize,
                            dimmed: outOfStock,
                            badge: sale != null
                                ? FlashBadge(
                                    discountPercentage: hasSavings
                                        ? item.discountPercentage
                                        : sale.discountPercentage,
                                  )
                                : hasSavings
                                    ? MarketDiscountBadge(
                                        percentage: item.discountPercentage,
                                      )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: MarketText.label(
                                    size: 14,
                                    weight: FontWeight.w600,
                                  ).copyWith(height: 1.3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (sale != null && !outOfStock) ...[
                                FlashTimerChip(endDate: sale.endDate),
                                const SizedBox(height: 6),
                              ] else if (outOfStock) ...[
                                ExcludeSemantics(
                                  child: Text(
                                    'Stokta yok',
                                    style: MarketText.caption(
                                      color: MarketPalette.red,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (stacked) ...[
                                ExcludeSemantics(child: price),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: action,
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                        child: ExcludeSemantics(child: price)),
                                    const SizedBox(width: 8),
                                    action,
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RowImage extends StatelessWidget {
  final Product item;
  final double size;
  final bool dimmed;
  final Widget? badge;

  const _RowImage({
    required this.item,
    required this.size,
    required this.dimmed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.inventory_2_outlined,
      color: MarketPalette.subtle,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: dimmed ? .45 : 1,
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MarketPalette.surface,
              borderRadius: BorderRadius.circular(MarketRadius.md),
              border: Border.all(color: MarketPalette.line),
            ),
            child: item.image.isNotEmpty
                ? Image.network(
                    optimizedImageUrl(item.image, width: MarketImageSize.thumb),
                    fit: BoxFit.contain,
                    cacheWidth: 240,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => fallback,
                  )
                : fallback,
          ),
        ),
        if (badge != null) Positioned(left: -4, top: -4, child: badge!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre çubuğu ve görünüm seçimi
// ---------------------------------------------------------------------------

/// Izgara / liste görünümü seçimi (sonuç satırının sağında).
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
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          label: tooltip,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(MarketRadius.sm),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              width: MarketSize.control,
              height: MarketSize.control,
              decoration: BoxDecoration(
                color: selected ? MarketPalette.greenDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? MarketPalette.lime : MarketPalette.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: MarketSize.tapTarget,
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

  static const double _height = 64;

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
      child: SizedBox(
        height: _height,
        child: Center(child: child),
      ),
    );
  }

  // Çipler her yeniden çizimde yeni durumla gelir.
  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => true;
}
