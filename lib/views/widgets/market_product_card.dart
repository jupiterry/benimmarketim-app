import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/flash_sale.dart';
import '../../models/product.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/favorites_viewmodel.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
import 'category_presentation.dart';
import 'custom_dialog.dart';
import 'flash_sale_widgets.dart';
import 'market_ui.dart';
import '../../services/app_logger.dart';
import '../../services/image_url.dart';

/// Ürün ızgaralarında kullanılan kart yüksekliği (yazı boyutu 1.0'da).
const double marketProductCardHeight = 268;

/// Kart yüksekliği, sistem yazı boyutuna göre büyütülmüş hali (1.0 → +0,
/// 1.3 → +27, 2.0 ve üstü → +90). Izgaraların `mainAxisExtent`'i ve yatay
/// rafların yüksekliği için bunu kullan.
double marketProductCardExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
  return marketProductCardHeight + (scale - 1).clamp(0.0, 1.0) * 90;
}

/// Ürün ızgarası yüklenirken gösterilen iskelet (2 sütun, kartla aynı ölçü).
class MarketProductGridSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const MarketProductGridSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return MarketSkeletonPulse(
      semanticLabel: 'Ürünler yükleniyor',
      child: GridView.builder(
        shrinkWrap: true,
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: marketProductCardExtent(context),
          crossAxisSpacing: MarketSpace.md,
          mainAxisSpacing: MarketSpace.md,
        ),
        itemBuilder: (_, __) => const MarketProductCardSkeleton(),
      ),
    );
  }
}

/// Tek kartın iskeleti (yatay raflar ve ızgaralar için). Nabız efekti için
/// [MarketSkeletonPulse] içine koy.
class MarketProductCardSkeleton extends StatelessWidget {
  const MarketProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MarketCard(
      shadow: false,
      padding: EdgeInsets.all(6),
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
          Padding(
            padding: EdgeInsets.fromLTRB(6, 12, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarketSkeleton(width: 56, height: 10, radius: MarketRadius.xs),
                SizedBox(height: MarketSpace.sm),
                MarketSkeleton(width: 110, height: 13, radius: MarketRadius.xs),
                SizedBox(height: MarketSpace.sm),
                MarketSkeleton(width: 64, height: 16, radius: MarketRadius.xs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketProductCard extends StatelessWidget {
  /// Listeden gelen ürün. Gösterilen fiyat ve stok, flash sale başlayıp
  /// bittiyse [FlashSaleViewModel.latest] ile güncellenmiş halidir.
  final Product product;

  /// Aynı ürün sayfada birden çok rafta görünebiliyorsa (flash sale rafı,
  /// fırsatlar, ızgara) yalnızca birinde Hero geçişi açık olmalı; aynı
  /// etiketli iki Hero sayfa geçişinde hata verir.
  final bool hero;

  /// Kategori satırı gösterilsin mi (reyon sayfasında zaten belli olduğu için
  /// gizlenebilir).
  final bool showCategory;

  /// Favori düğmesiyle ekleme/çıkarma başarıyla bittikten sonra yeni durumla
  /// (true: favorilere eklendi) çağrılır; ör. "Geri al" bildirimi için.
  final ValueChanged<bool>? onFavoriteChanged;

  /// Flash sale ürününde görselin üstündeki geri sayım. Rafın başlığı aynı
  /// süreyi zaten gösteriyorsa kapatılır (aynı sayaç iki kez görünmesin).
  final bool showFlashTimer;

  /// Karta dokununca ürün sayfasını doğrudan açmak yerine güncel ürünle
  /// çağrılır (ör. alt sayfadaki kart, ürün sayfasını açmadan önce alt sayfayı
  /// kapatır).
  final ValueChanged<Product>? onOpen;

  const MarketProductCard({
    super.key,
    required this.product,
    this.hero = true,
    this.showCategory = true,
    this.onFavoriteChanged,
    this.showFlashTimer = true,
    this.onOpen,
  });

  /// Flash sale durumundan yalnızca bu kartı ilgilendiren alanlar değişince
  /// yeniden çizilir (liste her yenilendiğinde yeni nesneler gelir; aynı
  /// fiyat/stok/kampanya ise kart dokunulmaz).
  static bool _flashStateChanged(_FlashState prev, _FlashState next) {
    final a = prev.product;
    final b = next.product;
    if (a.id != b.id ||
        a.actualPrice != b.actualPrice ||
        a.price != b.price ||
        a.isDiscounted != b.isDiscounted ||
        a.isOutOfStock != b.isOutOfStock ||
        a.name != b.name ||
        a.image != b.image ||
        a.category != b.category ||
        a.updatedAt != b.updatedAt) {
      return true;
    }
    final sa = prev.sale;
    final sb = next.sale;
    if ((sa == null) != (sb == null)) return true;
    if (sa != null && sb != null) {
      return sa.id != sb.id ||
          sa.endDate != sb.endDate ||
          sa.discountPercentage != sb.discountPercentage;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<FlashSaleViewModel, _FlashState>(
      selector: (_, flash) => (
        product: flash.latest(product),
        // Rozet ve geri sayım ürünün kendi flashSale özetinden
        sale: flash.saleOf(product),
      ),
      shouldRebuild: _flashStateChanged,
      builder: (context, flashState, _) {
        final product = flashState.product;
        final sale = flashState.sale;
        return Selector<CartViewModel, int>(
          selector: (_, cart) => cart.getProductQuantity(product.id),
          builder: (context, quantity, _) => _buildCard(
            context,
            product: product,
            sale: sale,
            quantity: quantity,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Product product,
    required FlashSale? sale,
    required int quantity,
  }) {
    // Flash sale'de yüzde sunucunun kampanya özetinden gelir
    final discount = sale?.discountPercentage ??
        (product.isDiscounted ? product.discountPercentage : 0.0);
    final showOld = product.isDiscounted && product.price > product.actualPrice;
    final inCart = quantity > 0 && !product.isOutOfStock;
    final scaler = MediaQuery.textScalerOf(context);
    final displayName = productDisplayName(product.name);

    // Ekran okuyucu kartı tek cümle olarak okur; düğmeler ayrıca seçilebilir.
    final label = StringBuffer('$displayName, ${formatTl(product.actualPrice)}');
    if (showOld) {
      label.write(', eski fiyat ${formatTl(product.price)}');
      if (discount > 0) label.write(', %${discount.round()} indirim');
    }
    if (inCart) label.write(', sepette $quantity adet');
    if (product.isOutOfStock) label.write(', stokta yok');

    return Semantics(
      container: true,
      label: label.toString(),
      child: Material(
        color: MarketPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          side: inCart
              ? const BorderSide(color: MarketPalette.greenLine, width: 1.5)
              : const BorderSide(color: MarketPalette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen != null
              ? () => onOpen!(product)
              : () => context.push('/product', extra: product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        Positioned.fill(
                          child: _ImageWell(product: product, hero: hero),
                        ),
                        if (sale != null || discount > 0)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (sale != null)
                                  FlashBadge(discountPercentage: discount)
                                else
                                  MarketDiscountBadge(percentage: discount),
                                if (sale != null &&
                                    showFlashTimer &&
                                    !product.isOutOfStock) ...[
                                  const SizedBox(height: 4),
                                  // Sağ üstteki ♥ dairesinin (34 pt, köşeden
                                  // 5 pt içeride) soluna sığar; "2 gün 03:59"
                                  // gibi uzun süreler dar kartta küçülür.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: (box.maxWidth - 6 - 39 - 4)
                                          .clamp(0.0, double.infinity),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: FlashTimerChip(
                                        endDate: sale.endDate,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (product.isOutOfStock)
                          const Positioned.fill(child: _OutOfStockVeil()),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: MarketFavoriteButton(
                            product: product,
                            onChanged: onFavoriteChanged,
                          ),
                        ),
                        if (!product.isOutOfStock)
                          // Görünen düğme kutunun köşesinden 6 pt içeride
                          // (44 pt dokunma alanının 2 pt'lik payı dahil)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: MarketCartButton(
                              product: product,
                              maxWidth: box.maxWidth - 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showCategory) ...[
                        // Satır boş olsa da yer kaplar: yan yana kartların
                        // adları ve fiyatları aynı hizada kalır.
                        Text(
                          product.category.trim().isEmpty
                              ? ' '
                              : categoryDisplayName(product.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.caption(
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      SizedBox(
                        height: scaler.scale(13) * 1.3 * 2 + 1,
                        child: Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.label(
                            size: 13,
                            weight: FontWeight.w600,
                          ).copyWith(height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatTl(product.actualPrice),
                              style: MarketText.price(
                                color: showOld
                                    ? MarketPalette.red
                                    : MarketPalette.ink,
                              ),
                            ),
                            if (showOld) ...[
                              const SizedBox(width: 6),
                              Text(
                                formatTl(product.price),
                                style: MarketText.oldPrice(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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

Product flashLatest(BuildContext context, Product product) =>
    context.read<FlashSaleViewModel>().latest(product);

/// Kartın flash sale'den aldığı durum: güncel ürün ve (varsa) kampanya.
typedef _FlashState = ({Product product, FlashSale? sale});

/// Ürün görselinin beyaz "stüdyo" kutusu. Katalog fotoğraflarının çoğu beyaz
/// zeminli olduğu için kutu da beyazdır; ince çizgi kutuyu karttan ayırır.
class _ImageWell extends StatelessWidget {
  final Product product;
  final bool hero;

  const _ImageWell({required this.product, required this.hero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.line),
      ),
      child: product.image.isNotEmpty
          ? HeroMode(
              enabled: hero,
              child: Hero(
                tag: 'product_image_${product.id}',
                child: Image.network(
                  optimizedImageUrl(product.image, width: MarketImageSize.card),
                  fit: BoxFit.contain,
                  cacheWidth: 380,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const _ProductImageFallback(),
                ),
              ),
            )
          : const _ProductImageFallback(),
    );
  }
}

class _OutOfStockVeil extends StatelessWidget {
  const _OutOfStockVeil();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: MarketPalette.ink,
          borderRadius: BorderRadius.circular(MarketRadius.pill),
        ),
        child: Text(
          'Stokta yok',
          style: MarketText.label(color: Colors.white, size: 12),
        ),
      ),
    );
  }
}

/// İndirim yüzdesi rozeti ("%13"). Flash sale ürünlerinde [FlashBadge]
/// kullanılır.
class MarketDiscountBadge extends StatelessWidget {
  final double percentage;

  const MarketDiscountBadge({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MarketPalette.red,
        borderRadius: BorderRadius.circular(MarketRadius.xs),
      ),
      child: Text(
        '%${percentage.round()}',
        style: MarketText.label(
          color: Colors.white,
          size: 12,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Kart ve vitrinlerdeki yuvarlak favori düğmesi: görünen 34 pt, dokunma
/// alanı 44 pt. Misafir kullanıcıya giriş yapmasını öneren pencere açar.
class MarketFavoriteButton extends StatefulWidget {
  final Product product;

  /// Ekleme/çıkarma başarıyla bitince yeni durumla çağrılır (misafire giriş
  /// penceresi gösterildiğinde çağrılmaz).
  final ValueChanged<bool>? onChanged;

  const MarketFavoriteButton({
    super.key,
    required this.product,
    this.onChanged,
  });

  @override
  State<MarketFavoriteButton> createState() => _MarketFavoriteButtonState();
}

class _MarketFavoriteButtonState extends State<MarketFavoriteButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final favorites = context.read<FavoritesViewModel>();
    final auth = context.read<AuthViewModel>();
    if (!auth.isLoggedIn) {
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
    HapticFeedback.selectionClick();
    final latest = flashLatest(context, widget.product);
    final willBeFavorite = !favorites.isFavorite(latest.id);
    _busy = true;
    try {
      await favorites.toggleFavorite(latest);
    } catch (e) {
      AppLogger.debug('Favori güncellenemedi: $e');
      return;
    } finally {
      _busy = false;
    }
    widget.onChanged?.call(willBeFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Selector<FavoritesViewModel, bool>(
      selector: (_, favorites) => favorites.isFavorite(widget.product.id),
      builder: (context, isFavorite, _) {
        final tooltip = isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle';
        return Semantics(
          container: true,
          button: true,
          toggled: isFavorite,
          label: tooltip,
          excludeSemantics: true,
          onTap: _toggle,
          child: Tooltip(
            message: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Material(
                    color: Colors.white.withValues(alpha: .94),
                    shape: const CircleBorder(
                      side: BorderSide(color: MarketPalette.line),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggle,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isFavorite),
                            color: isFavorite
                                ? MarketPalette.pink
                                : MarketPalette.muted,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kartın sepet düğmesi. Sepette yokken yeşil "+" (40 pt); eklenince yerinde
/// beyaz bir adet seçiciye [−/🗑 | adet | +] dönüşür. Dokunma alanı 44 pt.
/// Sepete ekleme bildirim çıkarmaz: görünen geri bildirim bu dönüşüm ve
/// alt menüdeki sepet rozetidir; ekran okuyucuya ayrıca duyurulur.
class MarketCartButton extends StatelessWidget {
  final Product product;

  /// Seçicinin sığması gereken en geniş alan (dar kartlarda daralır).
  final double maxWidth;

  const MarketCartButton({
    super.key,
    required this.product,
    this.maxWidth = 108,
  });

  static const double _visual = 40;
  static const double _hit = 44;

  void _add(BuildContext context, {required bool first}) {
    HapticFeedback.selectionClick();
    context.read<CartViewModel>().addToCart(product);
    if (first) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${productDisplayName(product.name)} sepete eklendi',
        TextDirection.ltr,
      );
    }
  }

  void _remove(BuildContext context) {
    HapticFeedback.selectionClick();
    context.read<CartViewModel>().removeFromCart(product);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Selector<CartViewModel, int>(
      selector: (_, cart) => cart.getProductQuantity(product.id),
      builder: (context, quantity, _) {
        return AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerRight,
          child: quantity <= 0
              ? _buildAdd(context)
              : _buildStepper(context, quantity, reduceMotion),
        );
      },
    );
  }

  Widget _buildAdd(BuildContext context) {
    final name = productDisplayName(product.name);
    return Semantics(
      container: true,
      button: true,
      label: '$name sepete ekle',
      excludeSemantics: true,
      onTap: () => _add(context, first: true),
      child: Tooltip(
        message: 'Sepete ekle',
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _add(context, first: true),
          child: SizedBox.square(
            dimension: _hit,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: MarketPalette.greenDeep.withValues(alpha: .16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: MarketPalette.green,
                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                  child: InkWell(
                    onTap: () => _add(context, first: true),
                    borderRadius: BorderRadius.circular(MarketRadius.sm),
                    child: const SizedBox.square(
                      dimension: _visual,
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(BuildContext context, int quantity, bool reduceMotion) {
    final width = maxWidth.clamp(96.0, 108.0);
    final countWidth = width - _visual * 2;
    final name = productDisplayName(product.name);
    const radius = Radius.circular(MarketRadius.sm);

    return Semantics(
      container: true,
      label: '$name, sepette',
      value: '$quantity adet',
      increasedValue: '${quantity + 1} adet',
      decreasedValue: quantity > 1 ? '${quantity - 1} adet' : 'Sepetten çıkar',
      onIncrease: () => _add(context, first: false),
      onDecrease: () => _remove(context),
      child: SizedBox(
        width: width,
        height: _hit,
        child: Stack(
          children: [
            // Görünen hap 40 pt; üst/alttaki 2'şer pt dokunma payıdır.
            Positioned.fill(
              top: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MarketPalette.surface,
                  borderRadius: const BorderRadius.all(radius),
                  border: Border.all(color: MarketPalette.greenLine),
                  boxShadow: [
                    BoxShadow(
                      color: MarketPalette.greenDeep.withValues(alpha: .12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: _visual,
                      decoration: const BoxDecoration(
                        color: MarketPalette.green,
                        borderRadius: BorderRadius.horizontal(right: radius),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  _StepperHalf(
                    icon: quantity <= 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    color: MarketPalette.greenDark,
                    tooltip: quantity <= 1 ? 'Sepetten çıkar' : 'Azalt',
                    borderRadius:
                        const BorderRadius.horizontal(left: radius),
                    onTap: () => _remove(context),
                  ),
                  SizedBox(
                    width: countWidth,
                    child: ExcludeSemantics(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          child: Text(
                            '$quantity',
                            key: ValueKey(quantity),
                            maxLines: 1,
                            style: MarketText.label(
                              color: MarketPalette.greenDeep,
                              size: 14,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _StepperHalf(
                    icon: Icons.add_rounded,
                    color: Colors.white,
                    tooltip: 'Artır',
                    borderRadius:
                        const BorderRadius.horizontal(right: radius),
                    onTap: () => _add(context, first: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperHalf extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _StepperHalf({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: SizedBox(
            width: MarketCartButton._visual,
            height: MarketCartButton._hit,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: MarketPalette.subtle,
        size: 38,
      ),
    );
  }
}
