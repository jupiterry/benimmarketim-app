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
  List<Product>? _shuffledProducts;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _tabController = TabController(length: 2, vsync: this);

    // ViewModel'deki tab index'i dinle
    final viewModel = context.read<HomePageViewModel>();
    if (viewModel.currentTabIndex != _selectedIndex) {
      viewModel.setTabIndex(_selectedIndex);
    }

    _tabController.addListener(_onTabChanged);

    _shuffledProducts = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      if (authViewModel.isLoggedIn && authViewModel.user == null) {
        authViewModel.updateProfile();
      }
      context.read<CategoryViewModel>().loadCategories();
      context.read<HomePageViewModel>().loadHomeProducts();
      context.read<BannerViewModel>().loadBanners();

      if (widget.openOrders) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            context.push('/orders');
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      // Bu kısım artık ViewModel üzerinden yönetilecek ama yedek olarak kalsın
      context.read<HomePageViewModel>().setTabIndex(widget.initialTabIndex);
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      context.read<HomePageViewModel>().setTabIndex(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomePageViewModel>(
      builder: (context, viewModel, child) {
        // ViewModel değiştiğinde tab'ı güncelle
        if (_tabController.index != viewModel.currentTabIndex) {
          _tabController.animateTo(viewModel.currentTabIndex);
          _selectedIndex = viewModel.currentTabIndex;
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          extendBody: true,
          body: _getCurrentPage(),
          bottomNavigationBar: _buildBottomNavigation(),
        );
      },
    );
  }

  Widget _getCurrentPage() {
    Widget page;
    // _selectedIndex yerine ViewModel'i kullanabiliriz ama animasyon için local state tutmak daha iyi olabilir
    // Ancak build içinde senkronize ediyoruz.

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

    final bool isMovingRight = _selectedIndex > _previousIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
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
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          _buildSliverAppBar(),
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  indicator: BoxDecoration(
                    color: AppColors.successGreen,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Ana Sayfa'),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Kategoriler'),
                      ),
                    ),
                  ],
                ),
              ),
              pinned: false,
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeContent(),
          _buildCategoriesContent(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      collapsedHeight: 90.0,
      toolbarHeight: 90.0,
      floating: false,
      snap: false,
      pinned: true,
      backgroundColor: Colors
          .grey[50], // Sayfa rengiyle aynı olmalı ki "hanging" efekti çalışsın
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.0,
        titlePadding: const EdgeInsets.only(left: 24, right: 24, bottom: 15),
        centerTitle: true,
        title: GestureDetector(
          onTap: () => context.push('/search'),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: AppColors.successGreen,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ne aramıştınız?',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Ürün, kategori veya marka...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.successGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        background: Align(
          alignment: Alignment.topCenter,
          child: Consumer<AuthViewModel>(
            builder: (context, authViewModel, child) {
              String userName = 'Kullanıcı';
              String userInitials = 'K';
              if (authViewModel.isLoggedIn && authViewModel.user != null) {
                final name = authViewModel.user!.name;
                userName = name.isNotEmpty ? name : 'Kullanıcı';
                if (userName.isNotEmpty) {
                  userInitials = userName
                      .trim()
                      .split(' ')
                      .map((e) => e[0])
                      .take(2)
                      .join()
                      .toUpperCase();
                }
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Yeşil Arka Plan
                  Container(
                    height: 150,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 24,
                      right: 24,
                    ),
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
                        bottom: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C639).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  userInitials,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // İsim ve Selamlama
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merhaba,',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Bildirim İkonu
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Dekoratif Daireler
                  Positioned(
                    top: -60,
                    left: -60,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          key: const PageStorageKey<String>('home'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildBannerSlider(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Ürünler',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            _buildProductSliverGrid(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        );
      },
    );
  }

  Widget _buildProductSliverGrid() {
    return Consumer<HomePageViewModel>(
      builder: (context, productViewModel, child) {
        if (productViewModel.isLoading) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const SkeletonProductCard(),
                childCount: 4,
              ),
            ),
          );
        }

        final targetCategories = ['atistirma', 'icecekler', 'yiyecekler'];
        final filteredProducts = productViewModel.products.where((product) {
          final category = product.category.toLowerCase().trim();
          return targetCategories.contains(category);
        }).toList();

        if (filteredProducts.isNotEmpty) {
          if (_shuffledProducts == null) {
            final shuffled = List<Product>.from(filteredProducts);
            shuffled.shuffle();
            _shuffledProducts = shuffled;
          } else {
            final shuffledIds = _shuffledProducts!.map((p) => p.id).toSet();
            final filteredIds = filteredProducts.map((p) => p.id).toSet();
            if (shuffledIds.length != filteredIds.length ||
                !shuffledIds.every((id) => filteredIds.contains(id))) {
              final shuffled = List<Product>.from(filteredProducts);
              shuffled.shuffle();
              _shuffledProducts = shuffled;
            }
          }
        } else {
          _shuffledProducts = null;
        }

        final products =
            (_shuffledProducts != null && _shuffledProducts!.isNotEmpty)
                ? _shuffledProducts!.take(20).toList()
                : filteredProducts.take(20).toList();

        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
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
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return _buildProductGridCard(product);
              },
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesContent() {
    return Builder(
      builder: (BuildContext context) {
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
          child: CustomScrollView(
            key: const PageStorageKey<String>('categories'),
            slivers: [
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              _buildCategorySliverGrid(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySliverGrid() {
    return Consumer<CategoryViewModel>(
      builder: (context, categoryViewModel, child) {
        if (categoryViewModel.isLoading) {
          return SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.successGreen),
              ),
            ),
          );
        }

        if (categoryViewModel.categories.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kategori bulunamadı',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = categoryViewModel.categories[index];
                return _buildCategoryCard(context, category, index);
              },
              childCount: categoryViewModel.categories.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category, int index) {
    // Modern pastel renk paleti
    final List<Color> colors = [
      const Color(0xFFE3F2FD), // Blue
      const Color(0xFFF3E5F5), // Purple
      const Color(0xFFE8F5E9), // Green
      const Color(0xFFFFF3E0), // Orange
      const Color(0xFFFFEBEE), // Red
      const Color(0xFFE0F7FA), // Cyan
      const Color(0xFFFFF8E1), // Amber
      const Color(0xFFFCE4EC), // Pink
    ];

    final List<Color> iconColors = [
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      const Color(0xFF2E7D32),
      const Color(0xFFEF6C00),
      const Color(0xFFC62828),
      const Color(0xFF00838F),
      const Color(0xFFFF8F00),
      const Color(0xFFAD1457),
    ];

    final colorIndex = index % colors.length;
    final bgColor = colors[colorIndex];
    final iconColor = iconColors[colorIndex];

    return GestureDetector(
      onTap: () {
        context.push('/category-products', extra: category);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(
                _getCategoryIcon(category.name),
                color: iconColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'benim kahvem':
        return Icons.coffee_rounded;
      case 'yiyecekler':
        return Icons.restaurant_rounded;
      case 'kahvaltılık ürünler':
        return Icons.egg_alt_rounded;
      case 'temel gıda':
        return Icons.kitchen_rounded;
      case 'meyve & sebze':
        return Icons.apple_rounded;
      case 'süt & süt ürünleri':
        return Icons.water_drop_rounded;
      case 'beş para etmeyen ürünler':
        return Icons.money_off_rounded;
      case 'toz içecekler':
        return Icons.local_cafe_rounded;
      case 'cips & çerez':
        return Icons.cookie_rounded;
      case 'çay ve şekerler':
        return Icons.emoji_food_beverage_rounded;
      case 'atıştırmalıklar':
        return Icons.fastfood_rounded;
      case 'temizlik & hijyen':
        return Icons.cleaning_services_rounded;
      case 'kişisel bakım':
        return Icons.face_rounded;
      case 'makarna ve kuru bakliyat':
        return Icons.grain_rounded;
      case 'şarküteri & et ürünleri':
        return Icons.kebab_dining_rounded;
      case 'buz gibi içecekler':
        return Icons.ac_unit_rounded;
      case 'dondurulmuş gıdalar':
        return Icons.ac_unit_rounded;
      case 'baharatlar':
        return Icons.spa_rounded;
      case 'golf dondurmalar':
        return Icons.icecream_rounded;
      default:
        return Icons.category_rounded;
    }
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
                              onTap: product.isOutOfStock
                                  ? () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Üzgünüz, bu ürün stokta yok.',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  : () {
                                      cartViewModel.addToCart(product);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.name} sepete eklendi',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor:
                                              AppColors.successGreen,
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: product.isOutOfStock
                                      ? Colors.grey[300]
                                      : AppColors.successGreen,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: product.isOutOfStock
                                          ? Colors.transparent
                                          : AppColors.successGreen.withOpacity(
                                              0.3,
                                            ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  product.isOutOfStock
                                      ? Icons.remove_shopping_cart_outlined
                                      : Icons.add_shopping_cart,
                                  color: product.isOutOfStock
                                      ? Colors.grey[500]
                                      : Colors.white,
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

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              Icons.home_rounded,
              'Ana Sayfa',
              0,
              _selectedIndex == 0,
            ),
            _buildNavItem(
              Icons.shopping_cart_rounded,
              'Sepet',
              1,
              _selectedIndex == 1,
            ),
            _buildNavItem(
              Icons.person_rounded,
              'Hesap',
              2,
              _selectedIndex == 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    bool isSelected,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _previousIndex = _selectedIndex;
            _selectedIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutBack,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.successGreen.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isSelected ? 8 : 0),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.successGreen : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.successGreen.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[400],
                  size: isSelected ? 24 : 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.successGreen : Colors.grey[400],
                  height: 1.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 20;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 20;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50],
      child: Container(
        margin: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
