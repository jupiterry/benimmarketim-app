import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/banner_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'widgets/market_home_widgets.dart';
import 'widgets/market_tab_stack.dart';

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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: MarketPalette.greenDeep,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: MarketPalette.canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MarketPalette.greenDeep,
        extendBody: true,
        body: MarketTabStack(
          index: _selectedIndex,
          children: [
            const ModernMarketHome(),
            CartPage(onExplore: () => _selectPage(0)),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: MarketBottomNavigation(
          selectedIndex: _selectedIndex,
          onSelected: _selectPage,
        ),
      ),
    );
  }
}
