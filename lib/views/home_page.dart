import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/banner_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'widgets/market_home_widgets.dart';

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

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _safeIndex(widget.initialTabIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.isLoggedIn && auth.user == null) {
        auth.updateProfile();
      }
      context.read<CategoryViewModel>().loadCategories();
      context.read<HomePageViewModel>().loadHomeProducts();
      context.read<BannerViewModel>().loadBanners();

      if (widget.openOrders && mounted) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) context.push('/orders');
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final nextIndex = _safeIndex(widget.initialTabIndex);
      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = nextIndex;
      });
    }
  }

  int _safeIndex(int value) {
    if (value < 0) return 0;
    if (value > 2) return 2;
    return value;
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final movingRight = _selectedIndex > _previousIndex;

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(movingRight ? .035 : -.035, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: switch (_selectedIndex) {
            1 => CartPage(onExplore: () => _selectPage(0)),
            2 => const ProfilePage(),
            _ => const ModernMarketHome(),
          },
        ),
      ),
      bottomNavigationBar: MarketBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: _selectPage,
      ),
    );
  }
}
