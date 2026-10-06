import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/coupon.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import '../viewmodels/referral_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/community_campaign.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_mascot.dart';
import 'widgets/market_ui.dart';
import 'widgets/save_cart_dialog.dart';

class CartPage extends StatelessWidget {
  final VoidCallback? onExplore;

  const CartPage({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final items = cart.items;
    final unitCount = cart.totalItems;

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Column(
        children: [
          MarketHeader(
            title: 'Sepetim',
            subtitle: items.isEmpty
                ? 'Alışverişe başlamaya hazır mısın?'
                : '$unitCount ürün • ${items.length} çeşit',
            icon: Icons.shopping_bag_rounded,
            showBack: false,
            compact: true,
            actions: [
              if (items.isNotEmpty)
                MarketHeaderButton(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: 'Favori sepet olarak kaydet',
                  onTap: () => showSaveCartDialog(
                    context,
                    aboveNavigation: true,
                    items: [
                      for (final item in items)
                        {
                          'productId': item.product.id,
                          'quantity': item.quantity > 20 ? 20 : item.quantity,
                        },
                    ],
                  ),
                ),
              if (items.isNotEmpty)
                MarketHeaderButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Sepeti boşalt',
                  onTap: () => _confirmClear(context, cart),
                ),
            ],
          ),
          Expanded(
            child: items.isEmpty
                ? _EmptyCart(onExplore: onExplore)
                : const _CartContent(),
          ),
          if (items.isNotEmpty)
            SafeArea(top: false, child: _CheckoutBar(cart: cart)),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, CartViewModel cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.delete_sweep_outlined,
          size: 52,
          background: MarketPalette.redSoft,
          foreground: MarketPalette.red,
        ),
        title: const Text('Sepet boşaltılsın mı?', textAlign: TextAlign.center),
        content: const Text(
          'Sepetindeki tüm ürünler kaldırılacak.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: MarketPalette.red),
            child: const Text('Boşalt'),
          ),
        ],
      ),
    );
    if (confirmed == true) cart.clearCart();
  }
}

// ---------------------------------------------------------------------------
// İçerik
// ---------------------------------------------------------------------------

class _CartContent extends StatelessWidget {
  const _CartContent();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final items = cart.items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        const _StoreClosedNotice(),
        const _MinimumOrderProgress(),
        // Sepetteki ürünler tek kartta, ilk bakışta görünür.
        MarketCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _CartItemCard(item: items[i], cart: cart),
              ],
            ],
          ),
        ),
        const _MinimumOrderSuggestions(),
        const SizedBox(height: MarketSpace.xl),
        _AvailableCouponBanner(cart: cart),
        const _CouponSection(),
        const _CouponRequestCampaignCard(),
        const SizedBox(height: MarketSpace.lg),
        _PriceSummary(cart: cart),
      ],
    );
  }
}

/// Mağaza kapalıyken kullanıcı bunu sipariş adımında değil, sepette öğrenir.
class _StoreClosedNotice extends StatelessWidget {
  const _StoreClosedNotice();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    if (settings.isWithinOrderHours) return const SizedBox.shrink();
    final opens =
        '${settings.orderStartHour.toString().padLeft(2, '0')}:${settings.orderStartMinute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MarketNotice.warning(
        icon: Icons.schedule_rounded,
        text: 'Şu an sipariş alamıyoruz. Açılış saati $opens; sepetin seni bekler.',
      ),
    );
  }
}

class _MinimumOrderProgress extends StatelessWidget {
  const _MinimumOrderProgress();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final minimum = context.watch<SettingsViewModel>().minimumOrderAmount;
    final total = cart.totalPrice;
    // Tutar dolunca şerit kalkar; alttaki buton zaten etkinleşir.
    if (minimum <= 0 || total >= minimum) return const SizedBox.shrink();
    final progress = (total / minimum).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: MarketSpace.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: MarketPalette.orangeSoft,
          borderRadius: BorderRadius.circular(MarketRadius.md),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: MarketPalette.orangeInk,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: formatTl(minimum - total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' daha ekle, sipariş ver'),
                    ]),
                    style: MarketText.label(
                      color: MarketPalette.orangeInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'En az ${formatTlShort(minimum)}',
                  style: MarketText.caption(color: MarketPalette.orangeInk),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(MarketRadius.xs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: MarketPalette.orange,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimum tutara ulaşılmadıysa eksiği kapatabilecek ürünleri önerir.
/// Önce tek başına eksiği kapatan en ucuz ürünler, sonra en çok yaklaştıranlar.
class _MinimumOrderSuggestions extends StatelessWidget {
  const _MinimumOrderSuggestions();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final minimum = context.watch<SettingsViewModel>().minimumOrderAmount;
    final gap = minimum - cart.totalPrice;
    if (gap <= 0) return const SizedBox.shrink();

    final home = context.watch<HomePageViewModel>();
    final seen = <String>{};
    final candidates = <Product>[
      ...home.personalizedProducts,
      ...home.featuredProducts,
      ...home.products,
    ].where((p) {
      if (p.isHidden || p.isOutOfStock || p.actualPrice <= 0) return false;
      if (cart.isInCart(p.id)) return false;
      return seen.add(p.id);
    }).toList();

    final closers = candidates.where((p) => p.actualPrice >= gap).toList()
      ..sort((a, b) => a.actualPrice.compareTo(b.actualPrice));
    final others = candidates.where((p) => p.actualPrice < gap).toList()
      ..sort((a, b) => b.actualPrice.compareTo(a.actualPrice));
    final picks = [...closers.take(5), ...others].take(8).toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: MarketSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bunu da ekle', style: MarketText.heading()),
          const SizedBox(height: MarketSpace.md),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _SuggestionTile(
                product: picks[index],
                closesGap: picks[index].actualPrice >= gap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Product product;
  final bool closesGap;

  const _SuggestionTile({required this.product, required this.closesGap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      child: MarketCard(
        shadow: false,
        padding: const EdgeInsets.all(10),
        borderColor: closesGap ? MarketPalette.greenLine : MarketPalette.line,
        onTap: () => context.push('/product', extra: product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: product.image.isEmpty
                    ? const Icon(Icons.inventory_2_outlined,
                        color: MarketPalette.subtle)
                    : Image.network(
                        product.image,
                        fit: BoxFit.contain,
                        cacheWidth: 240,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: MarketPalette.subtle,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MarketText.label(size: 12, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatTl(product.actualPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.price(
                      color: MarketPalette.greenDark,
                      size: 14,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Sepete ekle',
                  child: Material(
                    color: MarketPalette.green,
                    borderRadius: BorderRadius.circular(MarketRadius.sm),
                    child: InkWell(
                      onTap: () =>
                          context.read<CartViewModel>().addToCart(product),
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartViewModel cart;

  const _CartItemCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final discounted = product.actualPrice < product.price;

    return Dismissible(
      key: ValueKey('cart-${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: MarketPalette.red,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kaldır', style: MarketText.label(color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      child: Material(
        color: MarketPalette.surface,
        child: InkWell(
        onTap: () => context.push('/product', extra: product),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: MarketPalette.canvas,
                borderRadius: BorderRadius.circular(MarketRadius.md),
              ),
              child: product.image.isNotEmpty
                  ? Image.network(
                      product.image,
                      fit: BoxFit.contain,
                      cacheWidth: 200,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_outlined,
                        color: MarketPalette.subtle,
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined, color: MarketPalette.subtle),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(size: 14, weight: FontWeight.w600)
                        .copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      if (discounted) ...[
                        TextSpan(
                          text: formatTl(product.price),
                          style: const TextStyle(decoration: TextDecoration.lineThrough),
                        ),
                        const TextSpan(text: '   '),
                      ],
                      TextSpan(text: '${formatTl(product.actualPrice)} / adet'),
                    ]),
                    style: MarketText.caption(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatTl(item.totalPrice),
                            style: MarketText.price(
                              color: discounted ? MarketPalette.red : MarketPalette.ink,
                            ),
                          ),
                        ),
                      ),
                      MarketStepper(
                        quantity: item.quantity,
                        compact: true,
                        minusIcon: item.quantity == 1
                            ? Icons.delete_outline_rounded
                            : null,
                        onMinus: () => cart.removeFromCart(product),
                        onPlus: () => cart.addToCart(product),
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
      ),
    );
  }

  void _remove(BuildContext context) {
    final product = item.product;
    final quantity = item.quantity;
    cart.updateQuantity(product, 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} sepetten çıkarıldı'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              for (var i = 0; i < quantity; i++) {
                cart.addToCart(product);
              }
            },
          ),
        ),
      );
  }
}

class _PriceSummary extends StatelessWidget {
  final CartViewModel cart;

  const _PriceSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final productSavings = _productSavings(cart);
    return MarketCard(
      shadow: false,
      child: Column(
        children: [
          _SummaryRow(
            label: 'Ürünler (${cart.totalItems})',
            value: formatTl(cart.totalPrice + productSavings),
          ),
          if (productSavings > 0)
            _SummaryRow(
              label: 'Ürün indirimleri',
              value: '-${formatTl(productSavings)}',
              accent: true,
            ),
          if (cart.discountAmount > 0)
            _SummaryRow(
              label: 'Kupon (${cart.appliedCouponCode ?? ''})',
              value: '-${formatTl(cart.discountAmount)}',
              accent: true,
            ),
          const _SummaryRow(label: 'Teslimat', value: 'Ücretsiz', accent: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(child: Text('Toplam', style: MarketText.heading(size: 16))),
              Text(formatTl(cart.finalPrice), style: MarketText.price(size: 22)),
            ],
          ),
        ],
      ),
    );
  }
}

double _productSavings(CartViewModel cart) => cart.items.fold(
      0.0,
      (sum, item) {
        final diff = item.product.price - item.product.actualPrice;
        return diff > 0 ? sum + diff * item.quantity : sum;
      },
    );

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _SummaryRow({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: MarketText.body(color: MarketPalette.muted, size: 14))),
          Text(
            value,
            style: MarketText.label(
              color: accent ? MarketPalette.green : MarketPalette.ink,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt ödeme çubuğu
// ---------------------------------------------------------------------------

class _CheckoutBar extends StatelessWidget {
  final CartViewModel cart;

  const _CheckoutBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    final minimum = context.watch<SettingsViewModel>().minimumOrderAmount;
    final allowed = cart.totalPrice >= minimum;
    final savings = _productSavings(cart) + cart.discountAmount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: MarketPalette.line)),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Toplam', style: MarketText.caption()),
              Text(formatTl(cart.finalPrice), style: MarketText.price(size: 22)),
              if (savings > 0)
                Text(
                  '${formatTl(savings)} kazanç',
                  style: MarketText.caption(color: MarketPalette.green, weight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: allowed ? () => _checkout(context) : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      allowed
                          ? 'Siparişi tamamla'
                          : '${formatTl(minimum - cart.totalPrice)} daha ekle',
                    ),
                    if (allowed) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    if (!auth.isLoggedIn) {
      final result = await context.push<bool>('/login');
      if (result != true && !auth.isLoggedIn) return;
    }
    if (context.mounted) context.push('/create-order');
  }
}

// ---------------------------------------------------------------------------
// Boş sepet
// ---------------------------------------------------------------------------

class _EmptyCart extends StatelessWidget {
  final VoidCallback? onExplore;

  const _EmptyCart({this.onExplore});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 24),
      children: [
        MarketEmptyState(
          icon: Icons.shopping_basket_outlined,
          illustration: const MarketMascot(size: 132),
          title: 'Sepetin boş',
          message:
              'Henüz ürün eklemedin. Atıştırmalıktan temizliğe ihtiyacın olan her şey birkaç dokunuş uzağında.',
          actionLabel: 'Ürünleri keşfet',
          actionIcon: Icons.explore_rounded,
          onAction: onExplore ?? () => context.go('/home'),
        ),
        if (context.watch<AuthViewModel>().isLoggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/saved-carts'),
              icon: const Icon(Icons.bookmarks_outlined, size: 18),
              label: const Text('Favori sepetlerimden doldur'),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CouponRequestCampaignCard(),
        ),
        const _EmptyCartSuggestions(),
      ],
    );
  }
}

/// Boş sepette öne çıkan ürünlerden kısa bir öneri rafı.
class _EmptyCartSuggestions extends StatelessWidget {
  const _EmptyCartSuggestions();

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomePageViewModel>();
    final source = home.featuredProducts.isNotEmpty ? home.featuredProducts : home.products;
    final products = source.where((p) => !p.isHidden && !p.isOutOfStock).take(8).toList();
    if (products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: MarketSectionTitle(
              eyebrow: 'İLHAM AL',
              title: 'Bunlara göz at',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: marketProductCardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: 172,
                child: MarketProductCard(product: products[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kupon: giriş alanı (kendi controller'ı ile; yazılan kod yeniden çizimde
// kaybolmaz), uygulanan kupon, kupon cüzdanı
// ---------------------------------------------------------------------------

class _CouponSection extends StatefulWidget {
  const _CouponSection();

  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final referral = context.watch<ReferralViewModel>();
    if (!referral.couponsLoaded && !referral.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        referral.loadCoupons();
      });
    }

    final applied = cart.appliedCouponCode;
    final walletCount = referral.validCoupons.length;
    return MarketCard(
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MarketIconTile(icon: Icons.confirmation_number_outlined, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Text('Kupon', style: MarketText.heading(size: 16))),
              TextButton(
                onPressed: () => _showCouponWallet(context, referral, cart),
                child: Text(walletCount > 0 ? 'Kuponlarım ($walletCount)' : 'Kuponlarım'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (applied != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: MarketPalette.greenSoft,
                borderRadius: BorderRadius.circular(MarketRadius.md),
                border: Border.all(color: MarketPalette.greenLine),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: MarketPalette.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applied, style: MarketText.code(size: 14)),
                        Text(
                          cart.appliedCoupon?['requiresDeliveryPoint'] == true
                              ? 'Teslimat noktasında doğrulanacak'
                              : '${formatTl(cart.discountAmount)} indirim uygulandı',
                          style: MarketText.caption(color: MarketPalette.greenDark),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: cart.removeCoupon,
                    style: TextButton.styleFrom(foregroundColor: MarketPalette.red),
                    child: const Text('Kaldır'),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _apply(cart),
                    style: MarketText.label(size: 14, weight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Kupon kodu',
                      prefixIcon: Icon(Icons.discount_outlined),
                      fillColor: MarketPalette.canvas,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: cart.isValidatingCoupon ? null : () => _apply(cart),
                    child: cart.isValidatingCoupon
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Uygula'),
                  ),
                ),
              ],
            ),
            if (cart.couponError != null) ...[
              const SizedBox(height: 8),
              Text(
                cart.couponError!,
                style: MarketText.caption(color: MarketPalette.red, weight: FontWeight.w600),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _apply(CartViewModel cart) async {
    FocusScope.of(context).unfocus();
    final success = await cart.applyCoupon(_controller.text);
    if (success && mounted) _controller.clear();
  }
}

/// Sepete özel önerilen kupon veya cüzdandaki ilk geçerli kupon.
class _AvailableCouponBanner extends StatelessWidget {
  final CartViewModel cart;

  const _AvailableCouponBanner({required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart.appliedCouponCode != null) return const SizedBox.shrink();

    String? code;
    var detail = '';
    final recommended = cart.recommendedCoupon;
    if (recommended != null) {
      code = recommended['code']?.toString();
      final discount = (recommended['calculatedDiscount'] as num?)?.toDouble() ?? 0;
      detail = '${formatTl(discount)} kazanç';
    } else {
      final coupons = context.watch<ReferralViewModel>().validCoupons;
      if (coupons.isNotEmpty) {
        code = coupons.first.code;
        detail = coupons.first.discountText;
      }
    }
    if (code == null || code.isEmpty) return const SizedBox.shrink();
    final couponCode = code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MarketPalette.limeSoft, MarketPalette.greenSoft],
          ),
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          border: Border.all(color: MarketPalette.limeLine),
        ),
        child: Row(
          children: [
            const MarketIconTile(
              icon: Icons.auto_awesome_rounded,
              size: 40,
              background: MarketPalette.lime,
              foreground: MarketPalette.greenDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommended != null
                        ? 'Sepetin için en iyi kupon'
                        : 'Kullanılabilir kuponun var',
                    style: MarketText.caption(color: MarketPalette.greenDark, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    couponCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.code(color: MarketPalette.greenDeep, size: 13),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.caption(color: MarketPalette.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => cart.applyCoupon(couponCode),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: MarketPalette.greenDeep,
              ),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCouponWallet(
  BuildContext context,
  ReferralViewModel referral,
  CartViewModel cart,
) async {
  if (!referral.couponsLoaded) await referral.loadCoupons(force: true);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: .76,
      minChildSize: .5,
      maxChildSize: .92,
      expand: false,
      builder: (context, controller) {
        final coupons = referral.validCoupons;
        return Container(
          decoration: const BoxDecoration(
            color: MarketPalette.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: MarketPalette.lineStrong,
                  borderRadius: BorderRadius.circular(MarketRadius.lg),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                child: Row(
                  children: [
                    const MarketIconTile(icon: Icons.local_activity_outlined, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kupon cüzdanım', style: MarketText.title(size: 22)),
                          Text('${coupons.length} aktif fırsat', style: MarketText.caption(size: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: coupons.isEmpty
                    ? ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: const [
                          MarketEmptyState(
                            icon: Icons.local_activity_outlined,
                            title: 'Henüz kuponun yok',
                            message:
                                'Aktif kampanyaya katılarak kişisel kupon kazanabilirsin.',
                          ),
                          _CouponRequestCampaignCard(),
                        ],
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: coupons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _CouponCard(
                          coupon: coupons[index],
                          cart: cart,
                          sheetContext: sheetContext,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final CartViewModel cart;
  final BuildContext sheetContext;

  const _CouponCard({
    required this.coupon,
    required this.cart,
    required this.sheetContext,
  });

  @override
  Widget build(BuildContext context) {
    final expiry =
        '${coupon.expirationDate.day.toString().padLeft(2, '0')}.${coupon.expirationDate.month.toString().padLeft(2, '0')}.${coupon.expirationDate.year}';
    final conditions = <String>[
      if (coupon.minimumOrderAmount > 0)
        'En az ${formatTlShort(coupon.minimumOrderAmount)} sepet',
      if (coupon.maximumDiscount > 0)
        'En fazla ${formatTlShort(coupon.maximumDiscount)} indirim',
      if (coupon.deliveryPoints.isNotEmpty) 'Teslimat noktasına özel',
      if (coupon.firstOrderOnly) 'İlk siparişe özel',
      if (coupon.newUsersOnly) 'Yeni kullanıcılara özel',
    ];
    final globalUse = coupon.remainingGlobalUses == null
        ? 'Sınırsız kullanım'
        : '${coupon.remainingGlobalUses} kullanım kaldı';

    Widget info(IconData icon, String text) => MarketPill(
          icon: icon,
          label: text,
          background: MarketPalette.surfaceMuted,
          foreground: MarketPalette.inkSoft,
        );

    return MarketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  coupon.discountText,
                  style: MarketText.title(color: MarketPalette.greenDark, size: 22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MarketPalette.greenSoft,
                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                  border: Border.all(color: MarketPalette.greenLine),
                ),
                child: Text(coupon.code, style: MarketText.code(size: 13)),
              ),
            ],
          ),
          if (coupon.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(coupon.description, style: MarketText.body(color: MarketPalette.muted, size: 13)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              info(Icons.event_outlined, 'Son gün $expiry'),
              info(Icons.people_outline, globalUse),
              info(Icons.person_outline, 'Kişisel ${coupon.remainingUses} hak'),
              for (final text in conditions) info(Icons.check_circle_outline, text),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cart.isValidatingCoupon
                  ? null
                  : () async {
                      final success = await cart.applyCoupon(coupon.code);
                      if (success && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
              child: const Text('Kuponu uygula'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yönetici tarafından açılan topluluk kupon kampanyası
// ---------------------------------------------------------------------------

class _CouponRequestCampaignCard extends StatefulWidget {
  const _CouponRequestCampaignCard();

  @override
  State<_CouponRequestCampaignCard> createState() =>
      _CouponRequestCampaignCardState();
}

class _CouponRequestCampaignCardState
    extends State<_CouponRequestCampaignCard> {
  final _api = ApiService();
  Map<String, dynamic>? _campaign;
  bool _loading = true;
  bool _requesting = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final campaign = await _api.getActiveCouponRequestCampaign();
    if (mounted) {
      setState(() {
        _campaign = campaign;
        _loading = false;
      });
    }
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    final response = await _api.requestCouponCampaign();
    if (!mounted) return;
    setState(() => _requesting = false);
    showMarketSnack(
      context,
      response['message'] ?? 'İşlem tamamlandı',
      error: response['success'] != true,
      aboveNavigation: true,
    );
    if (response['success'] == true) {
      setState(
          () => _campaign = Map<String, dynamic>.from(response['campaign']));
    }
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _campaign == null) return const SizedBox.shrink();
    final campaign = _campaign!;
    final target = (campaign['targetCount'] ?? 0) as num;
    final current = (campaign['weightedCount'] ?? 0) as num;
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final requested = campaign['userRequested'] == true;
    final eligible = campaign['isEligible'] != false;
    final canJoin = CommunityCampaign.canJoin(campaign);
    final minimumOrder = (campaign['minimumOrderAmount'] ?? 0) as num;

    Widget chip(IconData icon, String label) => MarketPill(
          icon: icon,
          label: label,
          background: Colors.white,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: MarketCard(
        color: MarketPalette.limeSoft,
        borderColor: canJoin ? MarketPalette.green : MarketPalette.limeLine,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MarketIconTile(
                  icon: Icons.redeem_rounded,
                  size: 40,
                  background: Colors.white,
                  foreground: MarketPalette.greenDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign['title'] ?? 'Topluluk indirimi',
                        style: MarketText.heading(color: MarketPalette.greenDeep),
                      ),
                      if (canJoin)
                        Text(
                          'Şartı sağlıyorsun, katılabilirsin',
                          style: MarketText.caption(
                            color: MarketPalette.greenDark,
                            weight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                MarketPill(
                  label: '%${campaign['discountPercentage']}',
                  background: MarketPalette.greenDeep,
                  foreground: Colors.white,
                ),
              ],
            ),
            if (_expanded) ...[
            const SizedBox(height: 12),
            Text(
              '${campaign['targetCount']} katkı puanına ulaşınca %${campaign['discountPercentage']} indirim açılacak. Yalnızca katılanlar yararlanır.',
              style: MarketText.body(color: MarketPalette.inkSoft, size: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                chip(Icons.verified_user_outlined,
                    campaign['orderRequirementLabel'] ?? 'Katılım şartı'),
                chip(Icons.event_outlined, 'Son ${_dateLabel(campaign['endsAt'])}'),
                if (minimumOrder > 0)
                  chip(Icons.shopping_basket_outlined,
                      'En az ${formatTlShort(minimumOrder)} sepet'),
                if ((campaign['requesterWeight'] ?? 1) == 2)
                  chip(Icons.group_add_outlined, 'Davet katkın 2 puan'),
              ],
            ),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(MarketRadius.xs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${current.toInt()} / ${target.toInt()} katkı puanı',
                        style: MarketText.label(size: 13),
                      ),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(MarketRadius.xs),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _expanded ? 'Ayrıntıları gizle' : 'Nasıl çalışır?',
                                style: MarketText.label(
                                  color: MarketPalette.greenDark,
                                  size: 12,
                                ),
                              ),
                              Icon(
                                _expanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: MarketPalette.greenDark,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed:
                      requested || !eligible || _requesting ? null : _request,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: MarketPalette.greenDeep,
                  ),
                  child: Text(_requesting
                      ? 'Gönderiliyor...'
                      : requested
                          ? 'İsteğin alındı'
                          : eligible
                              ? 'Hemen katıl'
                              : 'Şartı tamamla'),
                ),
              ],
            ),
            if (!eligible) ...[
              const SizedBox(height: 8),
              Text(
                'Katılmak için: ${campaign['eligibilityMessage']}',
                style: MarketText.caption(color: MarketPalette.orangeInk, weight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
