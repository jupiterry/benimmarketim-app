import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/turkish_text.dart';
import '../viewmodels/category_products_viewmodel.dart';
import 'widgets/category_presentation.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';

class CategoryProductsPage extends StatefulWidget {
  final Category category;

  const CategoryProductsPage({super.key, required this.category});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

enum _Sort { recommended, priceLow, priceHigh, discounted }

const _sortLabels = {
  _Sort.recommended: 'Önerilen',
  _Sort.priceLow: 'En düşük fiyat',
  _Sort.priceHigh: 'En yüksek fiyat',
  _Sort.discounted: 'İndirimli',
};

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _Sort _sort = _Sort.recommended;

  String get _categoryTitle => categoryDisplayName(widget.category.name);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProductsViewModel>().loadCategoryProducts(
            widget.category.id,
          );
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

  List<Product> _visible(List<Product> products) {
    final list = products
        .where((product) => TurkishText.contains(product.name, _searchQuery))
        .toList();
    switch (_sort) {
      case _Sort.recommended:
        break;
      case _Sort.priceLow:
        list.sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
      case _Sort.priceHigh:
        list.sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
      case _Sort.discounted:
        list.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    }
    // Stokta olmayanlar her sıralamada sona.
    final inStock = list.where((p) => !p.isOutOfStock);
    final outOfStock = list.where((p) => p.isOutOfStock);
    return [...inStock, ...outOfStock];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer<CategoryProductsViewModel>(
        builder: (context, viewModel, child) {
          final products = _visible(viewModel.products);
          final loaded = !viewModel.isLoading && viewModel.error == null;

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: MarketHeader(
                  title: _categoryTitle,
                  subtitle: loaded ? '${viewModel.products.length} ürün' : 'Ürünler yükleniyor',
                  compact: true,
                  leading: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MarketPalette.lime,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                    child: Text(
                      categoryEmoji(widget.category.name),
                      style: const TextStyle(fontSize: 22, height: 1),
                    ),
                  ),
                  bottom: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: MarketText.body(size: 16),
                    decoration: InputDecoration(
                      hintText: '$_categoryTitle içinde ara',
                      prefixIcon: const Icon(Icons.search_rounded, color: MarketPalette.green),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _searchController.clear,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MarketRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MarketRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MarketRadius.md),
                        borderSide: const BorderSide(color: MarketPalette.lime, width: 2),
                      ),
                    ),
                  ),
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
                    onAction: () => viewModel.loadCategoryProducts(widget.category.id),
                    tint: MarketPalette.red,
                    tintSoft: MarketPalette.redSoft,
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      children: [
                        for (final entry in _sortLabels.entries) ...[
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _sort == entry.key,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _sort = entry.key),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MarketEmptyState(
                      icon: _searchQuery.isEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off_rounded,
                      title: _searchQuery.isEmpty
                          ? 'Bu kategoride ürün yok'
                          : '"$_searchQuery" bulunamadı',
                      message: _searchQuery.isEmpty
                          ? 'Yeni ürünler eklendiğinde burada göreceksin.'
                          : 'Farklı bir kelimeyle tekrar dene.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 920 ? 4 : width >= 620 ? 3 : 2;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: marketProductCardHeight,
                            crossAxisSpacing: 13,
                            mainAxisSpacing: 13,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => MarketProductCard(product: products[index]),
                            childCount: products.length,
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
}
