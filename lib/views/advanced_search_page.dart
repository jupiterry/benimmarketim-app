import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/meta_app_events_service.dart';
import '../services/turkish_text.dart';
import 'widgets/browse_cart_bar.dart';
import 'widgets/browse_controls.dart';
import 'widgets/category_presentation.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';

/// Tüm markette ürün arama.
///
/// Arama kutusu üstte sabit durur; en az 2 harf yazınca sonuçlar gelir.
/// Boşken son aramalar ve reyonlar gösterilir. Altta sepet doluyken
/// "Sepete git" çubuğu durur.
class AdvancedSearchPage extends StatefulWidget {
  /// Başka bir ekrandan aranacak metinle açılırsa (ör. reyondaki "Tüm markette
  /// ara") arama kutusuna yazılacak sorgu. `/search` rotasının `extra`'sı.
  final String? initialQuery;

  const AdvancedSearchPage({super.key, this.initialQuery});

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

/// Sunucuya giden sıralama değerleri. 'createdAt' gönderilmez (sunucunun
/// varsayılan sıralaması), bu yüzden kullanıcıya "Önerilen" olarak görünür.
const _defaultSort = 'createdAt';

const _sortLabels = <String, String>{
  _defaultSort: 'Önerilen',
  'price_low': 'En düşük fiyat',
  'price_high': 'En yüksek fiyat',
  'name_asc': 'İsim (A-Z)',
  'name_desc': 'İsim (Z-A)',
};

const _recentSearchesKey = 'recent_product_searches';
const _maxRecentSearches = 6;
const _maxPrice = 1000.0;

/// Sonuçların gelmesi için gereken en az harf sayısı.
const _minQueryLength = 2;

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ApiService _apiService = ApiService();

  List<Product> _searchResults = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;

  /// Ekrandaki sonuçların ait olduğu sorgu.
  String _shownQuery = '';

  /// En az bir ürün döndüren son sorgu; sayfadan çıkarken son aramalara
  /// kaydedilir.
  String? _lastSuccessfulQuery;

  String _selectedCategory = '';
  double _minPrice = 0;
  double _maxPriceFilter = _maxPrice;
  String _sortBy = _defaultSort;
  Timer? _debounce;
  int _searchRequestId = 0;
  List<String> _recentSearches = [];
  bool _recentsLoaded = false;

  String get _query => _searchController.text.trim();

  /// Sonuç alanı gösterilsin mi: en az 2 harf ya da klavyeden bilerek
  /// aranmış tek harf.
  bool get _hasQuery =>
      _query.length >= _minQueryLength ||
      (_query.isNotEmpty && (_isLoading || _shownQuery == _query));
  bool get _priceFiltered => _minPrice > 0 || _maxPriceFilter < _maxPrice;
  int get _activeFilterCount =>
      (_selectedCategory.isNotEmpty ? 1 : 0) + (_priceFiltered ? 1 : 0);
  bool get _hasFilters => _activeFilterCount > 0 || _sortBy != _defaultSort;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _loadRecentSearches();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) _searchController.text = initial;
    if (initial.length >= _minQueryLength) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performSearch(initial, remember: true);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Sonuç veren son arama, sayfadan çıkarken son aramalara eklenir (yarım
    // yazılmış ya da sonuçsuz sorgular kaydedilmez).
    final last = _lastSuccessfulQuery;
    if (last != null && _recentsLoaded) {
      unawaited(_writeRecentSearches(
        _withRecent(_recentSearches, last, expandPartial: true),
      ));
    }
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // --- Son aramalar ----------------------------------------------------------

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentSearchesKey) ?? [];
      if (!mounted) return;
      setState(() {
        _recentSearches = saved;
        _recentsLoaded = true;
      });
    } catch (e) {
      AppLogger.debug('Son aramalar okunamadı: $e');
    }
  }

  /// a, b'nin kelime ortasında kesilmiş başı mı ("çik" / "çikolata").
  /// İkisi de [TurkishText.normalize]'dan geçmiş olmalı.
  static bool _isPartialOf(String a, String b) =>
      a.length < b.length && b.startsWith(a) && b[a.length] != ' ';

  /// [query]'yi başa ekler; aynısını ve onun yarım yazılmış hallerini
  /// ("çik" → "çikolata") listeden çıkarır.
  ///
  /// [expandPartial]: sorgu kullanıcı bilerek aramadan kaydediliyor (sayfadan
  /// çıkış). Listedeki bir aramanın yarım hali ise onun yerine o tam arama
  /// başa alınır. Klavyeden / çipten bilerek yapılan arama ise yazıldığı gibi
  /// kaydedilir ("süt" aranınca listedeki "sütlaç" yerine "süt" saklanır).
  static List<String> _withRecent(
    List<String> current,
    String query, {
    bool expandPartial = false,
  }) {
    final key = TurkishText.normalize(query);
    var first = query;
    final known = current.any((entry) => TurkishText.normalize(entry) == key);
    if (expandPartial && !known) {
      for (final entry in current) {
        if (_isPartialOf(key, TurkishText.normalize(entry))) {
          first = entry;
          break;
        }
      }
    }
    final firstKey = TurkishText.normalize(first);
    return [
      first,
      ...current.where((entry) {
        final k = TurkishText.normalize(entry);
        return k != firstKey && !_isPartialOf(k, firstKey);
      }),
    ].take(_maxRecentSearches).toList();
  }

  static Future<void> _writeRecentSearches(List<String> searches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (searches.isEmpty) {
        await prefs.remove(_recentSearchesKey);
      } else {
        await prefs.setStringList(_recentSearchesKey, searches);
      }
    } catch (e) {
      AppLogger.debug('Son aramalar kaydedilemedi: $e');
    }
  }

  void _rememberSearch(String query) {
    if (!_recentsLoaded) return;
    final updated = _withRecent(_recentSearches, query);
    setState(() => _recentSearches = updated);
    unawaited(_writeRecentSearches(updated));
  }

  void _removeRecentSearch(String query) {
    final updated = _recentSearches.where((item) => item != query).toList();
    // Kaldırılan arama (ya da yarım hali) sayfadan çıkarken geri yazılmasın.
    final last = _lastSuccessfulQuery;
    if (last != null) {
      final lastKey = TurkishText.normalize(last);
      final removedKey = TurkishText.normalize(query);
      if (lastKey == removedKey || _isPartialOf(lastKey, removedKey)) {
        _lastSuccessfulQuery = null;
      }
    }
    setState(() => _recentSearches = updated);
    unawaited(_writeRecentSearches(updated));
  }

  void _clearRecentSearches() {
    // Temizlenen liste sayfadan çıkarken son aramayla yeniden dolmasın.
    _lastSuccessfulQuery = null;
    setState(() => _recentSearches = []);
    unawaited(_writeRecentSearches(const []));
  }

  // --- Reyonlar --------------------------------------------------------------

  // Kategori önerileri (filtre ve "Kategorilere göz at" çipleri): aktif
  // kategoriler sunucudan okunur.
  Future<void> _loadSuggestions() async {
    try {
      final categories = await _apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = [
          for (final category in categories)
            if (category.isActive) category,
        ];
      });
    } catch (e) {
      AppLogger.debug('Öneriler yüklenemedi: $e');
    }
  }

  void _openCategory(Category category) {
    FocusScope.of(context).unfocus();
    context.push('/category', extra: category);
  }

  // --- Arama -----------------------------------------------------------------

  // Akıllı arama. [remember]: kullanıcı aramayı bilerek yaptı (klavyeden ara,
  // son arama çipi); sonuç varsa son aramalara eklenir.
  Future<void> _performSearch(String query, {bool remember = false}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();

    // Yalnızca en son başlatılan aramanın sonucu ekrana yazılır; yavaş dönen
    // eski bir yanıt yeni sonucu ezemez.
    final requestId = ++_searchRequestId;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.searchProducts(
        query: query,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPriceFilter < _maxPrice ? _maxPriceFilter : null,
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
        _shownQuery = trimmed;
      });
      if (products.isNotEmpty) {
        _lastSuccessfulQuery = trimmed;
        if (remember) _rememberSearch(trimmed);
      }
      // Meta: yalnızca gönderilen arama sayılır, yazarken yapılanlar değil
      if (remember) {
        unawaited(MetaAppEventsService.instance
            .logSearch(trimmed, resultCount: products.length));
      }
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      // Sonuçlar ekrandaysa korunur; hata kısa bir bildirimle söylenir.
      if (_searchResults.isNotEmpty) {
        showMarketSnack(
          context,
          'Arama yapılamadı. Bağlantını kontrol edip tekrar dene.',
          error: true,
        );
      }
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < _minQueryLength) {
      // Kutu boşaldı ya da tek harf kaldı: eski sonuçlar ve yoldaki istek
      // bırakılır, boş ekran (son aramalar, reyonlar) geri gelir.
      _searchRequestId++;
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
        _error = null;
        _shownQuery = '';
      });
      return;
    }
    // İstek kısa bir beklemeden sonra gider; o sırada yükleniyor gösterilir.
    setState(() => _isLoading = true);
    _debounce = Timer(
      const Duration(milliseconds: 380),
      () => _performSearch(value),
    );
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    // Aynı sorgunun sonuçları zaten ekrandaysa tekrar istek atılmaz.
    if (trimmed == _shownQuery && !_isLoading && _error == null) {
      if (_searchResults.isNotEmpty) _rememberSearch(trimmed);
      return;
    }
    _performSearch(value, remember: true);
  }

  void _searchFor(String text) {
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    FocusScope.of(context).unfocus();
    _performSearch(text, remember: true);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchRequestId++;
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
      _isLoading = false;
      _error = null;
      _shownQuery = '';
    });
    _searchFocus.requestFocus();
  }

  void _research() {
    if (_query.isNotEmpty) _performSearch(_searchController.text);
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = '';
      _minPrice = 0;
      _maxPriceFilter = _maxPrice;
      _sortBy = _defaultSort;
    });
    _research();
  }

  String _priceLabel(double min, double max) {
    if (min > 0 && max >= _maxPrice) return '${formatTlShort(min)} ve üzeri';
    if (min <= 0) return '${formatTlShort(max)} altı';
    return '${formatTlShort(min)} – ${formatTlShort(max)}';
  }

  // --- Görünüm ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fieldHeight = math.max(52.0, scaler.scale(16) * 1.45 + 28);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      // Gövde sepet çubuğunun arkasına uzanır; alt boşluk paddingOf'tan gelir.
      extendBody: true,
      bottomNavigationBar: const BrowseCartBar(),
      // Çubuğun yüksekliği yalnızca Scaffold'un gövdesindeki bağlamda
      // paddingOf'a eklenir; alt boşluk bu yüzden burada okunur.
      body: Builder(
        builder: (bodyContext) {
          final bottomGap = MediaQuery.paddingOf(bodyContext).bottom + 24;
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: MarketScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(
                  extent: fieldHeight + 24,
                  child: _buildSearchBar(fieldHeight),
                ),
              ),
              if (_hasQuery) SliverToBoxAdapter(child: _buildFilterChips()),
              ..._buildBody(bottomGap),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(double fieldHeight) {
    final gutter = MarketSpace.gutterOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
      child: Row(
        children: [
          MarketHeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Geri',
            onTap: _pop,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              label: 'Ürün ara',
              child: SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: widget.initialQuery == null,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                  onSubmitted: _onSubmitted,
                  style: MarketText.body(size: 16),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Ürün veya marka ara',
                    filled: true,
                    fillColor: MarketPalette.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: MarketPalette.green,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Aramayı temizle',
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
                      borderSide:
                          const BorderSide(color: MarketPalette.lime, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pop() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }

  Widget _buildFilterChips() {
    final count = _activeFilterCount;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: BrowseChipRow(
        padding:
            EdgeInsets.symmetric(horizontal: MarketSpace.gutterOf(context)),
        children: [
          MarketChip(
            label: 'Filtrele',
            icon: Icons.tune_rounded,
            selected: count > 0,
            badgeCount: count > 0 ? count : null,
            onTap: _openFilters,
          ),
          MarketChip(
            label: _sortBy == _defaultSort
                ? 'Sırala'
                : (_sortLabels[_sortBy] ?? 'Sırala'),
            icon: Icons.swap_vert_rounded,
            dropdown: true,
            selected: _sortBy != _defaultSort,
            onTap: _openSort,
            semanticLabel: 'Sırala, ${_sortLabels[_sortBy] ?? 'Önerilen'}',
          ),
          if (_selectedCategory.isNotEmpty)
            MarketChip(
              label: categoryDisplayName(_selectedCategory),
              leading: Text(
                categoryEmoji(_selectedCategory),
                style: MarketText.emoji(16),
              ),
              selected: true,
              onTap: _openFilters,
              onClear: () {
                setState(() => _selectedCategory = '');
                _research();
              },
            ),
          if (_priceFiltered)
            MarketChip(
              label: _priceLabel(_minPrice, _maxPriceFilter),
              icon: Icons.sell_outlined,
              selected: true,
              onTap: _openFilters,
              onClear: () {
                setState(() {
                  _minPrice = 0;
                  _maxPriceFilter = _maxPrice;
                });
                _research();
              },
            ),
          if (_hasFilters) BrowseClearButton(onPressed: _resetFilters),
        ],
      ),
    );
  }

  Future<void> _openSort() async {
    FocusScope.of(context).unfocus();
    final picked = await showBrowseSortSheet<String>(
      context,
      options: _sortLabels,
      selected: _sortBy,
    );
    if (picked == null || picked == _sortBy || !mounted) return;
    setState(() => _sortBy = picked);
    _research();
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    var category = _selectedCategory;
    var range = RangeValues(_minPrice, _maxPriceFilter);

    final applied = await showMarketSheet<bool>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final rangeLabel = range.start <= 0 && range.end >= _maxPrice
              ? 'Tümü'
              : _priceLabel(range.start, range.end);
          return MarketSheetScaffold(
            header: const MarketSheetHeader(
              title: 'Filtrele',
              subtitle: 'Sonuçları kategoriye ve fiyata göre daralt.',
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kategori', style: MarketText.heading(size: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    MarketChip(
                      label: 'Tümü',
                      selected: category.isEmpty,
                      onTap: () => setSheetState(() => category = ''),
                    ),
                    for (final item in _categories)
                      MarketChip(
                        label: categoryDisplayName(item.name),
                        leading: Text(
                          categoryEmoji(item.name),
                          style: MarketText.emoji(16),
                        ),
                        selected: category == item.name,
                        onTap: () => setSheetState(() => category = item.name),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fiyat aralığı',
                        style: MarketText.heading(size: 16),
                      ),
                    ),
                    Text(
                      rangeLabel,
                      style: MarketText.label(color: MarketPalette.greenDark),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: _maxPrice,
                  divisions: 20,
                  labels: RangeLabels(
                    formatTlShort(range.start),
                    range.end >= _maxPrice
                        ? '${formatTlShort(range.end)}+'
                        : formatTlShort(range.end),
                  ),
                  semanticFormatterCallback: (value) => value >= _maxPrice
                      ? '${formatTlShort(value)} ve üzeri'
                      : formatTlShort(value),
                  onChanged: (values) => setSheetState(() => range = values),
                ),
              ],
            ),
            footer: Row(
              children: [
                TextButton(
                  onPressed: category.isEmpty &&
                          range.start <= 0 &&
                          range.end >= _maxPrice
                      ? null
                      : () => setSheetState(() {
                            category = '';
                            range = const RangeValues(0, _maxPrice);
                          }),
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.greenDark,
                    minimumSize: const Size(88, MarketSize.button),
                  ),
                  child: const Text('Temizle'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(MarketSize.button),
                    ),
                    child: const Text('Uygula'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (applied != true || !mounted) return;
    setState(() {
      _selectedCategory = category;
      _minPrice = range.start;
      _maxPriceFilter = range.end;
    });
    _research();
  }

  List<Widget> _buildBody(double bottomGap) {
    final gutter = MarketSpace.gutterOf(context);

    if (!_hasQuery) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, bottomGap),
          sliver: SliverToBoxAdapter(child: _buildIdle()),
        ),
      ];
    }

    if (_searchResults.isEmpty) {
      if (_isLoading) {
        return [
          SliverToBoxAdapter(
            child: MarketProductGridSkeleton(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, bottomGap),
            ),
          ),
        ];
      }
      if (_error != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomGap),
              child: MarketEmptyState.error(
                title: 'Arama yapılamadı',
                message: 'Bağlantını kontrol edip tekrar dene.',
                onRetry: _research,
              ),
            ),
          ),
        ];
      }
      if (_hasSearched) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketEmptyState(
                    icon: Icons.search_off_rounded,
                    title: '“$_shownQuery” için sonuç yok',
                    message: _activeFilterCount > 0
                        ? 'Filtreleri kaldırmayı ya da daha genel bir kelime denemeyi unutma.'
                        : 'Yazımı kontrol et ya da daha genel bir kelime dene.',
                    actionLabel:
                        _activeFilterCount > 0 ? 'Filtreleri temizle' : null,
                    actionIcon: Icons.filter_alt_off_rounded,
                    onAction: _activeFilterCount > 0 ? _resetFilters : null,
                  ),
                  if (_categories.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: _buildCategorySection(
                        title: 'Kategorilere göz at',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ];
      }
      // Bekleme süresi dolmadan: iskelet (boş ekran yanıp sönmesin).
      return [
        SliverToBoxAdapter(
          child: MarketProductGridSkeleton(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, bottomGap),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yeni sonuçlar yüklenirken eski ızgara durur; üstte ince bir
              // çizgi ilerler (yer hep ayrılı, sayfa zıplamaz).
              SizedBox(
                height: 3,
                child: _isLoading
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(MarketRadius.pill),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          color: MarketPalette.green,
                          backgroundColor: MarketPalette.greenSoft,
                          semanticsLabel: 'Aranıyor',
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 9),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  '“$_shownQuery” için ${_searchResults.length} ürün',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.heading(size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomGap),
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
                (context, index) =>
                    MarketProductCard(product: _searchResults[index]),
                childCount: _searchResults.length,
              ),
            );
          },
        ),
      ),
    ];
  }

  /// Boş ekran: son aramalar, reyonlar ve kısa bir ipucu.
  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Son aramaların',
                    style: MarketText.heading(size: 16),
                  ),
                ),
              ),
              // Düğmenin iç boşluğu kenar boşluğuna taşar; "Temizle" yazısı
              // sayfa kenarıyla hizalanır.
              Transform.translate(
                offset: const Offset(8, 0),
                child: TextButton(
                  onPressed: _clearRecentSearches,
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.greenDark,
                    textStyle: MarketText.label(size: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, MarketSize.control),
                  ),
                  child: const Text(
                    'Temizle',
                    semanticsLabel: 'Son aramaları temizle',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            children: [
              for (final text in _recentSearches)
                _RecentSearchChip(
                  label: text,
                  onTap: () => _searchFor(text),
                  onRemove: () => _removeRecentSearch(text),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (_categories.isNotEmpty) ...[
          _buildCategorySection(title: 'Kategorilere göz at'),
          const SizedBox(height: 24),
        ],
        const MarketNotice.info(
          icon: Icons.lightbulb_outline_rounded,
          text: 'Marka adıyla da arayabilirsin, ör. Ülker.',
        ),
      ],
    );
  }

  Widget _buildCategorySection({required String title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: MarketText.heading(size: 16)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final category in _categories.take(12))
              MarketChip(
                label: categoryDisplayName(category.name),
                leading: _CategoryDot(name: category.name),
                onTap: () => _openCategory(category),
                semanticLabel:
                    '${categoryDisplayName(category.name)} reyonunu aç',
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Parçalar
// ---------------------------------------------------------------------------

/// Reyon çipinin solundaki renkli daire + emoji (ana sayfadaki kategori
/// kutularıyla aynı tonlar).
class _CategoryDot extends StatelessWidget {
  final String name;

  const _CategoryDot({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: categoryTint(name),
        shape: BoxShape.circle,
      ),
      child: Text(categoryEmoji(name), style: MarketText.emoji(15)),
    );
  }
}

/// Son arama çipi: dokununca aynı aramayı yapar, ✕ ile listeden kaldırılır.
/// Görünüm [MarketChip] ile aynıdır (40 pt hap, 48 pt dokunma alanı). ✕'in
/// dokunma alanı sondaki 44 pt'nin tamamıdır (üst/alt boşluk dahil 44x48).
class _RecentSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  static const double _removeWidth = MarketSize.control;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: MarketPalette.surface,
      shape: const StadiumBorder(side: BorderSide(color: MarketPalette.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 17,
                  color: MarketPalette.muted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(size: 13, weight: FontWeight.w600),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '“$label” aramasını kaldır',
                  excludeSemantics: true,
                  // excludeSemantics InkWell'in eylemini de düşürür; ekran
                  // okuyucu dokunuşu buradan gelir.
                  onTap: onRemove,
                  child: Tooltip(
                    message: 'Kaldır',
                    excludeFromSemantics: true,
                    child: InkWell(
                      onTap: onRemove,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: _removeWidth,
                        height: 40,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: MarketPalette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: '“$label” ara',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // Çipin üstündeki/altındaki 4 pt da dokunmayı alır (48 pt hedef);
        // ✕'in üstü ve altı kaldırmaya gider.
        onTapUp: (details) {
          final width = context.size?.width ?? 0;
          if (details.localPosition.dx >= width - _removeWidth) {
            onRemove();
          } else {
            onTap();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: chip,
        ),
      ),
    );
  }
}

/// Üstte sabit duran arama çubuğu (geri + arama kutusu).
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _SearchBarDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: ColoredBox(
        // Köşelerin arkası, içerik henüz çubuğun altına girmemişken zemin
        // rengindedir (ana sayfadaki arama bandı gibi).
        color: overlapsContent ? Colors.transparent : MarketPalette.canvas,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: MarketPalette.headerGradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(MarketRadius.xl),
            ),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep
                    .withValues(alpha: overlapsContent ? .18 : 0),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // Arama kutusu ve temizle düğmesi her yeniden çizimde yeni durumla gelir.
  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) => true;
}
