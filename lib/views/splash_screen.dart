import 'package:flutter/material.dart';
import 'widgets/market_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/version_check_service.dart';
import '../viewmodels/banner_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import 'whats_new_screen.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/market_mascot.dart';
import 'widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animation;
  // Maskotun yerinde hafifçe süzülmesi (0 → 1 → 0, sürekli)
  late final AnimationController _float;
  String _version = '';

  // Açılış ekranı en az [_minSplash] görünür; bu sürede ana sayfanın verisi
  // ve ilk görselleri indirilir. İndirme uzarsa en fazla [_maxSplash]
  // beklenir, kalanı ana sayfada yüklenmeye devam eder.
  static const Duration _minSplash = Duration(seconds: 3);
  static const Duration _maxSplash = Duration(seconds: 5);
  // Görseller, ana sayfadaki Image.network çağrılarıyla aynı genişlikte
  // önbelleğe alınır; böylece ana sayfa aynı kaydı bulur ve yeniden indirmez.
  static const int _productImageWidth = 380;
  static const int _bannerImageWidth = 1000;
  static const int _maxPreloadedProductImages = 28;

  final DateTime _startedAt = DateTime.now();
  Future<void>? _preload;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _start();
  }

  /// Ana sayfanın ürün, vitrin ve kategori verisini, ardından ekranda ilk
  /// görünecek görselleri indirir. Hata fırlatmaz; başarısız olursa ana sayfa
  /// her zamanki gibi kendi yüklemesini yapar.
  Future<void> _preloadHome() async {
    try {
      if (!mounted) return;
      final home = context.read<HomePageViewModel>();
      final banners = context.read<BannerViewModel>();
      final categories = context.read<CategoryViewModel>();
      await Future.wait<void>([
        home.loadHomeProducts(),
        banners.loadBanners(),
        categories.loadCategories(),
      ]);
      if (!mounted) return;

      final providers = <ImageProvider>[];
      for (final banner in banners.banners) {
        final url = banner.image.trim();
        if (banner.isActive && url.isNotEmpty) {
          providers.add(ResizeImage(NetworkImage(banner.image),
              width: _bannerImageWidth));
        }
      }
      // Ana sayfadaki sırayla: öne çıkanlar, sana özel, tüm ürünler
      final seen = <String>{};
      final products = [
        ...home.featuredProducts.take(8),
        ...home.personalizedProducts.take(8),
        ...home.products.take(20),
      ];
      for (final product in products) {
        if (seen.length >= _maxPreloadedProductImages) break;
        if (product.isHidden || product.image.isEmpty) continue;
        if (!seen.add(product.image)) continue;
        providers.add(ResizeImage(NetworkImage(product.image),
            width: _productImageWidth));
      }

      await Future.wait<void>([
        for (final provider in providers)
          precacheImage(provider, context, onError: (_, __) {}),
      ]);
    } catch (_) {
      // Ön yükleme isteğe bağlıdır; hata açılışı engellemez
    }
  }

  Future<void> _start() async {
    final package = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = package.version);
    // Sürüm denetimiyle aynı anda ana sayfa verisi de indirilmeye başlar.
    // (İlk kare çizildikten sonra başlatılır; veri sınıfları çizim sırasında
    // dinleyicilerini uyarmamalıdır.)
    _preload = _preloadHome();
    try {
      final result = await VersionCheckService().checkVersion();
      if (!mounted) return;
      if (result == null) {
        await CustomDialog.show(
          context: context,
          title: 'Bağlantı kurulamadı',
          message:
              'Market bilgilerine ulaşamadık. İnternet bağlantınızı kontrol edip yeniden deneyin.',
          confirmButtonText: 'Yeniden dene',
          showCancelButton: false,
          icon: Icons.wifi_off_rounded,
          isDestructive: true,
          onConfirm: () {
            Navigator.pop(context);
            _start();
          },
        );
        return;
      }
      if (result.isUpdateRequired) {
        showUpdateDialog(
          context,
          isMandatory: result.isMandatory,
          storeUrl: result.storeUrl,
          latestVersion: result.latestVersion,
        );
        if (result.isMandatory) return;
      }
      await _navigate();
    } catch (_) {
      if (mounted) await _navigate();
    }
  }

  Future<void> _navigate() async {
    // Ön yükleme bitene kadar (en fazla _maxSplash) beklenir; erken biterse
    // ekran yine de en az _minSplash görünür.
    final maxWait = _maxSplash - DateTime.now().difference(_startedAt);
    if (maxWait > Duration.zero) {
      await Future.any<void>([
        _preload ?? Future<void>.value(),
        Future<void>.delayed(maxWait),
      ]);
    }
    final minWait = _minSplash - DateTime.now().difference(_startedAt);
    if (minWait > Duration.zero) await Future<void>.delayed(minWait);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool('isFirstTime') ?? true) {
      context.go('/onboarding');
      return;
    }
    if (await WhatsNewScreen.shouldShow(_version) && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WhatsNewScreen(
          currentVersion: _version,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ));
    }
    if (mounted) context.go('/home');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa giriş ve süzülme animasyonları atlanır.
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _animation, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final panelIn = _stage(0, .55);
    final mascotIn = _stage(.22, .8, Curves.easeOutBack);
    final mascotFade = _stage(.22, .5, Curves.easeOut);
    final textIn = _stage(.5, 1);

    return Scaffold(
      backgroundColor: MarketPalette.greenDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;
          // Alttaki beyaz panel ekranın yaklaşık %43'ü; maskot panelin üst
          // kenarına basar gibi durur.
          final panelHeight = (height * .43).clamp(300.0, 430.0).toDouble();
          final mascotSize =
              ((height - panelHeight) * .62).clamp(130.0, 250.0).toDouble();
          final mascotBottom = panelHeight - mascotSize * .13;
          final wordmarkHeight = (width * .23).clamp(64.0, 92.0).toDouble();

          return Stack(
            children: [
              const Positioned.fill(child: _SplashBackdrop()),
              // Maskotun arkasındaki yumuşak ışık
              Positioned(
                left: 0,
                right: 0,
                bottom: mascotBottom - mascotSize * .3,
                child: FadeTransition(
                  opacity: mascotFade,
                  child: Center(
                    child: Container(
                      width: mascotSize * 1.7,
                      height: mascotSize * 1.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            MarketPalette.lime.withValues(alpha: .30),
                            MarketPalette.lime.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Beyaz panel: özgün renkleriyle logo, slogan ve yükleme çubuğu
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelHeight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(panelIn),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: MarketPalette.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(44)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 40,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                        child: Column(
                          children: [
                            // Maskotun yere düşen gölgesi
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: FadeTransition(
                                opacity: mascotFade,
                                child: AnimatedBuilder(
                                  animation: _float,
                                  builder: (context, child) => Transform.scale(
                                    scaleX: 1 - Curves.easeInOut.transform(_float.value) * .14,
                                    child: child,
                                  ),
                                  child: Container(
                                    width: mascotSize * .5,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: MarketPalette.greenDeep
                                          .withValues(alpha: .10),
                                      borderRadius: const BorderRadius.all(
                                          Radius.elliptical(80, 12)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(flex: 2),
                            FadeTransition(
                              opacity: textIn,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, .18),
                                  end: Offset.zero,
                                ).animate(textIn),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MarketWordmark(
                                      height: wordmarkHeight,
                                      onLight: true,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'İhtiyacın olan her şey,\nbirkaç dokunuş uzağında.',
                                      textAlign: TextAlign.center,
                                      style: MarketText.body(
                                        color: MarketPalette.muted,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(flex: 3),
                            FadeTransition(
                              opacity: textIn,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 132,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(MarketRadius.pill)),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        color: MarketPalette.green,
                                        backgroundColor: MarketPalette.greenSoft,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _version.isEmpty
                                        ? 'Market hazırlanıyor'
                                        : 'Sürüm $_version',
                                    style: MarketText.caption(
                                      color: MarketPalette.subtle,
                                      size: 12,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Maskot: panelin üst kenarında, hafifçe süzülür
              Positioned(
                left: 0,
                right: 0,
                bottom: mascotBottom,
                child: FadeTransition(
                  opacity: mascotFade,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .6, end: 1).animate(mascotIn),
                    alignment: Alignment.bottomCenter,
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0, -9 * Curves.easeInOut.transform(_float.value)),
                        child: child,
                      ),
                      child: Center(child: MarketMascot(size: mascotSize)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BackdropPainter());
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lime = Paint()
      ..color = MarketPalette.lime.withValues(alpha: .09);
    final green = Paint()
      ..color = MarketPalette.green.withValues(alpha: .25);
    canvas.drawCircle(Offset(size.width * .92, size.height * .06), 150, lime);
    canvas.drawCircle(Offset(size.width * .02, size.height * .34), 170, green);
    canvas.drawCircle(Offset(size.width * .14, size.height * .1), 34, lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
