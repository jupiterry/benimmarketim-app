import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../viewmodels/home_page_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/banner_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../views/widgets/product_card.dart';
import '../views/widgets/skeleton_widgets.dart';
import '../views/categories_page.dart';
import '../views/cart_page.dart';
import '../views/profile_page.dart';

import '../services/theme_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart' as models;
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  final int initialTabIndex;
  final bool openOrders;

  const HomePage({
    super.key,
    this.initialTabIndex = 0,
    this.openOrders = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  int _previousIndex = 0;
  late TabController _tabController;
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();
  List<Product>? _shuffledProducts; // Karıştırılmış ürünleri sakla

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _tabController = TabController(length: 2, vsync: this);
    // Tab değişikliğini dinle
    _tabController.addListener(_onTabChanged);
    // Scroll listener ekle

    // Shuffle'ı sıfırla - uygulama her açıldığında yeni shuffle
    _shuffledProducts = null;
    // Kategorileri, ürünleri ve banner'ları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      // Eğer giriş yapılmışsa ama user bilgisi yoksa yükle
      if (authViewModel.isLoggedIn && authViewModel.user == null) {
        authViewModel.updateProfile();
      }
      context.read<CategoryViewModel>().loadCategories();
      // Ana sayfada her zaman tüm ürünleri yükle (kategori filtresi olmadan)
      // Ana sayfada her zaman tüm ürünleri yükle (kategori filtresi olmadan)
      context.read<HomePageViewModel>().loadHomeProducts();
      context.read<BannerViewModel>().loadBanners();

      // Eğer openOrders true ise Siparişler sayfasına git
      if (widget.openOrders) {
        // Biraz gecikme ekle ki sayfa tam yüklensin
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            // OrdersPage import edilmemiş olabilir, kontrol etmem lazım.
            // Ancak HomePage'de import '../views/profile_page.dart'; var, OrdersPage orada kullanılıyor.
            // Burada OrdersPage'i import etmem gerekebilir.
            // Şimdilik Navigator.pushNamed kullanalım veya OrdersPage'i import edelim.
            // ProfilePage import edilmiş, ama OrdersPage import edilmemiş olabilir.
            // En iyisi route name kullanmak ama route tanımlı mı?
            // main.dart'a bakmadım.
            // Güvenli yol: import 'orders_page.dart'; eklemek.
            // Güvenli yol: import 'orders_page.dart'; eklemek.
            context.push('/orders');
          }
        });
      }
    });
  }

  void _onTabChanged() {
    // Tab değişikliğinde gereksiz reload kaldırıldı
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _bannerController.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _getCurrentPage(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _getCurrentPage() {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = _buildHomeTab();
        break;
      case 1:
        page = const CartPage();
        break;
      case 2:
        page = const ProfilePage();
        break;
      default:
        page = _buildHomeTab();
    }

    // Animasyon yönünü belirle
    final bool isMovingRight = _selectedIndex > _previousIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset(isMovingRight ? 1.0 : -1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Container(key: ValueKey<int>(_selectedIndex), child: page),
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        // Custom Header with Search
        _buildModernHeader(),

        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.successGreen,
            indicatorWeight: 3,
            labelColor: AppColors.successGreen,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Ana Sayfa'),
              Tab(text: 'Kategoriler'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildHomeContent(), _buildCategoriesContent()],
          ),
        ),
      ],
    );
  }

  Widget _buildModernHeader() {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        if (authViewModel.isLoggedIn && authViewModel.user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authViewModel.updateProfile();
          });
        }

        String userName = 'Kullanıcı';
        if (authViewModel.isLoggedIn && authViewModel.user != null) {
          final name = authViewModel.user!.name;
          userName = name.isNotEmpty ? name : 'Kullanıcı';
        }

        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.successGreen,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x3300C639),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Greeting & Notification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merhaba, $userName',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alışverişe başlayalım',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox.shrink(),
                ],
              ),

              const SizedBox(height: 24),

              // Search Bar
              GestureDetector(
                onTap: () {
                  context.push('/search');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.successGreen,
                        size: 26,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Ürün, kategori veya marka ara...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<HomePageViewModel>().refreshProducts();
        await context.read<BannerViewModel>().loadBanners();
      },
      color: AppColors.successGreen,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Slider
            _buildBannerSlider(),

            const SizedBox(height: 24),

            // Ürünler Bölümü
            _buildNewProductsSection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSlider() {
    return Consumer<BannerViewModel>(
      builder: (context, bannerViewModel, child) {
        if (bannerViewModel.isLoading) {
          return SizedBox(
            height: 180,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }

        if (bannerViewModel.banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              // Banner değişti
            },
            itemCount: bannerViewModel.banners.length,
            itemBuilder: (context, index) {
              final banner = bannerViewModel.banners[index];
              return _buildBannerItem(banner);
            },
          ),
        );
      },
    );
  }

  Widget _buildBannerItem(models.Banner banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Banner görseli
            Image.network(
              banner.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Banner image error: $error');
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.successGreenMedium,
                        AppColors.successGreen,
                      ],
                    ),
                  ),
                  child: Icon(Icons.image, color: Colors.white, size: 48),
                );
              },
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
            ),
            // Banner içeriği
            if (banner.title.isNotEmpty || banner.subtitle.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (banner.title.isNotEmpty)
                      Text(
                        banner.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Ürünler',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Consumer<HomePageViewModel>(
          builder: (context, productViewModel, child) {
            if (productViewModel.isLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 4, // 4 tane skeleton göster
                  itemBuilder: (context, index) => const SkeletonProductCard(),
                ),
              );
            }

            // Belirtilen kategorilerden ürünleri filtrele
            final targetCategories = ['atistirma', 'icecekler', 'yiyecekler'];
            final filteredProducts = productViewModel.products.where((product) {
              // Kategori adını normalize et (küçük harf, boşlukları temizle)
              final category = product.category.toLowerCase().trim();
              return targetCategories.contains(category);
            }).toList();

            // Ürünleri sadece ilk yüklemede karıştır (state'te sakla)
            // Uygulama her açıldığında yeni shuffle yapılır
            // Sadece filteredProducts değiştiğinde ve _shuffledProducts null olduğunda shuffle yap
            if (filteredProducts.isNotEmpty) {
              // Eğer _shuffledProducts null ise veya ürün listesi tamamen değiştiyse yeniden shuffle yap
              if (_shuffledProducts == null) {
                final shuffled = List<Product>.from(filteredProducts);
                shuffled.shuffle();
                _shuffledProducts = shuffled;
              } else {
                // Mevcut shuffled products'ın ID'lerini al
                final shuffledIds = _shuffledProducts!.map((p) => p.id).toSet();
                final filteredIds = filteredProducts.map((p) => p.id).toSet();

                // Eğer filtered products ile shuffled products farklıysa yeniden shuffle yap
                if (shuffledIds.length != filteredIds.length ||
                    !shuffledIds.every((id) => filteredIds.contains(id))) {
                  final shuffled = List<Product>.from(filteredProducts);
                  shuffled.shuffle();
                  _shuffledProducts = shuffled;
                }
              }
            } else {
              // Eğer filtered products boşsa, shuffled products'ı da temizle
              _shuffledProducts = null;
            }

            // Karıştırılmış ürünleri kullan veya yoksa normal listeyi kullan
            final products =
                (_shuffledProducts != null && _shuffledProducts!.isNotEmpty)
                ? _shuffledProducts!
                      .take(20)
                      .toList() // 30'dan 20'ye düşürüldü
                : filteredProducts.take(20).toList();

            if (products.isEmpty) {
              return SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ürün bulunamadı',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                cacheExtent: 500, // Performans için cache optimizasyonu
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio:
                      0.85, // Overflow'u önlemek için daha da artırıldı
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildProductGridCard(product);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductGridCard(Product product) {
    return Consumer2<FavoritesViewModel, CartViewModel>(
      builder: (context, favoritesViewModel, cartViewModel, child) {
        final isFavorite = favoritesViewModel.favorites.any(
          (p) => p.id == product.id,
        );

        return GestureDetector(
          onTap: () {
            context.push('/product', extra: product);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün resmi ve favori ikonu
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          color: Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: product.image.isNotEmpty
                              ? Hero(
                                  tag: 'product_image_${product.id}',
                                  child: Image.network(
                                    product.image,
                                    fit: BoxFit
                                        .contain, // cover yerine contain kullan
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey[400],
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      // Favori ikonu
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            final authViewModel = context.read<AuthViewModel>();
                            if (!authViewModel.isLoggedIn) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    'Giriş Yapın',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  content: Text(
                                    'Favorilere eklemek için giriş yapmalısınız.',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'İptal',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.push('/login');
                                      },
                                      child: Text(
                                        'Giriş Yap',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.successGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            favoritesViewModel.toggleFavorite(product);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ürün bilgileri
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ), // Padding daha da azaltıldı
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ürün adı - sadece 1 satır
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12, // Font boyutu daha da küçültüldü
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2, // Line height azaltıldı
                          ),
                          maxLines: 1, // Sadece 1 satır
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Description kaldırıldı - overflow'u önlemek için
                        const Spacer(),
                        // Fiyat ve Sepet Butonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Fiyat
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (product.isDiscounted &&
                                      product.discountedPrice != null) ...[
                                    Text(
                                      '₺${product.price.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                            10, // Font boyutu daha da küçültüldü
                                        color: Colors.grey[500],
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Text(
                                      '₺${product.discountedPrice!.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14, // Font boyutu küçültüldü
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.successGreen,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else
                                    Text(
                                      '₺${product.actualPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14, // Font boyutu küçültüldü
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.successGreen,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            // Sepete Ekle Butonu
                            GestureDetector(
                              onTap: () {
                                cartViewModel.addToCart(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${product.name} sepete eklendi',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: AppColors.successGreen,
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.successGreen.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_shopping_cart,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            AppColors.successGreenLighter.withOpacity(0.3),
          ],
        ),
      ),
      child: const CategoryGrid(),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            Icons.home_outlined,
            Icons.home,
            'Ana Sayfa',
            0,
            _selectedIndex == 0,
          ),
          _buildNavItem(
            Icons.shopping_cart_outlined,
            Icons.shopping_cart,
            'Sepet',
            1,
            _selectedIndex == 1,
          ),
          _buildNavItem(
            Icons.person_outline,
            Icons.person,
            'Hesap',
            2,
            _selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    int index,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _previousIndex = _selectedIndex;
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.successGreenLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.successGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.successGreen : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
