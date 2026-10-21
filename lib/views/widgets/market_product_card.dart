import 'package:flutter/material.dart';
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
import 'flash_sale_widgets.dart';
import 'market_ui.dart';
import '../../services/image_url.dart';

/// Ürün ızgaralarında kullanılan kart yüksekliği.
const double marketProductCardHeight = 300;

/// Ürün ızgarası yüklenirken gösterilen iskelet (2 sütun).
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: marketProductCardHeight,
          crossAxisSpacing: 13,
          mainAxisSpacing: 13,
        ),
        itemBuilder: (_, __) => const MarketCard(
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

  const MarketProductCard({
    super.key,
    required this.product,
    this.hero = true,
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
        product: flash.latest(this.product),
        sale: flash.saleFor(this.product.id),
      ),
      shouldRebuild: _flashStateChanged,
      builder: (context, flashState, _) {
        final product = flashState.product;
        final sale = flashState.sale;
        final discount = product.isDiscounted ? product.discountPercentage : 0.0;

        return Semantics(
          container: true,
          label:
              '${product.name}, ${formatTl(product.actualPrice)}${product.isOutOfStock ? ', stokta yok' : ''}',
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MarketRadius.lg),
              side: const BorderSide(color: MarketPalette.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/product', extra: product),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(7),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MarketPalette.canvas,
                              borderRadius: BorderRadius.circular(MarketRadius.md),
                            ),
                            child: product.image.isNotEmpty
                                ? HeroMode(
                                    enabled: hero,
                                    child: Hero(
                                      tag: 'product_image_${product.id}',
                                      child: Image.network(
                                        optimizedImageUrl(
                                          product.image,
                                          width: MarketImageSize.card,
                                        ),
                                        fit: BoxFit.contain,
                                        cacheWidth: 380,
                                        errorBuilder: (_, __, ___) =>
                                            const _ProductImageFallback(),
                                      ),
                                    ),
                                  )
                                : const _ProductImageFallback(),
                          ),
                        ),
                        if (sale != null)
                          Positioned(
                            left: 13,
                            top: 13,
                            child: FlashBadge(
                              discountPercentage: discount > 0
                                  ? discount
                                  : sale.discountPercentage,
                            ),
                          )
                        else if (discount > 0)
                          Positioned(
                            left: 13,
                            top: 13,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MarketPalette.red,
                                borderRadius: BorderRadius.circular(MarketRadius.sm),
                              ),
                              child: Text(
                                '%${discount.toInt()}',
                                style: MarketText.label(color: Colors.white, size: 12, weight: FontWeight.w800),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Selector<FavoritesViewModel, bool>(
                            selector: (_, favorites) =>
                                favorites.isFavorite(product.id),
                            builder: (context, isFavorite, _) => Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 0,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _toggleFavorite(context),
                                child: Tooltip(
                                  message: isFavorite
                                      ? 'Favorilerden çıkar'
                                      : 'Favorilere ekle',
                                  child: SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: Icon(
                                      isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isFavorite
                                          ? MarketPalette.red
                                          : MarketPalette.muted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (sale != null && !product.isOutOfStock)
                          Positioned(
                            left: 13,
                            bottom: 13,
                            child: FlashTimerChip(endDate: sale.endDate),
                          ),
                        if (product.isOutOfStock)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .78),
                                borderRadius: BorderRadius.circular(MarketRadius.md),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: MarketPalette.ink,
                                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                                ),
                                child: Text(
                                  'Stokta yok',
                                  style: MarketText.label(color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.category.trim().isNotEmpty) ...[
                          Text(
                            categoryDisplayName(product.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.caption(
                              color: MarketPalette.green,
                              size: 12,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        SizedBox(
                          height: 36,
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.label(size: 13, weight: FontWeight.w600)
                                .copyWith(height: 1.3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _ProductPrice(product: product)),
                            const SizedBox(width: 6),
                            if (product.isOutOfStock)
                              const _DisabledAddButton()
                            else
                              Selector<CartViewModel, int>(
                                selector: (_, cart) =>
                                    cart.getProductQuantity(product.id),
                                builder: (context, quantity, _) {
                                  if (quantity > 0) {
                                    return MarketStepper(
                                      quantity: quantity,
                                      compact: true,
                                      onMinus: () => context
                                          .read<CartViewModel>()
                                          .removeFromCart(product),
                                      onPlus: () => context
                                          .read<CartViewModel>()
                                          .addToCart(product),
                                    );
                                  }
                                  return _AddButton(
                                    productName: product.name,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      context.read<CartViewModel>().addToCart(product);
                                      showMarketSnack(
                                        context,
                                        '${product.name} sepete eklendi',
                                        aboveNavigation: true,
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleFavorite(BuildContext context) {
    final favorites = context.read<FavoritesViewModel>();
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
    favorites.toggleFavorite(flashLatest(context, product));
  }
}

Product flashLatest(BuildContext context, Product product) =>
    context.read<FlashSaleViewModel>().latest(product);

/// Kartın flash sale'den aldığı durum: güncel ürün ve (varsa) kampanya.
typedef _FlashState = ({Product product, FlashSale? sale});

class _ProductPrice extends StatelessWidget {
  final Product product;

  const _ProductPrice({required this.product});

  @override
  Widget build(BuildContext context) {
    final showOld = product.isDiscounted && product.price > product.actualPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showOld)
          Text(
            formatTl(product.price),
            maxLines: 1,
            style: MarketText.caption(size: 12).copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: MarketPalette.muted,
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatTl(product.actualPrice),
            style: MarketText.price(
              color: showOld ? MarketPalette.red : MarketPalette.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final String productName;

  const _AddButton({required this.onTap, required this.productName});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$productName sepete ekle',
      excludeSemantics: true,
      child: Material(
        color: MarketPalette.green,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _DisabledAddButton extends StatelessWidget {
  const _DisabledAddButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: MarketPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: const Icon(
        Icons.remove_shopping_cart_outlined,
        color: MarketPalette.subtle,
        size: 19,
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
