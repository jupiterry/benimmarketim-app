import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/abandon_reason_sheet.dart';
import 'widgets/community_campaign.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/market_product_card.dart';
import 'widgets/market_mascot.dart';
import 'widgets/market_ui.dart';
import 'widgets/save_cart_dialog.dart';
import '../services/image_url.dart';

/// Sepet sekmesinde bildirim çubuğu, sayfanın altındaki ödeme çubuğunun
/// üstünde görünsün diye bırakılan boşluk (çubuğun yaklaşık yüksekliği;
/// büyük yazıda çubuk da uzar).
double _checkoutBarGap(BuildContext context) =>
    28 + math.max(54.0, MediaQuery.textScalerOf(context).scale(59));

/// Sepette ürün varken (ödeme çubuğu görünürken) bildirimin kaldırılacağı pay.
double _snackGap(BuildContext context) =>
    context.read<CartViewModel>().items.isEmpty ? 0 : _checkoutBarGap(context);

class CartPage extends StatefulWidget {
  final VoidCallback? onExplore;

  const CartPage({super.key, this.onExplore});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  /// "Bunu da ekle" rafı: en az tutarın altındayken alttaki düğme buraya kaydırır.
  final _suggestionsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final items = cart.items;
    final unitCount = cart.totalItems;
    final gutter = MarketSpace.gutterOf(context);
    // Sekmede geri düğmesi yok; ayrı sayfa olarak açıldıysa (/cart) var.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Sepet boşken içerik alttaki menünün arkasına kadar uzanır.
    final bottomInset =
        items.isEmpty ? MediaQuery.paddingOf(context).bottom : 0.0;

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const MarketScrollPhysics(),
              slivers: [
                // Başlık içerikle birlikte kayar: küçük ekranda ürünlere yer açılır.
                SliverToBoxAdapter(
                  child: MarketHeader(
                    title: 'Sepetim',
                    subtitle: items.isEmpty
                        ? 'Alışverişe başlamaya hazır mısın?'
                        : '$unitCount ürün • ${items.length} çeşit',
                    icon: Icons.shopping_bag_rounded,
                    showBack: canPop,
                    compact: true,
                  ),
                ),
                if (items.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: bottomInset + 24),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyCart(onExplore: widget.onExplore),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 24),
                    // Tembel liste değil: "Bunu da ekle" rafı ekranın altında
                    // kalsa da kurulur, alttaki "daha ekle" düğmesi ona kayar.
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _StoreClosedNotice(),
                          const _MinimumOrderProgress(),
                          // Sepetteki ürünler tek kartta, ilk bakışta görünür.
                          MarketCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  if (i > 0)
                                    const Divider(
                                        height: 1, indent: 16, endIndent: 16),
                                  _CartItemCard(item: items[i], cart: cart),
                                ],
                              ],
                            ),
                          ),
                          _CartActions(
                            cart: cart,
                            onCleared: _askAbandonReason,
                          ),
                          _MinimumOrderSuggestions(anchorKey: _suggestionsKey),
                          const SizedBox(height: MarketSpace.md),
                          const _CouponSection(),
                          const SizedBox(height: MarketSpace.lg),
                          _PriceSummary(cart: cart),
                          // İkincil tanıtım: fiyat özetinin altında durur.
                          const _CouponRequestCampaignCard(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            _CheckoutBar(
              cart: cart,
              onAddMore: _showSuggestions,
            ),
        ],
      ),
    );
  }

  /// Sepet boşaltılınca sorulan "neden?" sorusu sayfanın kendi bağlamıyla
  /// açılır: düğmelerin bulunduğu satır, sepet boşalınca ekrandan kalkar.
  Future<void> _askAbandonReason() async {
    if (mounted) await maybeAskAbandonReason(context);
  }

  /// En az tutarın altındayken: öneri rafına kaydırır; öneri yoksa
  /// alışverişe (ana sayfaya) döner.
  void _showSuggestions() {
    final target = _suggestionsKey.currentContext;
    if (target == null) {
      final explore = widget.onExplore;
      if (explore != null) {
        explore();
      } else {
        context.go('/home');
      }
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: .1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Ürünlerin altındaki iki eylem: kaydetmek (güvenli) ve boşaltmak (kırmızı,
/// onay ister). Başlıktaki adsız simgelerin yerini alır.
class _CartActions extends StatelessWidget {
  final CartViewModel cart;

  /// Sepet boşaltıldıktan sonra (bu satır ekrandan kalkmış olabilir).
  final Future<void> Function() onCleared;

  const _CartActions({required this.cart, required this.onCleared});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => _save(context),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size(0, MarketSize.control),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.bookmark_add_outlined, size: 20),
            label: const Text('Sepeti kaydet'),
          ),
          TextButton.icon(
            onPressed: () => _confirmClear(context),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.red,
              minimumSize: const Size(0, MarketSize.control),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            label: const Text('Sepeti boşalt'),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    showSaveCartDialog(
      context,
      bottomGap: _checkoutBarGap(context),
      items: [
        for (final item in cart.items)
          {
            'productId': item.product.id,
            'quantity': item.quantity > 20 ? 20 : item.quantity,
          },
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showMarketConfirm(
      context,
      icon: Icons.delete_sweep_outlined,
      title: 'Sepet boşaltılsın mı?',
      message:
          'Sepetindeki ${cart.totalItems} ürün çıkarılacak. Bu işlem geri alınamaz.',
      confirmLabel: 'Sepeti boşalt',
      tone: MarketTone.danger,
    );
    if (confirmed) {
      cart.clearCart();
      await onCleared();
    }
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
  /// Raf gösterildiğinde ona bağlanan anahtar (alttaki düğme buraya kaydırır).
  final GlobalKey anchorKey;

  const _MinimumOrderSuggestions({required this.anchorKey});

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
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.only(top: MarketSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Bunu da ekle', style: MarketText.heading()),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatTl(gap)} daha ekleyince sipariş verebilirsin',
            style: MarketText.caption(size: 12),
          ),
          const SizedBox(height: MarketSpace.md),
          SizedBox(
            height: 160 + (textScale - 1) * 120,
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

  void _add(BuildContext context) {
    HapticFeedback.lightImpact();
    context.read<CartViewModel>().addToCart(product);
    // Kart listeden hemen kalkar; ekleme bir bildirimle doğrulanır.
    showMarketSnack(
      context,
      '${productDisplayName(product.name)} sepete eklendi',
      icon: Icons.add_shopping_cart_rounded,
      bottomGap: _checkoutBarGap(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: MarketCard(
        shadow: false,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
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
                        optimizedImageUrl(
                          product.image,
                          width: MarketImageSize.thumb,
                        ),
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
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                productDisplayName(product.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MarketText.label(size: 12, weight: FontWeight.w600),
              ),
            ),
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
                // 40'lık görünür düğme, 44'lük dokunma alanı
                Semantics(
                  button: true,
                  label: '${productDisplayName(product.name)} sepete ekle',
                  excludeSemantics: true,
                  onTap: () => _add(context),
                  child: Tooltip(
                    message: 'Sepete ekle',
                    child: InkResponse(
                      onTap: () => _add(context),
                      radius: 24,
                      child: SizedBox(
                        width: MarketSize.control,
                        height: MarketSize.control,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: MarketPalette.green,
                              borderRadius:
                                  BorderRadius.circular(MarketRadius.sm),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 22),
                          ),
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
    final name = productDisplayName(product.name);

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
                  // Ürün kartlarındaki gibi beyaz "stüdyo" kutusu: beyaz zeminli
                  // katalog fotoğrafları gri kutuda dikdörtgen gibi görünmesin.
                  decoration: BoxDecoration(
                    color: MarketPalette.surface,
                    borderRadius: BorderRadius.circular(MarketRadius.md),
                    border: Border.all(color: MarketPalette.line),
                  ),
                  child: product.image.isNotEmpty
                      ? Image.network(
                          optimizedImageUrl(
                            product.image,
                            width: MarketImageSize.thumb,
                          ),
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            color: MarketPalette.subtle,
                          ),
                        )
                      : const Icon(Icons.inventory_2_outlined,
                          color: MarketPalette.subtle),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.label(size: 14, weight: FontWeight.w600)
                            .copyWith(height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      // Birim fiyat (kg ürünlerde de doğru okunsun diye
                      // "adet" yazılmaz); 1'den fazlaysa "2 × ₺36,90".
                      Text.rich(
                        TextSpan(children: [
                          if (item.quantity > 1)
                            TextSpan(text: '${item.quantity} × '),
                          if (discounted) ...[
                            TextSpan(
                              text: formatTl(product.price),
                              style: MarketText.oldPrice(),
                            ),
                            const TextSpan(text: '  '),
                          ],
                          TextSpan(text: formatTl(product.actualPrice)),
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
                                  color: discounted
                                      ? MarketPalette.red
                                      : MarketPalette.ink,
                                ),
                              ),
                            ),
                          ),
                          MarketStepper(
                            quantity: item.quantity,
                            compact: true,
                            semanticLabel: '$name adedi',
                            minusIcon: item.quantity == 1
                                ? Icons.delete_outline_rounded
                                : null,
                            // 1 adetteyken çöp kutusu: kaydırarak silmeyle
                            // aynı "Geri al" bildirimi çıkar.
                            onMinus: item.quantity == 1
                                ? () => _remove(context)
                                : () => cart.removeFromCart(product),
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
    HapticFeedback.lightImpact();
    cart.updateQuantity(product, 0);
    showMarketSnack(
      context,
      '${productDisplayName(product.name)} sepetten çıkarıldı',
      icon: Icons.remove_shopping_cart_outlined,
      actionLabel: 'Geri al',
      // Tek yazmayla eski adede döner.
      onAction: () => cart.addQuantity(product, quantity),
      bottomGap: cart.items.isEmpty ? 0 : _checkoutBarGap(context),
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

  /// En az tutarın altındayken düğmeye basılınca (öneri rafına kaydırır).
  final VoidCallback onAddMore;

  const _CheckoutBar({required this.cart, required this.onAddMore});

  @override
  Widget build(BuildContext context) {
    final minimum = context.watch<SettingsViewModel>().minimumOrderAmount;
    final allowed = cart.totalPrice >= minimum;
    final savings = _productSavings(cart) + cart.discountAmount;

    // Kısa ekranda (ör. 320x568) çubuk alttaki menüyle birlikte daha az yer
    // kaplasın diye iç boşluk azalır.
    final short = MediaQuery.sizeOf(context).height < 640;
    return MarketBottomBar(
      padding: short
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: allowed
          ? MarketTotalAction(
              label: 'Toplam',
              amount: cart.finalPrice,
              savings: savings,
              actionLabel: 'Siparişi tamamla',
              onPressed: () => _checkout(context),
            )
          : _BelowMinimumAction(
              amount: cart.finalPrice,
              savings: savings,
              gap: minimum - cart.totalPrice,
              onPressed: onAddMore,
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

/// En az sipariş tutarının altındayken: pasif gri buton yerine eksik tutarı
/// söyleyen ve önerilere götüren turuncu buton. Ödeme adımına yine geçilmez.
class _BelowMinimumAction extends StatelessWidget {
  final double amount;
  final double savings;
  final double gap;
  final VoidCallback onPressed;

  const _BelowMinimumAction({
    required this.amount,
    required this.savings,
    required this.gap,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Toplam',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.caption()),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatTl(amount), style: MarketText.price(size: 22)),
                ),
                if (savings > 0)
                  Text(
                    '${formatTl(savings)} kazanç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.caption(
                        color: MarketPalette.greenDark, weight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.button),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: MarketPalette.orangeSoft,
                foregroundColor: MarketPalette.orangeInk,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${formatTl(gap)} daha ekle',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    final gutter = MarketSpace.gutterOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 20),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/saved-carts'),
                icon: const Icon(Icons.bookmarks_outlined, size: 18),
                label: const Text('Favori sepetlerimden doldur'),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: const _CouponRequestCampaignCard(),
          ),
          const _EmptyCartSuggestions(),
        ],
      ),
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
    final gutter = MarketSpace.gutterOf(context);

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: const MarketSectionTitle(
              eyebrow: 'İLHAM AL',
              title: 'Bunlara göz at',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: marketProductCardExtent(context),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: 172,
                child: MarketProductCard(product: products[index], hero: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kupon: tek kart. Uygulanan kupon, sepete en uygun kupon (tek "Uygula") ya
// da kod alanı; kod alanının kendi controller'ı var (yazılan kod yeniden
// çizimde kaybolmaz). "Kuponlarım" cüzdanı açar.
// ---------------------------------------------------------------------------

/// Sepete önerilen kupon: sunucunun sepete özel önerisi ya da cüzdandaki,
/// en az sepet tutarı tutan ilk geçerli kupon.
({String code, String detail, bool best})? _cartCouponSuggestion(
    CartViewModel cart, ReferralViewModel referral) {
  if (cart.appliedCouponCode != null) return null;
  final recommended = cart.recommendedCoupon;
  final recommendedCode = recommended?['code']?.toString();
  if (recommendedCode != null && recommendedCode.isNotEmpty) {
    final discount = (recommended?['calculatedDiscount'] as num?)?.toDouble() ?? 0;
    return (
      code: recommendedCode,
      detail: discount > 0 ? '${formatTl(discount)} kazanç' : 'Sepetine uygun kupon',
      best: true,
    );
  }
  for (final coupon in referral.validCoupons) {
    if (coupon.minimumOrderAmount <= cart.totalPrice) {
      return (code: coupon.code, detail: coupon.discountText, best: false);
    }
  }
  return null;
}

class _CouponSection extends StatefulWidget {
  const _CouponSection();

  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  final _controller = TextEditingController();

  /// Önerilen kupon varken elle kod alanı açıldı mı.
  bool _manualOpen = false;

  /// Doğrulanan kod: hangi "Uygula" düğmesinin döneceğini belirler.
  String? _pendingCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyCode(CartViewModel cart, String code) async {
    FocusScope.of(context).unfocus();
    setState(() => _pendingCode = code);
    final success = await cart.applyCoupon(code);
    if (!mounted) return;
    setState(() {
      _pendingCode = null;
      if (success) {
        _controller.clear();
        _manualOpen = false;
      }
    });
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
    final suggestion = _cartCouponSuggestion(cart, referral);
    final validating = cart.isValidatingCoupon;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final manualField = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyCode(cart, _controller.text),
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
          child: _CouponApplyButton(
            loading: validating && _pendingCode == _controller.text,
            // Önerilen kuponun "Uygula"sı ana eylem kalır; bu ikincil görünür.
            secondary: suggestion != null,
            onPressed: validating ? null : () => _applyCode(cart, _controller.text),
          ),
        ),
      ],
    );

    return MarketCard(
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MarketIconTile(icon: Icons.confirmation_number_outlined, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Kupon', style: MarketText.heading(size: 16)),
                ),
              ),
              TextButton(
                onPressed: () => _showCouponWallet(context),
                style: TextButton.styleFrom(minimumSize: const Size(0, MarketSize.control)),
                child: Text(walletCount > 0 ? 'Kuponlarım ($walletCount)' : 'Kuponlarım'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (applied != null)
            _AppliedCouponRow(cart: cart, code: applied)
          else ...[
            if (suggestion != null) ...[
              _SuggestedCouponRow(
                title: suggestion.best ? 'Sepetin için en iyi kupon' : 'Kullanılabilir kuponun var',
                code: suggestion.code,
                detail: suggestion.detail,
                loading: validating && _pendingCode == suggestion.code,
                onApply: validating ? null : () => _applyCode(cart, suggestion.code),
              ),
              AnimatedSize(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _manualOpen
                    ? Padding(padding: const EdgeInsets.only(top: 12), child: manualField)
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _manualOpen = true),
                          style: TextButton.styleFrom(
                            foregroundColor: MarketPalette.inkSoft,
                            minimumSize: const Size(0, MarketSize.control),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          icon: const Icon(Icons.keyboard_rounded, size: 18),
                          label: const Text('Başka bir kod gir'),
                        ),
                      ),
              ),
            ] else
              manualField,
            if (cart.couponError != null && !validating) ...[
              const SizedBox(height: 8),
              Text(
                cart.couponError!,
                style: MarketText.caption(color: MarketPalette.red, weight: FontWeight.w700),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AppliedCouponRow extends StatelessWidget {
  final CartViewModel cart;
  final String code;

  const _AppliedCouponRow({required this.cart, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
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
                Text(code, style: MarketText.code(size: 14)),
                Text(
                  cart.appliedCoupon?['requiresDeliveryPoint'] == true && cart.discountAmount <= 0
                      ? 'Teslimat noktasında doğrulanacak'
                      : '${formatTl(cart.discountAmount)} indirim uygulandı',
                  style: MarketText.caption(color: MarketPalette.greenDark),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: cart.isValidatingCoupon ? null : cart.removeCoupon,
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.red,
              minimumSize: const Size(MarketSize.control, MarketSize.control),
            ),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
  }
}

class _SuggestedCouponRow extends StatelessWidget {
  final String title;
  final String code;
  final String detail;
  final bool loading;
  final VoidCallback? onApply;

  const _SuggestedCouponRow({
    required this.title,
    required this.code,
    required this.detail,
    required this.loading,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: MarketPalette.limeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.limeLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: MarketPalette.greenDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MarketText.caption(color: MarketPalette.greenDark, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
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
          _CouponApplyButton(loading: loading, onPressed: onApply),
        ],
      ),
    );
  }
}

/// Kuponun tek "Uygula" düğmesi: yeşil, en az 44 pt; doğrulanırken dönen
/// beyaz gösterge (yeşil kalır).
class _CouponApplyButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  /// Açık yeşil (ikincil) görünüm: ekranda ana "Uygula" başka yerdeyken.
  final bool secondary;

  const _CouponApplyButton({
    required this.loading,
    required this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = secondary ? MarketPalette.greenSoft : MarketPalette.green;
    final foreground = secondary ? MarketPalette.greenDark : Colors.white;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, MarketSize.control),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: loading ? background : null,
        disabledForegroundColor: loading ? foreground : null,
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          : const Text('Uygula'),
    );
  }
}

/// Kupon cüzdanı hemen açılır; kuponlar yüklenmediyse sayfanın içinde yüklenir.
Future<void> _showCouponWallet(BuildContext context) {
  final referral = context.read<ReferralViewModel>();
  final cart = context.read<CartViewModel>();
  return showMarketSheet<void>(
    context,
    builder: (sheetContext) => _CouponWalletSheet(
      referral: referral,
      cart: cart,
      hostContext: context,
    ),
  );
}

class _CouponWalletSheet extends StatefulWidget {
  final ReferralViewModel referral;
  final CartViewModel cart;

  /// Sepet sayfasının bağlamı: sayfa kapandıktan sonra bildirim orada çıkar.
  final BuildContext hostContext;

  const _CouponWalletSheet({
    required this.referral,
    required this.cart,
    required this.hostContext,
  });

  @override
  State<_CouponWalletSheet> createState() => _CouponWalletSheetState();
}

class _CouponWalletSheetState extends State<_CouponWalletSheet> {
  bool _loading = false;
  String? _pendingCode;
  String? _errorCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.referral.couponsLoaded) _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await widget.referral.loadCoupons(force: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _apply(Coupon coupon) async {
    final cart = widget.cart;
    if (cart.isValidatingCoupon) return;
    setState(() {
      _pendingCode = coupon.code;
      _errorCode = null;
      _error = null;
    });
    final success = await cart.applyCoupon(coupon.code);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      final host = widget.hostContext;
      if (host.mounted) {
        showMarketSnack(
          host,
          cart.discountAmount > 0
              ? 'Kupon uygulandı: ${formatTl(cart.discountAmount)} indirim'
              : 'Kupon uygulandı. İndirim teslimat noktasında hesaplanacak.',
          icon: Icons.local_activity_rounded,
          bottomGap: _snackGap(host),
        );
      }
      return;
    }
    setState(() {
      _pendingCode = null;
      _errorCode = coupon.code;
      _error = cart.couponError ?? 'Kupon uygulanamadı. Tekrar dener misin?';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.referral, widget.cart]),
      builder: (context, _) {
        final referral = widget.referral;
        final coupons = referral.validCoupons;
        final loading = _loading && !referral.couponsLoaded;
        final failed = !_loading && !referral.couponsLoaded;

        final Widget body;
        if (loading) {
          body = const MarketListSkeleton(count: 3);
        } else if (failed) {
          body = MarketEmptyState.error(onRetry: _reload);
        } else if (coupons.isEmpty) {
          body = const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarketEmptyState(
                icon: Icons.local_activity_outlined,
                title: 'Henüz kuponun yok',
                message: 'Aktif kampanyaya katılarak kişisel kupon kazanabilirsin.',
              ),
              _CouponRequestCampaignCard(),
            ],
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < coupons.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _CouponCard(
                  coupon: coupons[i],
                  cart: widget.cart,
                  loading: _pendingCode == coupons[i].code && widget.cart.isValidatingCoupon,
                  error: _errorCode == coupons[i].code ? _error : null,
                  onApply: () => _apply(coupons[i]),
                ),
              ],
            ],
          );
        }

        return MarketSheetScaffold(
          header: MarketSheetHeader(
            title: 'Kupon cüzdanım',
            subtitle: loading
                ? 'Kuponların yükleniyor'
                : coupons.isEmpty
                    ? null
                    : '${coupons.length} aktif fırsat',
          ),
          body: body,
          bodyPadding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        );
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final CartViewModel cart;
  final bool loading;
  final String? error;
  final VoidCallback onApply;

  const _CouponCard({
    required this.coupon,
    required this.cart,
    required this.loading,
    required this.error,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final expiry =
        '${coupon.expirationDate.day.toString().padLeft(2, '0')}.${coupon.expirationDate.month.toString().padLeft(2, '0')}.${coupon.expirationDate.year}';
    // Sepet, kuponun en az tutarını tutmuyorsa düğme eksik tutarı söyler.
    final gap = coupon.minimumOrderAmount - cart.totalPrice;
    final blocked = gap > 0;
    final applied = cart.appliedCouponCode?.toUpperCase() == coupon.code.toUpperCase();
    final conditions = <String>[
      if (coupon.maximumDiscount > 0)
        'En fazla ${formatTlShort(coupon.maximumDiscount)} indirim',
      if (coupon.deliveryPoints.isNotEmpty) 'Teslimat noktasına özel',
      if (coupon.firstOrderOnly) 'İlk siparişe özel',
      if (coupon.newUsersOnly) 'Yeni kullanıcılara özel',
    ];
    final globalUse = coupon.remainingGlobalUses == null
        ? 'Sınırsız kullanım'
        : '${coupon.remainingGlobalUses} kullanım kaldı';

    Widget info(IconData icon, String text, {bool warn = false}) => MarketPill(
          icon: icon,
          label: text,
          background: warn ? MarketPalette.orangeSoft : MarketPalette.surfaceMuted,
          foreground: warn ? MarketPalette.orangeInk : MarketPalette.inkSoft,
        );

    final Widget button;
    if (applied) {
      button = FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Sepetinde uygulandı'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.control),
          disabledBackgroundColor: MarketPalette.greenSoft,
          disabledForegroundColor: MarketPalette.greenDark,
        ),
      );
    } else if (blocked) {
      button = FilledButton.tonal(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.control),
          disabledBackgroundColor: MarketPalette.orangeSoft,
          disabledForegroundColor: MarketPalette.orangeInk,
        ),
        child: Text(
          '${formatTl(gap)} daha ekleyince kullanabilirsin',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      button = FilledButton(
        onPressed: loading || cart.isValidatingCoupon ? null : onApply,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.control),
          disabledBackgroundColor: loading ? MarketPalette.green : null,
          disabledForegroundColor: loading ? Colors.white : null,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Kuponu uygula'),
      );
    }

    return MarketCard(
      shadow: false,
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
              const SizedBox(width: 8),
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
              if (coupon.minimumOrderAmount > 0)
                info(Icons.shopping_basket_outlined,
                    'En az ${formatTlShort(coupon.minimumOrderAmount)} sepet',
                    warn: blocked),
              info(Icons.event_outlined, 'Son gün $expiry'),
              info(Icons.people_outline, globalUse),
              info(Icons.person_outline, 'Kişisel ${coupon.remainingUses} hak'),
              for (final text in conditions) info(Icons.check_circle_outline, text),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: button),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: MarketText.caption(color: MarketPalette.red, weight: FontWeight.w700),
            ),
          ],
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
      bottomGap: _snackGap(context),
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
            const SizedBox(height: 6),
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
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: MarketSize.control),
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
                    minimumSize: const Size(0, MarketSize.control),
                    backgroundColor: MarketPalette.greenDeep,
                  ),
                  child: Text(_requesting
                      ? 'Gönderiliyor…'
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
