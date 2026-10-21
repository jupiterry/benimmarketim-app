import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/order_feedback_coordinator.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/banner_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'widgets/market_home_widgets.dart';
import 'widgets/market_tab_stack.dart';
import 'widgets/meta_consent_sheet.dart';

class HomePage extends StatefulWidget {
  final int initialTabIndex;
  final bool openOrders;

  /// Bu sayfayı açan yönlendirme isteği (`/home` rotasının `extra` nesnesi).
  /// Her `context.go('/home', extra: {...})` yeni bir nesne getirir; böylece
  /// aynı sekme numarası art arda istense de (ör. elle Ana Sayfa'ya dönüp
  /// tekrar "Sepete git") istenen sekmeye geçilir.
  final Object? navigationRequest;

  const HomePage({
    super.key,
    this.initialTabIndex = 0,
    this.openOrders = false,
    this.navigationRequest,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  /// Ana sayfa akışının kaydırma denetleyicisi ("Ana Sayfa"ya tekrar
  /// dokununca başa döner).
  final ScrollController _homeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedIndex = _safeIndex(widget.initialTabIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      final currentUser = auth.user;
      if (auth.isLoggedIn &&
          (currentUser == null || currentUser.id.isEmpty)) {
        auth.updateProfile();
      }
      context.read<CategoryViewModel>().loadCategories();
      context.read<HomePageViewModel>().loadHomeProducts();
      context.read<BannerViewModel>().loadBanners();
      // Reklam ölçümü izni (karar verilmediyse bir kez sorulur), ardından
      // sipariş sonrası anket veya mağaza puan penceresi (oturum başına bir
      // kez). Pencereler üst üste açılmasın diye sırayla çalışır; karar
      // verilmişse izin adımı hiç beklemeden geçilir. Anket yalnızca Ana Sayfa
      // sekmesi açıkken gösterilir (sepet / hesap sekmesinin üstüne açılmaz).
      maybeAskMetaConsent(context).whenComplete(() {
        if (mounted) {
          OrderFeedbackCoordinator.run(
            context,
            isVisible: () => mounted && _selectedIndex == 0,
          );
        }
      });

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
    final newRequest =
        !identical(oldWidget.navigationRequest, widget.navigationRequest);
    if (newRequest || oldWidget.initialTabIndex != widget.initialTabIndex) {
      final nextIndex = _safeIndex(widget.initialTabIndex);
      if (nextIndex != _selectedIndex) {
        setState(() {
          _selectedIndex = nextIndex;
        });
      }
    }
    if (newRequest && widget.openOrders) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/orders');
      });
    }
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  int _safeIndex(int value) {
    if (value < 0) return 0;
    if (value > 2) return 2;
    return value;
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      if (index == 0) _scrollHomeToTop();
      return;
    }
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
    });
  }

  void _scrollHomeToTop() {
    if (!_homeScroll.hasClients || _homeScroll.offset <= 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _homeScroll.jumpTo(0);
    } else {
      _homeScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Durum ve gezinme çubuğu renklerini MarketSystemFrame yönetir.
    // Sepet ve Hesabım sekmelerinde Android geri tuşu uygulamayı kapatmak
    // yerine Ana Sayfa'ya döner.
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectPage(0);
      },
      child: Scaffold(
        backgroundColor: MarketPalette.greenDeep,
        extendBody: true,
        body: MarketTabStack(
          index: _selectedIndex,
          children: [
            ModernMarketHome(controller: _homeScroll),
            CartPage(onExplore: () => _selectPage(0)),
            const ProfilePage(),
          ],
        ),
        // Asistan, ana sayfadaki arama bandında ("Asistan" düğmesi) durur;
        // yüzen düğme ürünlerin "+" düğmelerini örtüyordu.
        bottomNavigationBar: MarketBottomNavigation(
          selectedIndex: _selectedIndex,
          onSelected: _selectPage,
        ),
      ),
    );
  }
}
