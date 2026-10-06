import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/turkish_text.dart';
import 'widgets/category_presentation.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';

class AdvancedSearchPage extends StatefulWidget {
  const AdvancedSearchPage({super.key});

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

const _sortLabels = <String, String>{
  'createdAt': 'En yeni',
  'price_low': 'Fiyat: düşükten yükseğe',
  'price_high': 'Fiyat: yüksekten düşüğe',
  'name_asc': 'İsim (A-Z)',
  'name_desc': 'İsim (Z-A)',
};

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<Product> _searchResults = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _selectedCategory = '';
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _sortBy = 'createdAt';
  Timer? _debounce;
  int _searchRequestId = 0;
  List<String> _recentSearches = [];

  bool get _priceFiltered => _minPrice > 0 || _maxPrice < 1000;
  bool get _hasFilters =>
      _selectedCategory.isNotEmpty || _priceFiltered || _sortBy != 'createdAt';

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recentSearches =
          prefs.getStringList('recent_product_searches') ?? []);
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final updated = [
      normalized,
      ..._recentSearches
          .where((item) => item.toLowerCase() != normalized.toLowerCase())
    ].take(6).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_product_searches', updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_product_searches');
    if (mounted) setState(() => _recentSearches = []);
  }

  // Arama önerileri yükle
  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _apiService.getSearchSuggestions();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      AppLogger.debug('Öneriler yüklenemedi: $e');
    }
  }

  // Akıllı arama
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Yalnızca en son başlatılan aramanın sonucu ekrana yazılır; yavaş dönen
    // eski bir yanıt yeni sonucu ezemez.
    final requestId = ++_searchRequestId;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.searchProducts(
        query: query,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 1000 ? _maxPrice : null,
        sort: _sortBy,
      );

      if (!mounted || requestId != _searchRequestId) return;

      var products = result.products;

      // Client-side sorting guarantee
      if (_sortBy == 'price_low') {
        products.sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
      } else if (_sortBy == 'price_high') {
        products.sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
      } else if (_sortBy == 'name_asc') {
        products.sort((a, b) => TurkishText.compare(a.name, b.name));
      } else if (_sortBy == 'name_desc') {
        products.sort((a, b) => TurkishText.compare(b.name, a.name));
      }

      setState(() {
        _searchResults = products;
        _isLoading = false;
        _hasSearched = true;
      });
      await _saveRecentSearch(query);
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
      });
      showMarketSnack(context, 'Arama yapılamadı. Lütfen tekrar deneyin.', error: true);
    }
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().length >= 2) {
      _debounce = Timer(
        const Duration(milliseconds: 380),
        () => _performSearch(value),
      );
    }
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
    });
  }

  void _research() {
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = '';
      _minPrice = 0;
      _maxPrice = 1000;
      _sortBy = 'createdAt';
    });
    _research();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: MarketHeader(
              title: 'Ürün ara',
              compact: true,
              bottom: _buildSearchField(),
            ),
          ),
          SliverToBoxAdapter(child: _buildFilterChips()),
          _buildSliverResults(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onQueryChanged,
      onSubmitted: _performSearch,
      style: MarketText.body(size: 16),
      decoration: InputDecoration(
        hintText: 'Ürün, kategori veya marka ara',
        prefixIcon: const Icon(Icons.search_rounded, color: MarketPalette.green),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Temizle',
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearQuery,
              )
            : null,
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
    );
  }

  Widget _buildFilterChips() {
    final categoryLabel = _selectedCategory.isEmpty
        ? 'Kategori'
        : categoryDisplayName(_selectedCategory);
    final priceLabel = _priceFiltered
        ? '${formatTlShort(_minPrice)} – ${formatTlShort(_maxPrice)}'
        : 'Fiyat';

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        children: [
          _FilterChip(
            icon: Icons.tune_rounded,
            label: 'Filtreler',
            active: _hasFilters,
            onTap: _openFilters,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            icon: Icons.grid_view_rounded,
            label: categoryLabel,
            active: _selectedCategory.isNotEmpty,
            onTap: _openFilters,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            icon: Icons.sell_outlined,
            label: priceLabel,
            active: _priceFiltered,
            onTap: _openFilters,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            icon: Icons.swap_vert_rounded,
            label: _sortLabels[_sortBy] ?? 'Sıralama',
            active: _sortBy != 'createdAt',
            onTap: _openFilters,
          ),
          if (_hasFilters) ...[
            const SizedBox(width: 4),
            TextButton(onPressed: _resetFilters, child: const Text('Sıfırla')),
          ],
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    var category = _selectedCategory;
    var range = RangeValues(_minPrice, _maxPrice);
    var sort = _sortBy;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketPalette.canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    decoration: BoxDecoration(
                      color: MarketPalette.lineStrong,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('Filtreler', style: MarketText.title(size: 22))),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          category = '';
                          range = const RangeValues(0, 1000);
                          sort = 'createdAt';
                        }),
                        child: const Text('Temizle'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    children: [
                      Text('Kategori', style: MarketText.heading(size: 16)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tümü'),
                            selected: category.isEmpty,
                            onSelected: (_) => setSheetState(() => category = ''),
                          ),
                          for (final item in _suggestions)
                            ChoiceChip(
                              label: Text(categoryDisplayName(item)),
                              selected: category == item,
                              onSelected: (_) => setSheetState(() => category = item),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Text('Fiyat aralığı', style: MarketText.heading(size: 16))),
                          Text(
                            '${formatTlShort(range.start)} – ${formatTlShort(range.end)}${range.end >= 1000 ? '+' : ''}',
                            style: MarketText.label(color: MarketPalette.greenDark),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: range,
                        min: 0,
                        max: 1000,
                        divisions: 20,
                        labels: RangeLabels(
                          formatTlShort(range.start),
                          formatTlShort(range.end),
                        ),
                        onChanged: (values) => setSheetState(() => range = values),
                      ),
                      const SizedBox(height: 12),
                      Text('Sıralama', style: MarketText.heading(size: 16)),
                      const SizedBox(height: 4),
                      RadioGroup<String>(
                        groupValue: sort,
                        onChanged: (value) =>
                            setSheetState(() => sort = value ?? 'createdAt'),
                        child: Column(
                          children: [
                            for (final entry in _sortLabels.entries)
                              RadioListTile<String>(
                                value: entry.key,
                                title: Text(entry.value),
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    child: const Text('Sonuçları göster'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied != true || !mounted) return;
    setState(() {
      _selectedCategory = category;
      _minPrice = range.start;
      _maxPrice = range.end;
      _sortBy = sort;
    });
    _research();
  }

  Widget _buildSliverResults() {
    if (_isLoading) {
      return const SliverToBoxAdapter(child: MarketProductGridSkeleton());
    }

    if (_searchResults.isEmpty && _hasSearched && _searchController.text.isNotEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: MarketEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Sonuç bulunamadı',
          message: _hasFilters
              ? 'Filtreleri gevşetmeyi ya da farklı bir kelime denemeyi unutma.'
              : 'Farklı bir kelimeyle veya marka adıyla tekrar dene.',
          actionLabel: _hasFilters ? 'Filtreleri sıfırla' : null,
          actionIcon: Icons.restart_alt_rounded,
          onAction: _hasFilters ? _resetFilters : null,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_recentSearches.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(child: Text('Son aramaların', style: MarketText.heading(size: 16))),
                    TextButton(
                      onPressed: _clearRecentSearches,
                      child: const Text('Temizle'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentSearches.map(_buildSearchChip).toList(),
                ),
                const SizedBox(height: 26),
              ],
              if (_suggestions.isNotEmpty) ...[
                Text('Kategorilerde keşfet', style: MarketText.heading(size: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.take(12).map(_buildCategoryChip).toList(),
                ),
                const SizedBox(height: 26),
              ],
              MarketCard(
                shadow: false,
                color: MarketPalette.greenSoft,
                borderColor: MarketPalette.greenLine,
                child: Row(
                  children: [
                    const MarketIconTile(
                      icon: Icons.manage_search_rounded,
                      size: 44,
                      background: Colors.white,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        'En az 2 harf yaz; sonuçlar sen yazarken gelir. Filtrelerle kategori, fiyat ve sıralamayı daralt.',
                        style: MarketText.body(color: MarketPalette.greenDeep, size: 13),
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

    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
          child: Text(
            '${_searchResults.length} ürün bulundu',
            style: MarketText.label(color: MarketPalette.muted, size: 13),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
                (context, index) => MarketProductCard(product: _searchResults[index]),
                childCount: _searchResults.length,
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildSearchChip(String text) => ActionChip(
        avatar: const Icon(Icons.history_rounded, size: 17, color: MarketPalette.muted),
        label: Text(text),
        onPressed: () {
          _searchController.text = text;
          _performSearch(text);
          setState(() {});
        },
      );

  Widget _buildCategoryChip(String text) => ActionChip(
        avatar: Text(categoryEmoji(text), style: const TextStyle(fontSize: 16)),
        label: Text(categoryDisplayName(text)),
        onPressed: () {
          setState(() => _selectedCategory = text);
          _searchController.text = text;
          _performSearch(text);
        },
      );
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MarketPalette.greenSoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.md),
        side: BorderSide(color: active ? MarketPalette.green : MarketPalette.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: active ? MarketPalette.greenDark : MarketPalette.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: MarketText.label(
                  color: active ? MarketPalette.greenDeep : MarketPalette.ink,
                  size: 13,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? MarketPalette.greenDark : MarketPalette.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
