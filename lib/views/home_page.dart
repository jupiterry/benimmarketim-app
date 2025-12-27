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
import '../viewmodels/chat_viewmodel.dart';
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
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.successGreen.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.successGreen.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.successGreen.withOpacity(0.15),
                        AppColors.successGreen.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.successGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
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
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ürün, kategori veya marka...',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.successGreen,
                        AppColors.successGreen.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 18,
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
                  // Modern Gradient Arka Plan
                  Container(
                    height: 150,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 24,
                      right: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00D946),
                          Color(0xFF00B83A),
                          Color(0xFF009E2D),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C639).withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00C639).withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Modern Avatar with Glow
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  userInitials,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
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
                                      color: Colors.white.withOpacity(0.95),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Modern Bildirim İkonu
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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

                  // Animasyonlu Dekoratif Bubble 1
                  Positioned(
                    top: -70,
                    left: -70,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Dekoratif Bubble 2
                  Positioned(
                    top: 30,
                    right: -50,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Küçük Parıltı Bubble'ları
                  Positioned(
                    top: 20,
                    left: 100,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 80,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.25),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 90,
                    left: 60,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
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
                child: Row(
                  children: [
                    // İkon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.successGreen.withOpacity(0.15),
                            AppColors.successGreen.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.successGreen.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.successGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Başlık ve Alt Başlık
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popüler Ürünler',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'En çok tercih edilenler',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tümü Butonu
                    GestureDetector(
                      onTap: () {
                        // Tüm ürünlere git
                        _tabController.animateTo(1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.successGreen,
                              AppColors.successGreen.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.successGreen.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tümü',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
            height: 200,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[200]!,
                    Colors.grey[100]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );
        }

        if (bannerViewModel.banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            SizedBox(
              height: 190,
              child: PageView.builder(
                controller: _bannerController,
                onPageChanged: (index) {
                  setState(() {});
                },
                itemCount: bannerViewModel.banners.length,
                itemBuilder: (context, index) {
                  final banner = bannerViewModel.banners[index];
                  return _buildBannerItem(banner);
                },
              ),
            ),
            // Modern Page Indicators
            if (bannerViewModel.banners.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    bannerViewModel.banners.length,
                    (index) {
                      final isActive = _bannerController.hasClients
                          ? (_bannerController.page?.round() ?? 0) == index
                          : index == 0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.successGreen
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.successGreen.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBannerItem(models.Banner banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.successGreen.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Banner görseli
            Image.network(
              banner.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00D946),
                        AppColors.successGreen,
                        const Color(0xFF007A25),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.image_rounded, color: Colors.white.withOpacity(0.5), size: 48),
                  ),
                );
              },
            ),
            // Gradient overlay - daha zengin
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.5),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Banner içeriği
            if (banner.title.isNotEmpty || banner.subtitle.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (banner.title.isNotEmpty)
                      Text(
                        banner.title,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        banner.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.95),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 6,
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.successGreen.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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
    return Consumer2<CartViewModel, ChatViewModel>(
      builder: (context, cartViewModel, chatViewModel, child) {
        final cartItemCount = cartViewModel.items.length;
        final chatUnreadCount = chatViewModel.totalUnreadCount;
        
        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          height: 75,
          decoration: BoxDecoration(
            // Glassmorphism efekti - %95 şeffaf beyaz
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Normal nav items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGlassNavItem(
                      Icons.home_rounded,
                      'Ana Sayfa',
                      0,
                      _selectedIndex == 0,
                    ),
                    // Sepet butonu için boşluk
                    const SizedBox(width: 70),
                    // Hesap butonu - chat badge ile
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildGlassNavItem(
                          Icons.person_rounded,
                          'Hesap',
                          2,
                          _selectedIndex == 2,
                        ),
                        // Canlı destek bildirim badge'i
                        if (chatUnreadCount > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  chatUnreadCount > 9 ? '9+' : '$chatUnreadCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Floating Sepet Butonu (Merkezi Yükseltilmiş)
              Positioned(
                top: -22,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _previousIndex = _selectedIndex;
                      _selectedIndex = 1;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _selectedIndex == 1
                            ? [
                                AppColors.successGreen,
                                AppColors.successGreen.withOpacity(0.85),
                              ]
                            : [
                                AppColors.successGreen.withOpacity(0.9),
                                AppColors.successGreen.withOpacity(0.7),
                              ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        // Glow efekti - seçildiğinde daha parlak
                        BoxShadow(
                          color: AppColors.successGreen.withOpacity(
                            _selectedIndex == 1 ? 0.5 : 0.3,
                          ),
                          blurRadius: _selectedIndex == 1 ? 25 : 15,
                          spreadRadius: _selectedIndex == 1 ? 5 : 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: _selectedIndex == 1 ? 28 : 26,
                        ),
                        // Kırmızı sepet sayısı badge'i
                        if (cartItemCount > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  cartItemCount > 9 ? '9+' : '$cartItemCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
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
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildGlassNavItem(
    IconData icon,
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.successGreen.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? AppColors.successGreen : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.successGreen : Colors.grey[400],
              ),
              child: Text(label),
            ),
          ],
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
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.successGreen.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: AppColors.successGreen.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
