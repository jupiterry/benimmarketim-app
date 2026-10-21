import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import 'widgets/flash_sale_widgets.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_ui.dart';
import '../services/image_url.dart';

const int _maxQuantity = 99;

/// Ürün detayı.
///
/// Üstte açık renkli bir "vitrin" (yumuşak lime ışık, ürün görseli ve
/// rozetler), üzerine yukarı çekilebilen beyaz bir bilgi paneli: ad, fiyat,
/// teslimat bilgileri, açıklama ve benzer ürünler. Altta sabit sepet çubuğu.
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

  @override
  void initState() {
    super.initState();
    _refreshProduct();
    _loadSimilarProducts();
  }

  /// Listedeki ürün bilgisi eski olabilir (flash sale başlamış/bitmiş, stok
  /// değişmiş). Sayfa açılınca güncel hali sunucudan alınır.
  Future<void> _refreshProduct() async {
    try {
      final fresh = await ApiService().getProductById(widget.product.id);
      if (!mounted || fresh.id != widget.product.id) return;
      setState(() => _product = fresh);
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

  @override
  Widget build(BuildContext context) {
    final flash = context.watch<FlashSaleViewModel>();
    final product = flash.latest(_product);
    final sale = flash.saleFor(product.id);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final showcaseHeight =
              (height * .44).clamp(280.0, 440.0).toDouble();
          // Panel vitrinin alt kenarına biner; ilk konumda görsel tam görünür.
          final initial = ((height - showcaseHeight + 34) / height)
              .clamp(.42, .9)
              .toDouble();

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
                  onBack: _goBack,
                  favoriteButton: _buildFavoriteButton(product),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: initial,
                minChildSize: initial,
                maxChildSize: .97,
                snap: true,
                builder: (context, controller) => _InfoPanel(
                  controller: controller,
                  product: product,
                  sale: sale,
                  descriptionExpanded: _descriptionExpanded,
                  onToggleDescription: () => setState(
                    () => _descriptionExpanded = !_descriptionExpanded,
                  ),
                  similarProducts: _similarProducts,
                  isLoadingSimilar: _isLoadingSimilar,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _PurchaseDock(
        product: product,
        quantity: _quantity,
        onMinus: () {
          if (_quantity > 1) setState(() => _quantity--);
        },
        onPlus: () {
          if (_quantity < _maxQuantity) setState(() => _quantity++);
        },
        onAdd: () => _addToCart(product),
      ),
    );
  }

  Widget _buildFavoriteButton(Product product) {
    return Consumer<FavoritesViewModel>(
      builder: (context, favorites, _) {
        final isFavorite = favorites.isFavorite(product.id);
        return _RoundButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: isFavorite ? MarketPalette.pink : MarketPalette.ink,
          semanticLabel: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
          onTap: () => _toggleFavorite(favorites, product),
        );
      },
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

  void _addToCart(Product product) {
    HapticFeedback.selectionClick();
    final quantity = _quantity;
    // Tek yazma, tek ölçüm olayı: adet tek seferde eklenir.
    context.read<CartViewModel>().addQuantity(product, quantity);
    setState(() => _quantity = 1);
    showMarketSnack(
      context,
      '$quantity adet ${product.name} sepete eklendi',
      aboveNavigation: true,
    );
  }

  void _toggleFavorite(FavoritesViewModel favorites, Product product) {
    final auth = context.read<AuthViewModel>();
    if (!auth.isLoggedIn) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const MarketIconTile(
            icon: Icons.favorite_rounded,
            size: 52,
            background: MarketPalette.pinkSoft,
            foreground: MarketPalette.pink,
          ),
          title: const Text('Favorilerini sakla', textAlign: TextAlign.center),
          content: const Text(
            'Favorilere ürün eklemek için hesabına giriş yapmalısın.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Şimdi değil'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/login');
              },
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      );
      return;
    }
    favorites.toggleFavorite(product);
  }
}

// ---------------------------------------------------------------------------
// Vitrin: açık zemin, yumuşak lime ışık, ürün görseli ve rozetler
// ---------------------------------------------------------------------------

class _Showcase extends StatelessWidget {
  final Product product;
  final FlashSale? sale;
  final VoidCallback onBack;
  final Widget favoriteButton;

  const _Showcase({
    required this.product,
    required this.sale,
    required this.onBack,
    required this.favoriteButton,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final discount =
        product.isDiscounted ? product.discountPercentage.round() : 0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MarketPalette.limeSoft, MarketPalette.canvas],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sağ üstte büyük, sol altta küçük yumuşak lime halkalar
          Positioned(
            top: -70,
            right: -60,
            child: _Glow(size: 260, alpha: .42),
          ),
          Positioned(
            bottom: 10,
            left: -90,
            child: _Glow(size: 220, alpha: .28),
          ),
          Positioned(
            top: top + 60,
            left: 48,
            right: 48,
            bottom: 30,
            child: Center(child: _ProductImage(product: product)),
          ),
          // Görselin altındaki zemin gölgesi: ürün "yerde duruyor" hissi
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                width: 160,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MarketRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: MarketPalette.greenDeep.withValues(alpha: .18),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Geri dön',
                  onTap: onBack,
                ),
                const Spacer(),
                favoriteButton,
              ],
            ),
          ),
          if (sale != null || discount > 0)
            Positioned(
              left: 20,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sale != null)
                    FlashBadge(
                      discountPercentage: discount > 0
                          ? discount.toDouble()
                          : sale!.discountPercentage,
                    )
                  else
                    _DiscountStamp(percent: discount),
                  if (sale != null) ...[
                    const SizedBox(height: 8),
                    FlashTimerChip(endDate: sale!.endDate),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final double alpha;

  const _Glow({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              MarketPalette.lime.withValues(alpha: alpha),
              MarketPalette.lime.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Product product;

  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.image.isEmpty) return const _LargeImageFallback();
    return Hero(
      tag: 'product_image_${product.id}',
      child: Image.network(
        optimizedImageUrl(product.image, width: MarketImageSize.detail),
        fit: BoxFit.contain,
        cacheWidth: 850,
        // Büyük görsel gelene kadar kartta zaten yüklü küçük görsel
        frameBuilder: (context, child, frame, sync) => frame == null && !sync
            ? Image.network(
                optimizedImageUrl(product.image, width: MarketImageSize.card),
                fit: BoxFit.contain,
                cacheWidth: 380,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : child,
        errorBuilder: (_, __, ___) => const _LargeImageFallback(),
      ),
    );
  }
}

/// Açık zemin üstünde beyaz, hafif gölgeli yuvarlak düğme.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color iconColor;

  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor = MarketPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withValues(alpha: .1),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: MarketPalette.surface,
          shape: const CircleBorder(side: BorderSide(color: MarketPalette.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
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
        boxShadow: [
          BoxShadow(
            color: MarketPalette.red.withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;
  final List<Product> similarProducts;
  final bool isLoadingSimilar;

  const _InfoPanel({
    required this.controller,
    required this.product,
    required this.sale,
    required this.descriptionExpanded,
    required this.onToggleDescription,
    required this.similarProducts,
    required this.isLoadingSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final description = product.description.trim();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MarketRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .12),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
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
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MarketPalette.lineStrong,
                      borderRadius: BorderRadius.circular(MarketRadius.pill),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryLink(categoryName: product.category),
                          ),
                          _StockChip(outOfStock: product.isOutOfStock),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(product.name, style: MarketText.title(size: 24)),
                      const SizedBox(height: 14),
                      _PriceRow(product: product, flash: sale != null),
                      const SizedBox(height: 18),
                      const _FactsRow(),
                      if (sale != null) ...[
                        const SizedBox(height: 16),
                        FlashSaleBanner(sale: sale!),
                      ],
                      _InCartNotice(productId: product.id),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _Description(
                          description: description,
                          expanded: descriptionExpanded,
                          onToggle: onToggleDescription,
                        ),
                      ],
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLoadingSimilar || similarProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: _SimilarProducts(
                products: similarProducts,
                loading: isLoadingSimilar,
              ),
            ),
          SliverPadding(padding: EdgeInsets.only(bottom: 28 + bottomInset)),
        ],
      ),
    );
  }
}

/// Kategori adı: dokununca o kategorinin sayfası açılır (kategori listesi
/// yüklüyse).
class _CategoryLink extends StatelessWidget {
  final String categoryName;

  const _CategoryLink({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final key = normalizedCategoryKey(categoryName);
    Category? category;
    for (final c in context.watch<CategoryViewModel>().categories) {
      if (normalizedCategoryKey(c.name) == key) {
        category = c;
        break;
      }
    }
    final label = Text(
      '${categoryEmoji(categoryName)}  ${categoryDisplayName(categoryName)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MarketText.label(color: MarketPalette.green, size: 13),
    );
    if (category == null) {
      return Align(alignment: Alignment.centerLeft, child: label);
    }
    final target = category;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => context.push('/category', extra: target),
        borderRadius: BorderRadius.circular(MarketRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: MarketPalette.green,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  final bool outOfStock;

  const _StockChip({required this.outOfStock});

  @override
  Widget build(BuildContext context) {
    final color = outOfStock ? MarketPalette.red : MarketPalette.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: outOfStock ? MarketPalette.redSoft : MarketPalette.greenSoft,
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
            outOfStock ? 'Stokta yok' : 'Stokta var',
            style: MarketText.label(
              color: outOfStock ? MarketPalette.red : MarketPalette.greenDark,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Büyük fiyat; indirimde eski fiyat üstü çizili ve kazanç rozeti.
class _PriceRow extends StatelessWidget {
  final Product product;
  final bool flash;

  const _PriceRow({required this.product, required this.flash});

  @override
  Widget build(BuildContext context) {
    final hasSavings = product.price > product.actualPrice;
    final label = flash
        ? 'Flash sale fiyatı'
        : hasSavings
            ? 'İndirimli fiyat'
            : 'Birim fiyat';

    return Semantics(
      label: hasSavings
          ? '$label ${formatTl(product.actualPrice)}, '
              'normal fiyat ${formatTl(product.price)}'
          : '$label ${formatTl(product.actualPrice)}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MarketText.caption(size: 12)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatTl(product.actualPrice),
                          style: MarketText.price(
                            color: MarketPalette.greenDeep,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    if (hasSavings) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          formatTl(product.price),
                          style: MarketText.body(
                            color: MarketPalette.subtle,
                            size: 15,
                            weight: FontWeight.w600,
                          ).copyWith(
                            decoration: TextDecoration.lineThrough,
                            decorationColor: MarketPalette.subtle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasSavings)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: MarketPalette.lime,
                borderRadius: BorderRadius.circular(MarketRadius.pill),
              ),
              child: Text(
                '${formatTlShort(product.price - product.actualPrice)} kazanç',
                style: MarketText.label(
                  color: MarketPalette.greenDeep,
                  size: 12,
                  weight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sipariş için işe yarar bilgiler, yan yana küçük kartlar halinde:
/// minimum tutara kalan, teslimat noktaları ve sipariş saatleri.
class _FactsRow extends StatelessWidget {
  const _FactsRow();

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

    final facts = <_Fact>[
      if (minimum > 0)
        _Fact(
          icon: remaining == 0
              ? Icons.check_circle_rounded
              : Icons.shopping_basket_outlined,
          title: remaining == 0 ? 'Sepet hazır' : '${formatTlShort(remaining)} kaldı',
          detail: 'Minimum sipariş ${formatTlShort(minimum)}',
          highlight: remaining == 0,
        ),
      _Fact(
        icon: Icons.location_on_outlined,
        title: points.isEmpty ? 'Teslimat kapalı' : 'Teslimat',
        detail: points.isEmpty ? 'Şu an teslimat yapılmıyor' : points.join(' · '),
      ),
      _Fact(
        icon: settings.isWithinOrderHours
            ? Icons.schedule_rounded
            : Icons.bedtime_outlined,
        title: settings.isWithinOrderHours ? 'Sipariş açık' : 'Sipariş kapalı',
        detail: settings.orderHoursMessage,
        highlight: settings.isWithinOrderHours,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: facts.length,
        separatorBuilder: (_, __) => const SizedBox(width: MarketSpace.sm),
        itemBuilder: (context, index) => _FactCard(fact: facts[index]),
      ),
    );
  }
}

class _Fact {
  final IconData icon;
  final String title;
  final String detail;
  final bool highlight;

  const _Fact({
    required this.icon,
    required this.title,
    required this.detail,
    this.highlight = false,
  });
}

class _FactCard extends StatelessWidget {
  final _Fact fact;

  const _FactCard({required this.fact});

  @override
  Widget build(BuildContext context) {
    final accent = fact.highlight ? MarketPalette.green : MarketPalette.muted;
    return Container(
      width: 164,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: fact.highlight ? MarketPalette.greenSoft : MarketPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(
          color: fact.highlight ? MarketPalette.greenLine : MarketPalette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(fact.icon, size: 17, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fact.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.label(
                    size: 13,
                    color: fact.highlight ? MarketPalette.greenDark : MarketPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              fact.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MarketText.caption(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InCartNotice extends StatelessWidget {
  final String productId;

  const _InCartNotice({required this.productId});

  @override
  Widget build(BuildContext context) {
    final quantity = context.select<CartViewModel, int>(
      (cart) => cart.getProductQuantity(productId),
    );
    if (quantity == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MarketNotice(
        icon: Icons.shopping_basket_rounded,
        text: 'Sepetinde $quantity adet var',
        trailing: TextButton(
          onPressed: () => context.go(
            '/home',
            extra: <String, dynamic>{'initialTabIndex': 1},
          ),
          style: TextButton.styleFrom(
            foregroundColor: MarketPalette.greenDark,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
          ),
          child: const Text('Sepete git'),
        ),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  final String description;
  final bool expanded;
  final VoidCallback onToggle;

  const _Description({
    required this.description,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final long = description.length > 180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ürün hakkında', style: MarketText.heading()),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Text(
            description,
            maxLines: long && !expanded ? 4 : null,
            overflow:
                long && !expanded ? TextOverflow.ellipsis : TextOverflow.visible,
            style: MarketText.body(color: MarketPalette.inkSoft, height: 1.6),
          ),
        ),
        if (long)
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: MarketPalette.greenDark,
            ),
            child: Text(expanded ? 'Daha az göster' : 'Devamını oku'),
          ),
      ],
    );
  }
}

class _SimilarProducts extends StatelessWidget {
  final List<Product> products;
  final bool loading;

  const _SimilarProducts({required this.products, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MarketSectionTitle(
            title: 'Yanına iyi gider',
            subtitle: 'Aynı raftan benzer ürünler',
            trailing: products.isEmpty
                ? null
                : MarketPill(label: '${products.length} ürün'),
          ),
        ),
        const SizedBox(height: 14),
        if (loading)
          const _SimilarProductsSkeleton()
        else
          SizedBox(
            height: marketProductCardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (context, index) => SizedBox(
                width: 172,
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

class _PurchaseDock extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onAdd;

  const _PurchaseDock({
    required this.product,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final total = product.actualPrice * quantity;
    final oldTotal = product.price * quantity;
    final showOld = product.price > product.actualPrice;

    return Container(
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        border: const Border(top: BorderSide(color: MarketPalette.line)),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: product.isOutOfStock
              ? const _OutOfStockBar()
              : Row(
                  children: [
                    MarketStepper(
                      quantity: quantity,
                      onMinus: onMinus,
                      onPlus: onPlus,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Sepete ekle, ${formatTl(total)}',
                        excludeSemantics: true,
                        child: Material(
                          color: MarketPalette.greenDeep,
                          borderRadius: BorderRadius.circular(MarketRadius.md),
                          child: InkWell(
                            onTap: onAdd,
                            borderRadius: BorderRadius.circular(MarketRadius.md),
                            child: SizedBox(
                              height: 54,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Sepete ekle',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MarketText.label(
                                          color: Colors.white,
                                          size: 15,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (showOld)
                                          Text(
                                            formatTl(oldTotal),
                                            style: MarketText.caption(
                                              color: Colors.white
                                                  .withValues(alpha: .6),
                                              size: 11,
                                            ).copyWith(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              decorationColor: Colors.white
                                                  .withValues(alpha: .6),
                                            ),
                                          ),
                                        Text(
                                          formatTl(total),
                                          style: MarketText.price(
                                            color: MarketPalette.lime,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OutOfStockBar extends StatelessWidget {
  const _OutOfStockBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: MarketPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.remove_shopping_cart_rounded,
            color: MarketPalette.muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Şu an stokta yok',
            style: MarketText.label(color: MarketPalette.muted, size: 14),
          ),
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
        size: 72,
      ),
    );
  }
}

class _SimilarProductsSkeleton extends StatelessWidget {
  const _SimilarProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return MarketSkeletonPulse(
      semanticLabel: 'Benzer ürünler yükleniyor',
      child: SizedBox(
        height: marketProductCardHeight,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 13),
          itemBuilder: (_, __) => const SizedBox(
            width: 172,
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
