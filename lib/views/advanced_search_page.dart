import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../views/widgets/product_card.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AdvancedSearchPage extends StatefulWidget {
  const AdvancedSearchPage({super.key});

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<Product> _searchResults = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  String _selectedCategory = '';
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _sortBy = 'createdAt';
  Timer? _debounce;
  List<String> _recentSearches = [];

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
    if (mounted)
      setState(() => _recentSearches =
          prefs.getStringList('recent_product_searches') ?? []);
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

  // Arama önerileri yükle
  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _apiService.getSearchSuggestions();
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Öneriler yüklenemedi: $e');
    }
  }

  // Akıllı arama
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

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

      var products = result.products;

      // Client-side sorting guarantee
      if (_sortBy == 'price_low') {
        products.sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
      } else if (_sortBy == 'price_high') {
        products.sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
      } else if (_sortBy == 'name_asc') {
        products.sort((a, b) => a.name.compareTo(b.name));
      } else if (_sortBy == 'name_desc') {
        products.sort((a, b) => b.name.compareTo(a.name));
      }

      setState(() {
        _searchResults = products;
        _isLoading = false;
      });
      await _saveRecentSearch(query);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama yapılamadı. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildFilters(),
              ],
            ),
          ),
          _buildSliverResults(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 60.0,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00C639),
              const Color(0xFF009E2D),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        'Gelişmiş Arama',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          _debounce?.cancel();
          if (value.trim().length >= 2) {
            _debounce = Timer(
                const Duration(milliseconds: 380), () => _performSearch(value));
          }
        },
        onSubmitted: (value) {
          _performSearch(value);
        },
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Ne aramıştınız?',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.successGreen,
            size: 26,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kategori Filtresi
          Row(
            children: [
              Text('Aramayı daralt',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Sıfırla'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.successGreen),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.category_outlined,
                  size: 20, color: AppColors.successGreen),
              const SizedBox(width: 8),
              Text(
                'Kategori',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    hint: Text(
                      'Tümü',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey[600], size: 20),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text('Tümü',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                      ..._suggestions.map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category,
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? '';
                      });
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Fiyat Aralığı
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_money,
                      size: 20, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Fiyat Aralığı',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₺${_minPrice.toInt()} - ₺${_maxPrice.toInt()}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.successGreen,
                  inactiveTrackColor: AppColors.successGreen.withOpacity(0.2),
                  thumbColor: Colors.white,
                  overlayColor: AppColors.successGreen.withOpacity(0.1),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 20),
                  valueIndicatorTextStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice),
                  min: 0,
                  max: 1000,
                  divisions: 20,
                  labels: RangeLabels(
                    '₺${_minPrice.toInt()}',
                    '₺${_maxPrice.toInt()}',
                  ),
                  onChanged: (values) {
                    setState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                  onChangeEnd: (values) {
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Sıralama
          Row(
            children: [
              Icon(Icons.sort, size: 20, color: AppColors.successGreen),
              const SizedBox(width: 8),
              Text(
                'Sıralama',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey[600], size: 20),
                    items: [
                      DropdownMenuItem(
                        value: 'createdAt',
                        child: Text('En Yeni',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'price_low',
                        child: Text('Fiyat (Düşük)',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'price_high',
                        child: Text('Fiyat (Yüksek)',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'name_asc',
                        child: Text('İsim (A-Z)',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'name_desc',
                        child: Text('İsim (Z-A)',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value ?? 'createdAt';
                      });
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverResults() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.successGreen),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded,
                    size: 48, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              Text(
                'Sonuç Bulunamadı',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Farklı anahtar kelimelerle tekrar deneyin',
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 65, 28, 32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.manage_search_rounded,
                    size: 48, color: AppColors.successGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Aradığını kolayca bul',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ürün, marka veya kategori yaz; filtrelerle sonucu anında daralt.',
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 34),
              if (_recentSearches.isNotEmpty) ...[
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Son aramaların',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map(_buildSearchChip).toList()),
              ],
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kategorilerde keşfet',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _suggestions.take(8).map(_buildCategoryChip).toList()),
              ],
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
          child: Text('${_searchResults.length} ürün bulundu',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = _searchResults[index];
              return ProductCard(
                product: product,
                onTap: () {
                  context.push('/product', extra: product);
                },
              );
            },
            childCount: _searchResults.length,
          ),
        ),
      ),
    ]);
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = '';
      _minPrice = 0;
      _maxPrice = 1000;
      _sortBy = 'createdAt';
    });
    if (_searchController.text.trim().isNotEmpty)
      _performSearch(_searchController.text);
  }

  Widget _buildSearchChip(String text) => ActionChip(
        avatar: const Icon(Icons.history_rounded, size: 16),
        label: Text(text,
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () {
          _searchController.text = text;
          _performSearch(text);
          setState(() {});
        },
      );

  Widget _buildCategoryChip(String text) => ActionChip(
        avatar: const Icon(Icons.grid_view_rounded, size: 15),
        label: Text(text,
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () {
          setState(() => _selectedCategory = text);
          _searchController.text = text;
          _performSearch(text);
        },
      );
}
