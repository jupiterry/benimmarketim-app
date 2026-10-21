import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/flash_sale.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../viewmodels/flash_sale_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/category_presentation.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/flash_sale_widgets.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_system_frame.dart';
import 'widgets/market_ui.dart';
import 'widgets/product_image_viewer.dart';
import '../services/image_url.dart';

const int _maxQuantity = 99;

/// Vitrinin alt kenarına binen panel payı (panelin yuvarlak köşesi + 4).
const double _sheetOverlap = MarketRadius.xl + 4;

/// Üst düğme satırının yüksekliği (8 + 48 + 8). Panel en fazla bunun altına
/// kadar çıkar; böylece geri ve favori düğmeleri hiç kapanmaz.
const double _topBarHeight = 8 + MarketSize.tapTarget + 8;

/// Ürün detayı.
///
/// Üstte beyaz bir "vitrin" (ürün görseli, rozet), üzerine yukarı
/// çekilebilen beyaz bir bilgi paneli: ad, fiyat, teslimat
/// bilgileri, açıklama ve benzer ürünler. Altta sabit sepet çubuğu: ürün
/// sepette yoksa adet + "Sepete ekle", sepetteyse sepetteki adet + "Sepete git".
class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Product _product = widget.product;
  int _quantity = 1;
  bool _descriptionExpanded = false;
  List<Product> _similarProducts = [];
  bool _isLoadingSimilar = true;

  /// Sunucu ürünü artık tanımıyor (404) ya da gizlenmiş: satışta değil.
  bool _unavailable = false;

  /// "Sepete ekle"den hemen sonra çubukta kısa bir "Sepete eklendi" onayı.
  bool _justAdded = false;
  Timer? _justAddedTimer;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Panel en üste çekildi mi (üstte ürün adlı beyaz çubuk görünür).
  final ValueNotifier<bool> _expanded = ValueNotifier<bool>(false);
  bool? _pendingExpanded;
  double _maxExtent = 1;
  final GlobalKey _similarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetMoved);
    _refreshProduct();
    _loadSimilarProducts();
  }

  @override
  void dispose() {
    _justAddedTimer?.cancel();
    _sheetController
      ..removeListener(_onSheetMoved)
      ..dispose();
    _expanded.dispose();
    super.dispose();
  }

  /// Listedeki ürün bilgisi eski olabilir (flash sale başlamış/bitmiş, stok
  /// değişmiş, ürün kaldırılmış). Sayfa açılınca güncel hali sunucudan alınır.
  Future<void> _refreshProduct() async {
    try {
      final fresh = await ApiService().getProductById(widget.product.id);
      if (!mounted || fresh.id != widget.product.id) return;
      setState(() {
        _product = fresh;
        _unavailable = fresh.isHidden;
      });
    } on ApiException catch (error) {
      AppLogger.debug('Ürün güncellenemedi: $error');
      if (mounted && error.statusCode == 404) {
        setState(() => _unavailable = true);
      }
    } catch (error) {
      AppLogger.debug('Ürün güncellenemedi: $error');
    }
  }

  Future<void> _loadSimilarProducts() async {
    try {
      final products = await ApiService().getSimilarProducts(widget.product.id);
      if (!mounted) return;
      final similar = products
          .where((p) => p.id != widget.product.id && !p.isHidden)
          .take(10)
          .toList();
      if (similar.isEmpty) {
        _loadSimilarProductsFallback();
      } else {
        setState(() => _similarProducts = similar);
      }
    } catch (error) {
      AppLogger.debug('Benzer ürünler yüklenirken hata: $error');
      if (mounted) _loadSimilarProductsFallback();
    } finally {
      if (mounted) setState(() => _isLoadingSimilar = false);
    }
  }

  void _loadSimilarProductsFallback() {
    final similar = context
        .read<HomePageViewModel>()
        .products
        .where((p) =>
            p.category == widget.product.category &&
            p.id != widget.product.id &&
            !p.isHidden)
        .take(10)
        .toList();
    setState(() => _similarProducts = similar);
  }

  // --- Panel konumu ---------------------------------------------------------

  void _onSheetMoved() {
    if (!_sheetController.isAttached) return;
    _setExpanded(_sheetController.size >= _maxExtent - .04);
  }

  /// Panel bir yerleşim sırasında da haber verebilir; o anda dinleyenleri
  /// yeniden çizdirmek hata verir, değer karenin sonunda uygulanır.
  void _setExpanded(bool value) {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _expanded.value = value;
      return;
    }
    final scheduled = _pendingExpanded != null;
    _pendingExpanded = value;
    if (scheduled) return;
    binding.addPostFrameCallback((_) {
      final pending = _pendingExpanded;
      _pendingExpanded = null;
      if (mounted && pending != null) _expanded.value = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flash = context.watch<FlashSaleViewModel>();
    final product = flash.latest(_product);
    final sale = flash.saleFor(product.id);
    final cartQuantity = context.select<CartViewModel, int>(
      (cart) => cart.getProductQuantity(product.id),
    );
    final hasSimilar = !_isLoadingSimilar && _similarProducts.isNotEmpty;

    // Vitrin beyaz olduğu için durum çubuğu şeridi de beyaz (koyu simgeler).
    return MarketStatusBand(
      color: MarketPalette.surface,
      child: Scaffold(
        backgroundColor: MarketPalette.surface,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // Küçük telefonda vitrin kısalır: fiyat ilk bakışta görünür.
            final compact = height < 600;
            final showcaseHeight = (height * (compact ? .38 : .44))
                .clamp(compact ? 190.0 : 260.0, 440.0)
                .toDouble();
            // Panel vitrinin alt kenarına biner; ilk konumda görsel tam görünür.
            final initial = ((height - showcaseHeight + _sheetOverlap) / height)
                .clamp(.42, .9)
                .toDouble();
            _maxExtent = math.max(initial, 1 - _topBarHeight / height);

            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: showcaseHeight,
                  child: _Showcase(
                    product: product,
                    sale: sale,
                    unavailable: _unavailable,
                    compact: compact,
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: initial,
                  minChildSize: initial,
                  maxChildSize: _maxExtent,
                  snap: true,
                  builder: (context, controller) => _InfoPanel(
                    controller: controller,
                    product: product,
                    sale: sale,
                    unavailable: _unavailable,
                    cartQuantity: cartQuantity,
                    onRemoveFromCart: () => _removeFromCart(product),
                    compact: compact,
                    descriptionExpanded: _descriptionExpanded,
                    onToggleDescription: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    similarProducts: _similarProducts,
                    isLoadingSimilar: _isLoadingSimilar,
                    similarKey: _similarKey,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(
                    expanded: _expanded,
                    title: productDisplayName(product.name),
                    onBack: _goBack,
                    onShare: () => _share(product),
                    favoriteButton: _FavoriteButton(product: product),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _PurchaseDock(
          product: product,
          quantity: _quantity,
          cartQuantity: cartQuantity,
          unavailable: _unavailable,
          justAdded: _justAdded,
          hasSimilar: hasSimilar,
          onMinus: () {
            if (_quantity > 1) setState(() => _quantity--);
          },
          onPlus: () {
            if (_quantity < _maxQuantity) setState(() => _quantity++);
          },
          onAdd: () => _addToCart(product),
          onCartMinus: () => _changeCartQuantity(product, -1),
          onCartPlus: () => _changeCartQuantity(product, 1),
          onGoToCart: _goToCart,
          onSeeSimilar: _showSimilar,
        ),
      ),
    );
  }

  void _goBack() {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (router != null) {
      router.go('/home');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goToCart() {
    context.go('/home', extra: <String, dynamic>{'initialTabIndex': 1});
  }

  void _addToCart(Product product) {
    HapticFeedback.selectionClick();
    final quantity = _quantity;
    // Tek yazma, tek ölçüm olayı: adet tek seferde eklenir.
    context.read<CartViewModel>().addQuantity(product, quantity);
    // Görünen onay çubuğun kendisi ("Sepete eklendi" → "Sepete git");
    // ekran okuyucuya ayrıca duyurulur.
    SemanticsService.sendAnnouncement(
      View.of(context),
      '$quantity adet ${productDisplayName(product.name)} sepete eklendi',
      TextDirection.ltr,
    );
    _justAddedTimer?.cancel();
    setState(() {
      _quantity = 1;
      _justAdded = true;
    });
    _justAddedTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _justAdded = false);
    });
  }

  /// Sepetteki adedi ürün kartındaki seçiciyle aynı çağrılarla değiştirir.
  void _changeCartQuantity(Product product, int delta) {
    HapticFeedback.selectionClick();
    final cart = context.read<CartViewModel>();
    if (delta > 0) {
      if (cart.getProductQuantity(product.id) < _maxQuantity) {
        cart.addToCart(product);
      }
    } else {
      cart.removeFromCart(product);
    }
    if (_justAdded) {
      _justAddedTimer?.cancel();
      setState(() => _justAdded = false);
    }
  }

  void _removeFromCart(Product product) {
    HapticFeedback.selectionClick();
    context.read<CartViewModel>().updateQuantity(product, 0);
    showMarketSnack(
      context,
      'Ürün sepetinden çıkarıldı',
      icon: Icons.remove_shopping_cart_outlined,
    );
  }

  /// Paneli en üste çeker ve benzer ürünler rafına kaydırır.
  Future<void> _showSimilar() async {
    HapticFeedback.selectionClick();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_sheetController.isAttached) {
      if (reduceMotion) {
        _sheetController.jumpTo(_maxExtent);
      } else {
        await _sheetController.animateTo(
          _maxExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
    final target = _similarKey.currentContext;
    if (!mounted || target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _share(Product product) {
    HapticFeedback.lightImpact();
    Share.share(
      '${product.name} – ${formatTl(product.actualPrice)}\n'
      "Benim Marketim'de gördüm, yurda kadar getiriyorlar 🛵\n"
      'https://devrekbenimmarketim.com',
    );
  }
}

/// Kategori adına göre yüklü kategori listesindeki kaydı bulur (yoksa null).
Category? _resolveCategory(BuildContext context, String categoryName) {
  final key = normalizedCategoryKey(categoryName);
  for (final c in context.watch<CategoryViewModel>().categories) {
    if (normalizedCategoryKey(c.name) == key) return c;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Üst çubuk: geri, paylaş, favori (panel en üstteyken arkasında beyaz zemin)
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final ValueListenable<bool> expanded;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final Widget favoriteButton;

  const _TopBar({
    required this.expanded,
    required this.title,
    required this.onBack,
    required this.onShare,
    required this.favoriteButton,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: _topBarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, on, _) => IgnorePointer(
                ignoring: !on,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: MarketPalette.surface,
                      border: Border(
                        bottom: BorderSide(color: MarketPalette.line),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: gutter + MarketSize.tapTarget + MarketSpace.md,
                        right: gutter +
                            MarketSize.tapTarget * 2 +
                            MarketSpace.sm +
                            MarketSpace.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // Panelde aynı ad zaten başlık olarak okunuyor.
                        child: ExcludeSemantics(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.heading(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 8),
            child: Row(
              children: [
                _RoundButton(
                  tooltip: 'Geri dön',
                  onTap: onBack,
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: MarketPalette.ink,
                    size: 22,
                  ),
                ),
                const Spacer(),
                _RoundButton(
                  tooltip: 'Paylaş',
                  onTap: onShare,
                  child: const Icon(
                    Icons.ios_share_rounded,
                    color: MarketPalette.ink,
                    size: 21,
                  ),
                ),
                const SizedBox(width: MarketSpace.sm),
                favoriteButton,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Açık zemin üstünde beyaz, hafif gölgeli yuvarlak düğme (48 pt).
class _RoundButton extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;
  final bool? toggled;

  const _RoundButton({
    required this.child,
    required this.tooltip,
    required this.onTap,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: toggled,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep.withValues(alpha: .08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: MarketPalette.surface,
            shape: const CircleBorder(
              side: BorderSide(color: MarketPalette.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: MarketSize.tapTarget,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Favori kalbi: eklenince hafifçe büyüyüp küçülür (hareket azaltılmışsa
/// durur). Misafire giriş yapmasını öneren pencere açar.
class _FavoriteButton extends StatefulWidget {
  final Product product;

  const _FavoriteButton({required this.product});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.18), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1), weight: 1),
  ]).animate(CurvedAnimation(parent: _bump, curve: Curves.easeOut));
  bool _busy = false;

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final favorites = context.read<FavoritesViewModel>();
    if (!context.read<AuthViewModel>().isLoggedIn) {
      final login = await showMarketConfirm(
        context,
        icon: Icons.favorite_rounded,
        title: 'Favorilerini sakla',
        message: 'Favorilere ürün eklemek için hesabına giriş yapmalısın.',
        confirmLabel: 'Giriş yap',
        cancelLabel: 'Şimdi değil',
        tone: MarketTone.favorite,
      );
      if (login && mounted) context.push('/login');
      return;
    }
    HapticFeedback.lightImpact();
    final willBeFavorite = !favorites.isFavorite(widget.product.id);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _busy = true;
    try {
      await favorites.toggleFavorite(widget.product);
    } catch (error) {
      AppLogger.debug('Favori güncellenemedi: $error');
      return;
    } finally {
      _busy = false;
    }
    if (mounted && willBeFavorite && !reduceMotion) _bump.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesViewModel, bool>(
      (favorites) => favorites.isFavorite(widget.product.id),
    );
    return _RoundButton(
      tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
      toggled: isFavorite,
      onTap: _toggle,
      child: ScaleTransition(
        scale: _scale,
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? MarketPalette.pink : MarketPalette.ink,
          size: 22,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vitrin: beyaz "stüdyo" zemin ve ürün görseli
// ---------------------------------------------------------------------------

/// Ürün görselinin sahnesi. Katalog fotoğraflarının çoğu beyaz zeminli olduğu
/// için vitrin de düz beyazdır: fotoğrafın kenarı hiç görünmez, saydam
/// görseller de aynı sahnede durur. Görsele dokununca tam ekranda açılır
/// (yakınlaştırılabilir).
class _Showcase extends StatelessWidget {
  final Product product;
  final FlashSale? sale;
  final bool unavailable;
  final bool compact;

  const _Showcase({
    required this.product,
    required this.sale,
    required this.unavailable,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final discount =
        product.isDiscounted ? product.discountPercentage.round() : 0;
    final soldOut = unavailable || product.isOutOfStock;
    final canZoom = product.image.trim().isNotEmpty;
    final top = compact ? MarketSpace.sm : MarketSpace.md;
    final bottom = _sheetOverlap + (compact ? MarketSpace.md : MarketSpace.lg);

    Widget stage = Padding(
      padding: EdgeInsets.fromLTRB(gutter, top, gutter, bottom),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: _ProductImage(product: product, dimmed: soldOut),
          ),
          if (soldOut)
            Align(
              alignment: Alignment.bottomCenter,
              child: _SoldOutPill(
                label: unavailable ? 'Satışta değil' : 'Stokta yok',
              ),
            ),
        ],
      ),
    );
    if (canZoom) {
      stage = Semantics(
        button: true,
        label: 'Ürün görselini büyüt',
        excludeSemantics: true,
        onTap: () => showProductImageViewer(context, product),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showProductImageViewer(context, product),
          child: stage,
        ),
      );
    } else {
      stage = ExcludeSemantics(child: stage);
    }

    return ColoredBox(
      color: MarketPalette.surface,
      child: Stack(
        children: [
          Positioned.fill(child: stage),
          // Ürün kartındaki gibi sol üstte (geri düğmesinin altında) rozet
          if (!soldOut && (sale != null || discount > 0))
            Positioned(
              left: gutter,
              top: _topBarHeight + MarketSpace.xs,
              child: ExcludeSemantics(
                child: sale != null
                    ? FlashBadge(
                        discountPercentage: discount > 0
                            ? discount.toDouble()
                            : sale!.discountPercentage,
                      )
                    : _DiscountStamp(percent: discount),
              ),
            ),
          if (canZoom)
            Positioned(
              right: gutter,
              bottom: bottom - MarketSpace.xs,
              child: const IgnorePointer(child: _ZoomHint()),
            ),
        ],
      ),
    );
  }
}

class _ZoomHint extends StatelessWidget {
  const _ZoomHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        shape: BoxShape.circle,
        border: Border.all(color: MarketPalette.line),
      ),
      child: const Icon(
        Icons.zoom_in_rounded,
        color: MarketPalette.muted,
        size: 18,
      ),
    );
  }
}

class _SoldOutPill extends StatelessWidget {
  final String label;

  const _SoldOutPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MarketPalette.ink,
        borderRadius: BorderRadius.circular(MarketRadius.pill),
      ),
      child: Text(
        label,
        style: MarketText.label(color: Colors.white, size: 13),
      ),
    );
  }
}

/// Doygunluğu [s] oranına indiren renk matrisi (0: gri, 1: özgün).
List<double> _saturationMatrix(double s) {
  const r = .2126, g = .7152, b = .0722;
  final i = 1 - s;
  return [
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

class _ProductImage extends StatelessWidget {
  final Product product;

  /// Stokta yok / satışta değil: görsel soluk ve renksizleşir.
  final bool dimmed;

  const _ProductImage({required this.product, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    if (product.image.trim().isEmpty) return const _LargeImageFallback();
    Widget image = Image.network(
      optimizedImageUrl(product.image, width: MarketImageSize.detail),
      fit: BoxFit.contain,
      cacheWidth: 850,
      excludeFromSemantics: true,
      // Büyük görsel gelene kadar kartta zaten yüklü küçük görsel; o da
      // yoksa iskelet.
      frameBuilder: (context, child, frame, sync) => frame != null || sync
          ? child
          : Image.network(
              optimizedImageUrl(product.image, width: MarketImageSize.card),
              fit: BoxFit.contain,
              cacheWidth: 380,
              excludeFromSemantics: true,
              frameBuilder: (context, small, smallFrame, smallSync) =>
                  smallFrame != null || smallSync
                      ? small
                      : const _ImageSkeleton(),
              errorBuilder: (_, __, ___) => const _ImageSkeleton(),
            ),
      errorBuilder: (_, __, ___) => const _LargeImageFallback(),
    );
    if (dimmed) {
      image = Opacity(
        opacity: .7,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturationMatrix(.4)),
          child: image,
        ),
      );
    }
    return Hero(tag: 'product_image_${product.id}', child: image);
  }
}

class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return const MarketSkeletonPulse(
      semanticLabel: 'Görsel yükleniyor',
      child: Center(
        child: FractionallySizedBox(
          widthFactor: .6,
          heightFactor: .6,
          child: MarketSkeleton(height: double.infinity, radius: MarketRadius.lg),
        ),
      ),
    );
  }
}

class _DiscountStamp extends StatelessWidget {
  final int percent;

  const _DiscountStamp({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MarketPalette.red,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
      ),
      child: Text(
        '%$percent indirim',
        style: MarketText.label(
          color: Colors.white,
          size: 12,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bilgi paneli (yukarı çekilebilen beyaz alt sayfa)
// ---------------------------------------------------------------------------

class _InfoPanel extends StatelessWidget {
  final ScrollController controller;
  final Product product;
  final FlashSale? sale;
  final bool unavailable;
  final int cartQuantity;
  final VoidCallback onRemoveFromCart;
  final bool compact;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;
  final List<Product> similarProducts;
  final bool isLoadingSimilar;
  final GlobalKey similarKey;

  const _InfoPanel({
    required this.controller,
    required this.product,
    required this.sale,
    required this.unavailable,
    required this.cartQuantity,
    required this.onRemoveFromCart,
    required this.compact,
    required this.descriptionExpanded,
    required this.onToggleDescription,
    required this.similarProducts,
    required this.isLoadingSimilar,
    required this.similarKey,
  });

  @override
  Widget build(BuildContext context) {
    final description = product.description.trim();
    final gutter = MarketSpace.gutterOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final displayName = productDisplayName(product.name);
    final titleSize = width < 360 || product.name.length > 42 ? 21.0 : 24.0;
    final soldOut = unavailable || product.isOutOfStock;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MarketRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Material(
        color: MarketPalette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MarketRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomScrollView(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MarketSheetHandle(margin: EdgeInsets.only(top: 10)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      compact ? MarketSpace.sm : MarketSpace.md,
                      gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _CategoryLink(
                                  categoryName: product.category,
                                ),
                              ),
                            ),
                            const SizedBox(width: MarketSpace.sm),
                            _StockChip(
                              outOfStock: product.isOutOfStock,
                              unavailable: unavailable,
                            ),
                          ],
                        ),
                        const SizedBox(height: MarketSpace.xs),
                        Semantics(
                          header: true,
                          child: Text(
                            displayName,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.title(size: titleSize),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : MarketSpace.md),
                        _PriceRow(product: product, flash: sale != null),
                        // Stokta olmayan ürün sepette kaldıysa: fiyatın hemen
                        // altında, tek dokunuşla çıkarılabilir.
                        if (soldOut && cartQuantity > 0) ...[
                          const SizedBox(height: MarketSpace.lg),
                          MarketNotice.warning(
                            icon: Icons.info_outline_rounded,
                            text: 'Sepetinde $cartQuantity adet var ama şu an '
                                '${unavailable ? 'satışta değil' : 'stokta yok'}.',
                            trailing: TextButton(
                              onPressed: onRemoveFromCart,
                              style: TextButton.styleFrom(
                                foregroundColor: MarketPalette.orangeInk,
                                textStyle: MarketText.label(size: 13),
                                minimumSize: const Size(
                                  MarketSize.control,
                                  MarketSize.control,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text('Çıkar'),
                            ),
                          ),
                        ],
                        if (sale != null) ...[
                          const SizedBox(height: MarketSpace.xl),
                          FlashSaleBanner(sale: sale!),
                        ],
                        const SizedBox(height: MarketSpace.xl),
                        const _DeliveryInfoCard(),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: MarketSpace.xxl),
                          _Description(
                            description: description,
                            expanded: descriptionExpanded,
                            onToggle: onToggleDescription,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoadingSimilar || similarProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: MarketSpace.xxl),
                  child: _SimilarProducts(
                    key: similarKey,
                    categoryName: product.category,
                    products: similarProducts,
                    loading: isLoadingSimilar,
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: MarketSpace.section),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kategori adı, yumuşak yeşil bir hap içinde: dokununca o kategorinin
/// sayfası açılır (kategori listesi yüklüyse). Dokunma alanı 44 pt.
class _CategoryLink extends StatelessWidget {
  final String categoryName;

  const _CategoryLink({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final category = _resolveCategory(context, categoryName);
    final name = categoryDisplayName(categoryName);
    final pill = Container(
      padding: EdgeInsets.fromLTRB(10, 6, category == null ? 12 : 6, 6),
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(categoryEmoji(categoryName), style: MarketText.emoji(14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MarketText.label(color: MarketPalette.greenDark, size: 13),
            ),
          ),
          if (category != null) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              color: MarketPalette.greenDark,
              size: 16,
            ),
          ],
        ],
      ),
    );

    if (category == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MarketSize.control),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: pill,
        ),
      );
    }
    final target = category;
    return Semantics(
      button: true,
      label: '$name kategorisine git',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/category', extra: target),
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MarketSize.control),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: pill,
          ),
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  final bool outOfStock;
  final bool unavailable;

  const _StockChip({required this.outOfStock, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final bad = outOfStock || unavailable;
    final color = bad ? MarketPalette.red : MarketPalette.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: bad ? MarketPalette.redSoft : MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            unavailable
                ? 'Satışta değil'
                : outOfStock
                    ? 'Stokta yok'
                    : 'Stokta var',
            style: MarketText.label(
              color: bad ? MarketPalette.red : MarketPalette.greenDark,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Büyük fiyat; indirimde eski fiyat üstü çizili ve lime kazanç hapı.
/// Flash sale'de üstte kırmızı "Flash Sale fiyatı" satırı.
class _PriceRow extends StatelessWidget {
  final Product product;
  final bool flash;

  const _PriceRow({required this.product, required this.flash});

  @override
  Widget build(BuildContext context) {
    final hasSavings = product.price > product.actualPrice;
    final saving = product.price - product.actualPrice;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: hasSavings
          ? '${flash ? 'Flash Sale fiyatı ' : ''}${formatTl(product.actualPrice)}, '
              'normal fiyat ${formatTl(product.price)}, '
              '${formatTlShort(saving)} kazanç'
          : 'Fiyat ${formatTl(product.actualPrice)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flash) ...[
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: MarketPalette.red,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  'Flash Sale fiyatı',
                  style: MarketText.label(color: MarketPalette.red, size: 12),
                ),
              ],
            ),
            const SizedBox(height: MarketSpace.xs),
          ],
          Wrap(
            spacing: MarketSpace.md,
            runSpacing: MarketSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Güncel fiyat değişirse (ör. sayfa açıkken yenilendi)
                  // yeni değer yumuşakça belirir.
                  AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: Text(
                      formatTl(product.actualPrice),
                      key: ValueKey(product.actualPrice),
                      style: MarketText.price(
                        color:
                            flash ? MarketPalette.red : MarketPalette.greenDeep,
                        size: 32,
                      ),
                    ),
                  ),
                  if (hasSavings) ...[
                    const SizedBox(width: 10),
                    Text(
                      formatTl(product.price),
                      style: MarketText.oldPrice(size: 15),
                    ),
                  ],
                ],
              ),
              if (hasSavings)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: MarketPalette.lime,
                    borderRadius: BorderRadius.circular(MarketRadius.pill),
                  ),
                  child: Text(
                    '${formatTlShort(saving)} kazanç',
                    style: MarketText.label(
                      color: MarketPalette.greenDeep,
                      size: 12,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sipariş için işe yarar bilgiler tek kutuda, alt alta: minimum sepet
/// tutarı, teslimat noktaları ve sipariş saatleri. Yana kaymaz; dar ekranda
/// ve büyük yazıda satırlar kırılır.
class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard();

  static String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final cartTotal = context.select<CartViewModel, double>((c) => c.totalPrice);
    final minimum = settings.minimumOrderAmount;
    final remaining = math.max(0.0, minimum - cartTotal);
    final points = [
      if (settings.girlsDormEnabled) settings.girlsDormName,
      if (settings.boysDormEnabled) settings.boysDormName,
    ];
    final open = settings.isWithinOrderHours;
    final allDay = settings.orderStartHour == 0 &&
        settings.orderStartMinute == 0 &&
        settings.orderEndHour == 0 &&
        settings.orderEndMinute == 0;
    final hours = allDay
        ? '7/24'
        : '${_clock(settings.orderStartHour, settings.orderStartMinute)}–'
            '${_clock(settings.orderEndHour, settings.orderEndMinute)}';

    final rows = <Widget>[
      if (minimum > 0)
        remaining == 0
            ? const _InfoRow(
                icon: Icons.check_circle_rounded,
                iconColor: MarketPalette.green,
                title: 'Minimum sepet tutarını geçtin',
                titleColor: MarketPalette.greenDark,
              )
            : _InfoRow(
                icon: Icons.shopping_basket_outlined,
                title: cartTotal <= 0
                    ? 'Minimum sepet tutarı ${formatTlShort(minimum)}'
                    : 'Minimum sepet tutarına ${formatTlShort(remaining)} kaldı',
                footer: cartTotal <= 0
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(MarketRadius.pill),
                        child: LinearProgressIndicator(
                          value: (cartTotal / minimum).clamp(0.0, 1.0),
                          minHeight: 4,
                          color: MarketPalette.green,
                          backgroundColor: MarketPalette.line,
                        ),
                      ),
              ),
      points.isEmpty
          ? const _InfoRow(
              icon: Icons.location_off_outlined,
              iconColor: MarketPalette.orangeInk,
              title: 'Şu an teslimat yapılmıyor',
              titleColor: MarketPalette.orangeInk,
            )
          : _InfoRow(
              icon: Icons.location_on_outlined,
              title: 'Yurduna teslim',
              detail: points.join(' · '),
            ),
      open
          ? _InfoRow(
              icon: Icons.schedule_rounded,
              iconColor: MarketPalette.green,
              title: allDay ? 'Sipariş açık · 7/24' : 'Sipariş açık · $hours',
            )
          : _InfoRow(
              icon: Icons.bedtime_outlined,
              iconColor: MarketPalette.orangeInk,
              title: 'Şu an sipariş alınmıyor',
              titleColor: MarketPalette.orangeInk,
              detail: 'Sipariş saatleri $hours. Sepetine ekleyip açılınca '
                  'sipariş verebilirsin.',
            ),
    ];

    return MarketCard(
      shadow: false,
      color: MarketPalette.surfaceMuted,
      borderColor: MarketPalette.line,
      radius: MarketRadius.md,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: MarketSpace.md),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String? detail;
  final Widget? footer;

  const _InfoRow({
    required this.icon,
    this.iconColor = MarketPalette.muted,
    required this.title,
    this.titleColor = MarketPalette.ink,
    this.detail,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MarketText.body(
                    color: titleColor,
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: MarketText.caption(size: 12)),
                ],
                if (footer != null) ...[
                  const SizedBox(height: MarketSpace.sm),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ürün açıklaması. Dört satırı aşıyorsa (gerçek yerleşime göre ölçülür)
/// kısaltılır, son satır soluklaşır ve "Devamını oku" çıkar. "İçindekiler:"
/// gibi etiketle başlayan paragrafların etiketi kalın yazılır.
class _Description extends StatelessWidget {
  final String description;
  final bool expanded;
  final VoidCallback onToggle;

  const _Description({
    required this.description,
    required this.expanded,
    required this.onToggle,
  });

  static const int _collapsedLines = 4;
  static final RegExp _labelPattern = RegExp(r'^([^:\n]{2,28}):\s');

  TextSpan _buildSpan() {
    final body = MarketText.body(color: MarketPalette.inkSoft, height: 1.55);
    final label = body.copyWith(
      color: MarketPalette.ink,
      fontWeight: FontWeight.w700,
    );
    final paragraphs = description
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final children = <InlineSpan>[];
    for (var i = 0; i < paragraphs.length; i++) {
      // Paragraf arası: küçük punto boş satır (~10 pt).
      if (i > 0) {
        children.add(
          const TextSpan(text: '\n\n', style: TextStyle(fontSize: 10, height: 1)),
        );
      }
      final paragraph = paragraphs[i];
      final match = _labelPattern.firstMatch(paragraph);
      if (match != null) {
        children
          ..add(TextSpan(text: '${match.group(1)}: ', style: label))
          ..add(TextSpan(text: paragraph.substring(match.end)));
      } else {
        children.add(TextSpan(text: paragraph));
      }
    }
    return TextSpan(style: body, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final span = _buildSpan();
    final scaler = MediaQuery.textScalerOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Ürün hakkında', style: MarketText.heading(size: 18)),
        ),
        const SizedBox(height: MarketSpace.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: span,
              maxLines: _collapsedLines,
              textDirection: TextDirection.ltr,
              textScaler: scaler,
            )..layout(maxWidth: constraints.maxWidth);
            final long = painter.didExceedMaxLines;
            painter.dispose();
            final collapsed = long && !expanded;

            Widget text = Text.rich(
              span,
              maxLines: collapsed ? _collapsedLines : null,
              overflow: collapsed ? TextOverflow.clip : TextOverflow.visible,
            );
            if (collapsed) {
              // Kesilen metnin son satırı soluklaşır: devamı olduğu belli olur.
              text = ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Colors.white, Colors.white, Colors.transparent],
                  stops: [
                    0,
                    rect.height <= 28 ? 0 : (rect.height - 28) / rect.height,
                    1,
                  ],
                ).createShader(rect),
                child: text,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: text,
                ),
                if (long)
                  TextButton.icon(
                    onPressed: onToggle,
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(expanded ? 'Daha az göster' : 'Devamını oku'),
                    style: TextButton.styleFrom(
                      foregroundColor: MarketPalette.greenDark,
                      textStyle: MarketText.label(size: 14),
                      minimumSize: const Size(0, MarketSize.control),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Benzer ürünler rafı. Kartlar 156 pt: yanda bir sonraki kart görünür ve
/// rafın kaydırılabildiği anlaşılır.
class _SimilarProducts extends StatelessWidget {
  final String categoryName;
  final List<Product> products;
  final bool loading;

  const _SimilarProducts({
    super.key,
    required this.categoryName,
    required this.products,
    required this.loading,
  });

  static const double _cardWidth = 156;

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final category = _resolveCategory(context, categoryName);
    final height = marketProductCardExtent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: MarketSectionTitle(
            dense: true,
            title: 'Bunlara da göz at',
            subtitle: 'Bu ürüne benzer seçenekler',
            actionLabel: category == null ? null : 'Tümünü gör',
            onAction: category == null
                ? null
                : () => context.push('/category', extra: category),
          ),
        ),
        const SizedBox(height: MarketSpace.md),
        if (loading)
          _SimilarProductsSkeleton(height: height, gutter: gutter)
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: MarketSpace.md),
              itemBuilder: (context, index) => SizedBox(
                width: _cardWidth,
                child: MarketProductCard(product: products[index], hero: false),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sepet çubuğu
// ---------------------------------------------------------------------------

/// Alt çubuğun üç hali:
/// * sepette yok: adet seçici + "Sepete ekle · ₺toplam",
/// * sepette var: sepetteki adedi değiştiren seçici + "Sepete git",
/// * stokta yok / satışta değil: açıklama + "Benzerlerini gör".
class _PurchaseDock extends StatelessWidget {
  final Product product;
  final int quantity;
  final int cartQuantity;
  final bool unavailable;
  final bool justAdded;
  final bool hasSimilar;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onAdd;
  final VoidCallback onCartMinus;
  final VoidCallback onCartPlus;
  final VoidCallback onGoToCart;
  final VoidCallback onSeeSimilar;

  const _PurchaseDock({
    required this.product,
    required this.quantity,
    required this.cartQuantity,
    required this.unavailable,
    required this.justAdded,
    required this.hasSimilar,
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
    required this.onCartMinus,
    required this.onCartPlus,
    required this.onGoToCart,
    required this.onSeeSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final soldOut = unavailable || product.isOutOfStock;

    final Widget content;
    if (soldOut) {
      content = _SoldOutBar(
        key: const ValueKey('sold-out'),
        unavailable: unavailable,
        hasSimilar: hasSimilar,
        onSeeSimilar: onSeeSimilar,
      );
    } else if (cartQuantity > 0) {
      content = Row(
        key: const ValueKey('in-cart'),
        children: [
          MarketStepper(
            quantity: cartQuantity,
            large: true,
            minusIcon: cartQuantity == 1 ? Icons.delete_outline_rounded : null,
            onMinus: onCartMinus,
            onPlus: onCartPlus,
            canIncrement: cartQuantity < _maxQuantity,
            semanticLabel: 'Sepetteki adet',
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: _GoToCartButton(
              quantity: cartQuantity,
              justAdded: justAdded,
              onTap: onGoToCart,
            ),
          ),
        ],
      );
    } else {
      content = Row(
        key: const ValueKey('add'),
        children: [
          MarketStepper(
            quantity: quantity,
            large: true,
            onMinus: onMinus,
            onPlus: onPlus,
            canDecrement: quantity > 1,
            canIncrement: quantity < _maxQuantity,
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: _AddToCartButton(
              quantity: quantity,
              total: product.actualPrice * quantity,
              onTap: onAdd,
            ),
          ),
        ],
      );
    }

    return MarketBottomBar(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
      child: AnimatedSwitcher(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: content,
      ),
    );
  }
}

/// "Sepete ekle" düğmesi. Etiket hiçbir zaman "Sep…" diye kesilmez: yer
/// darsa önce simge düşer, sonra etiket ve tutar alt alta dizilir.
class _AddToCartButton extends StatelessWidget {
  final int quantity;
  final double total;
  final VoidCallback onTap;

  const _AddToCartButton({
    required this.quantity,
    required this.total,
    required this.onTap,
  });

  static const String _label = 'Sepete ekle';
  static const double _padding = 16;
  static const double _iconSpace = 20 + 8;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final price = formatTl(total);
    final labelStyle = MarketText.label(
      color: Colors.white,
      size: 15,
      weight: FontWeight.w800,
    );
    final priceStyle = MarketText.price(color: Colors.white, size: 16);
    final radius = BorderRadius.circular(MarketRadius.md);

    return Semantics(
      button: true,
      label: '$quantity adet sepete ekle, toplam $price',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: MarketPalette.green,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: MarketSize.button,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scaler = MediaQuery.textScalerOf(context);
                final labelWidth = _measure(_label, labelStyle, scaler);
                final priceWidth = _measure(price, priceStyle, scaler);
                final inline = 2 * _padding + labelWidth + _gap + priceWidth;
                final max = constraints.maxWidth;

                if (inline > max) {
                  // Dar: etiket üstte, tutar altta.
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_label, style: labelStyle.copyWith(fontSize: 14)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            price,
                            style: MarketText.price(
                              color: Colors.white.withValues(alpha: .86),
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final showIcon = inline + _iconSpace <= max;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _padding),
                  child: Row(
                    children: [
                      if (showIcon) ...[
                        const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(_label, style: labelStyle),
                      const Spacer(),
                      Text(price, style: priceStyle),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble() + 1;
  }
}

/// Ürün sepetteyken: lime "Sepete git" düğmesi ve sepetteki adet. Eklemeden
/// hemen sonra kısa bir süre "Sepete eklendi" onayı gösterir.
class _GoToCartButton extends StatelessWidget {
  final int quantity;
  final bool justAdded;
  final VoidCallback onTap;

  const _GoToCartButton({
    required this.quantity,
    required this.justAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(MarketRadius.md);
    final titleStyle = MarketText.label(
      color: MarketPalette.greenDeep,
      size: 15,
      weight: FontWeight.w800,
    );

    final Widget child = justAdded
        ? Row(
            key: const ValueKey('added'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: MarketPalette.greenDeep,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Sepete eklendi', style: titleStyle),
                ),
              ),
            ],
          )
        : Row(
            key: const ValueKey('go'),
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Sepete git', style: titleStyle),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sepetinde $quantity adet',
                        style: MarketText.caption(
                          color: MarketPalette.greenDark,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MarketSpace.sm),
              const Icon(
                Icons.arrow_forward_rounded,
                color: MarketPalette.greenDeep,
                size: 20,
              ),
            ],
          );

    return Semantics(
      button: true,
      label: justAdded
          ? 'Sepete eklendi. Sepetinde $quantity adet. Sepete git'
          : 'Sepete git, sepetinde $quantity adet',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: MarketPalette.lime,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: MarketSize.button,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stokta yok / satışta değil: kısa açıklama ve (varsa) benzer ürünlere geçiş.
class _SoldOutBar extends StatelessWidget {
  final bool unavailable;
  final bool hasSimilar;
  final VoidCallback onSeeSimilar;

  const _SoldOutBar({
    super.key,
    required this.unavailable,
    required this.hasSimilar,
    required this.onSeeSimilar,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MarketSize.button),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unavailable ? 'Artık satışta değil' : 'Şu an stokta yok',
                    style: MarketText.label(size: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sepete eklenemiyor',
                    style: MarketText.caption(size: 12),
                  ),
                ],
              ),
            ),
          ),
          if (hasSimilar) ...[
            const SizedBox(width: MarketSpace.md),
            OutlinedButton(
              onPressed: onSeeSimilar,
              style: OutlinedButton.styleFrom(
                foregroundColor: MarketPalette.greenDark,
                side: const BorderSide(color: MarketPalette.greenLine, width: 1.5),
                minimumSize: const Size(0, MarketSize.tapTarget),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MarketRadius.md),
                ),
                textStyle: MarketText.label(size: 14),
              ),
              child: const Text('Benzerlerini gör'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Küçük parçalar
// ---------------------------------------------------------------------------

class _LargeImageFallback extends StatelessWidget {
  const _LargeImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: MarketPalette.subtle,
        size: 64,
      ),
    );
  }
}

class _SimilarProductsSkeleton extends StatelessWidget {
  final double height;
  final double gutter;

  const _SimilarProductsSkeleton({required this.height, required this.gutter});

  @override
  Widget build(BuildContext context) {
    return MarketSkeletonPulse(
      semanticLabel: 'Benzer ürünler yükleniyor',
      child: SizedBox(
        height: height,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: MarketSpace.md),
          itemBuilder: (_, __) => const SizedBox(
            width: _SimilarProducts._cardWidth,
            child: MarketCard(
              shadow: false,
              padding: EdgeInsets.all(MarketSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MarketSkeleton(
                      width: double.infinity,
                      height: double.infinity,
                      radius: MarketRadius.md,
                    ),
                  ),
                  SizedBox(height: MarketSpace.md),
                  MarketSkeleton(width: 110, height: 13, radius: MarketRadius.xs),
                  SizedBox(height: MarketSpace.sm),
                  MarketSkeleton(width: 64, height: 16, radius: MarketRadius.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
