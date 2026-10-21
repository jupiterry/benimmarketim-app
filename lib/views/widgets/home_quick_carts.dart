import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/cart_fill.dart';
import '../../services/image_url.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import 'market_ui.dart';

/// Ana sayfa aşağı çekilip yenilendiğinde artırılır; sipariş kartı, görevler
/// ve teslimat yeri yeniden yüklenir.
final ValueNotifier<int> homeRefreshSignal = ValueNotifier<int>(0);

const _activeStatuses = {'Hazırlanıyor', 'Yolda'};

/// Ana sayfanın en üstündeki sipariş alanı. Son 24 saatte verilmiş, yolda
/// ya da hazırlanan bir sipariş varsa onun durumu; yoksa son siparişi tek
/// dokunuşla tekrarlama kartı gösterilir. Giriş yapılmamışsa yer kaplamaz.
class HomeOrderSlot extends StatefulWidget {
  const HomeOrderSlot({super.key});

  @override
  State<HomeOrderSlot> createState() => _HomeOrderSlotState();
}

class _HomeOrderSlotState extends State<HomeOrderSlot> {
  List<Order> _active = const [];
  Order? _lastOrder;
  String? _loadedForUser;
  bool _adding = false;
  bool _visible = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    homeRefreshSignal.addListener(_reload);
    _lifecycle = AppLifecycleListener(onResume: _refreshActive);
  }

  @override
  void dispose() {
    homeRefreshSignal.removeListener(_reload);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ana sayfa yeniden görünür olunca (ör. Siparişlerim'den, başka bir
    // sekmeden ya da sayfadan dönünce) süren siparişin durumu tazelenir:
    // iptal edilen ya da teslim edilen sipariş "yolda" görünmeye devam etmez.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      if (visible) _refreshActive();
    }
    // Giriş durumu değişince (ör. açılışta profil yüklenince) yeniden yüklenir
    // didChangeDependencies içinde context.watch hata ayıklama modunda
    // izin verilmediği için Provider.of kullanılır.
    final auth = Provider.of<AuthViewModel>(context);
    final userId = auth.isLoggedIn ? auth.user?.id : null;
    if (userId == _loadedForUser) return;
    _loadedForUser = userId;
    if (userId == null) {
      _active = const [];
      _lastOrder = null;
    } else {
      _load(userId);
    }
  }

  void _reload() {
    final userId = _loadedForUser;
    if (userId != null) _load(userId);
  }

  /// Yalnızca süren bir sipariş gösteriliyorsa yeniden yükler (durumu
  /// değişebilecek tek kart odur; her sayfa dönüşünde istek atılmaz).
  void _refreshActive() {
    if (mounted && _active.isNotEmpty) _reload();
  }

  Future<void> _load(String userId) async {
    final active = <Order>[];
    Order? latest;
    try {
      final orders = await ApiService().getUserOrders();
      final since = DateTime.now().subtract(const Duration(hours: 24));
      for (final order in orders) {
        if (_activeStatuses.contains(order.status)) {
          if (order.createdAt.isAfter(since)) active.add(order);
          continue;
        }
        if (order.status == 'İptal Edildi' || order.products.isEmpty) continue;
        if (latest == null || order.createdAt.isAfter(latest.createdAt)) {
          latest = order;
        }
      }
    } catch (_) {
      // Siparişler alınamazsa kart gösterilmez; ana sayfa etkilenmez
      return;
    }
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Yükleme sürerken hesap değiştiyse eski sonucu gösterme
    if (!mounted || _loadedForUser != userId) return;
    setState(() {
      _active = active;
      _lastOrder = latest;
    });
  }

  Future<void> _repeatLastOrder() async {
    final order = _lastOrder;
    if (order == null || _adding) return;
    final confirmed = await showMarketSheet<bool>(
      context,
      builder: (_) => _RepeatOrderSheet(order: order),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _adding = true);
    final result = await addItemsToCart(
      context.read<CartViewModel>(),
      [
        for (final item in order.products)
          CartFillItem(
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (result.added == 0) {
      showMarketSnack(
        context,
        'Bu siparişteki ürünler şu an satışta değil.',
        error: true,
      );
      return;
    }
    showMarketSnack(
      context,
      cartFillMessage(result),
      icon: Icons.shopping_bag_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final Widget? card;
    if (_loadedForUser == null) {
      card = null;
    } else if (_active.isNotEmpty) {
      card = _ActiveOrderCard(orders: _active);
    } else if (_lastOrder != null) {
      card = _ReorderCard(
        order: _lastOrder!,
        busy: _adding,
        onRepeat: _repeatLastOrder,
      );
    } else {
      card = null;
    }

    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: card == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.lg, gutter, 0),
              child: card,
            ),
    );
  }
}

String _orderSummary(Order order) {
  final units = order.products.fold<int>(0, (sum, item) => sum + item.quantity);
  return '$units\u00A0ürün\u00A0· ${formatTlShort(order.totalAmount)}';
}

/// Süren siparişin durumu: Alındı → Hazırlanıyor → Yolda → Teslim.
class _ActiveOrderCard extends StatelessWidget {
  final List<Order> orders;

  const _ActiveOrderCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final order = orders.first;
    final onTheWay = order.status == 'Yolda';
    final title = orders.length > 1
        ? '${orders.length} aktif siparişin var'
        : onTheWay
            ? 'Siparişin yolda'
            : 'Siparişin hazırlanıyor';
    // Teslimat yerinin adı satır sonunda bölünmez ("Kız KYK Yurdu")
    final point = order.deliveryPointName.trim().replaceAll(' ', '\u00A0');
    final subtitle = point.isEmpty
        ? _orderSummary(order)
        : '${_orderSummary(order)}\u00A0· $point';
    final filled = onTheWay ? 3 : 2;
    // Dar ekranda ve büyük yazıda "Takip et" yazısı düşer, ok kalır (kartın
    // tamamı dokunulabilir); başlık ve özet sığar.
    final roomy = MediaQuery.sizeOf(context).width /
            MediaQuery.textScalerOf(context).scale(1) >=
        330;

    void track() => context.push('/orders');
    return Semantics(
      button: true,
      label: '$title, $subtitle. Takip et',
      excludeSemantics: true,
      onTap: track,
      child: MarketCard(
        shadow: false,
        borderColor: MarketPalette.greenLine,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        onTap: track,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MarketIconTile(
                  icon: onTheWay
                      ? Icons.delivery_dining_rounded
                      : Icons.soup_kitchen_outlined,
                  size: 44,
                  background:
                      onTheWay ? MarketPalette.blueSoft : MarketPalette.orangeSoft,
                  foreground:
                      onTheWay ? MarketPalette.blue : MarketPalette.orangeInk,
                ),
                const SizedBox(width: MarketSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.label(size: 15, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.caption(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MarketSpace.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (roomy)
                      Text(
                        'Takip et',
                        style: MarketText.label(color: MarketPalette.greenDark),
                      ),
                    Icon(Icons.chevron_right_rounded,
                        size: roomy ? 18 : 24, color: MarketPalette.greenDark),
                  ],
                ),
              ],
            ),
            const SizedBox(height: MarketSpace.md),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _OrderSteps(filled: filled),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSteps extends StatelessWidget {
  final int filled;

  const _OrderSteps({required this.filled});

  static const _labels = ['Alındı', 'Hazırlanıyor', 'Yolda', 'Teslim'];
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final segment = (constraints.maxWidth - _gap * 3) / 4;
        TextStyle style(int i) => MarketText.caption(
              size: 11,
              color: i == filled - 1
                  ? MarketPalette.greenDark
                  : MarketPalette.muted,
              weight: i == filled - 1 ? FontWeight.w700 : FontWeight.w500,
            );
        // Adımların adları sığmıyorsa (dar ekran, büyük yazı) yalnızca
        // çubuk gösterilir; başlık zaten durumu söylüyor.
        final widest = TextPainter(
          text: TextSpan(text: _labels[1], style: style(1)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final showLabels = widest.width <= segment;
        widest.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < _labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? MarketPalette.green
                            : MarketPalette.line,
                        borderRadius:
                            BorderRadius.circular(MarketRadius.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (showLabels) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < _labels.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: Text(
                        _labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: style(i),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Son siparişi tekrarlama kartı: üst üste binen küçük ürün görselleri,
/// özet ve "Tekrarla" düğmesi.
class _ReorderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final VoidCallback onRepeat;

  const _ReorderCard({
    required this.order,
    required this.busy,
    required this.onRepeat,
  });

  static const double _size = 36;
  static const double _step = 22;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final products = order.products;
    final summary = _orderSummary(order);
    final titleStyle = MarketText.label(size: 14, weight: FontWeight.w800);
    final summaryStyle = MarketText.caption();
    final buttonStyle = MarketText.label(size: 13);

    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return MarketCard(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: busy ? null : onRepeat,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Başlık ve tutar tek satırda tam okunmalı (müşteri tutara bakarak
          // karar verir). Sığmazsa önce görsel sayısı azalır; yine sığmazsa
          // "Tekrarla" alt satıra iner.
          final textNeed = math.max(
            textWidth('Son siparişin', titleStyle),
            textWidth(summary, summaryStyle),
          );
          final buttonWidth = textWidth('Tekrarla', buttonStyle) + 14 * 2 + 2;
          int circlesFor(int thumbs) =>
              thumbs + (products.length > thumbs ? 1 : 0);
          bool fits(int thumbs, {required bool inline}) {
            final thumbsWidth = _size + _step * (circlesFor(thumbs) - 1);
            final rest = constraints.maxWidth -
                thumbsWidth -
                MarketSpace.md -
                (inline ? MarketSpace.sm + buttonWidth : 0);
            return rest >= textNeed;
          }

          final maxThumbs = math.max(1, math.min(narrow ? 2 : 3, products.length));
          var thumbs = maxThumbs;
          while (thumbs > 1 && !fits(thumbs, inline: true)) {
            thumbs--;
          }
          final inline = fits(thumbs, inline: true);
          if (!inline) {
            thumbs = maxThumbs;
            while (thumbs > 1 && !fits(thumbs, inline: false)) {
              thumbs--;
            }
          }

          final info = Row(
            children: [
              _ThumbStack(
                images: [
                  for (final item in products.take(thumbs)) item.image,
                ],
                extra: products.length - math.min(thumbs, products.length),
                size: _size,
                step: _step,
              ),
              const SizedBox(width: MarketSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Son siparişin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      busy ? 'Sepete ekleniyor…' : summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: summaryStyle,
                    ),
                  ],
                ),
              ),
            ],
          );

          final Widget action = busy
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: MarketPalette.green,
                      ),
                    ),
                  ),
                )
              : FilledButton.tonal(
                  onPressed: onRepeat,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, MarketSize.control),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: MarketPalette.greenSoft,
                    foregroundColor: MarketPalette.greenDark,
                    textStyle: buttonStyle,
                  ),
                  child: Text(
                    'Tekrarla',
                    semanticsLabel: 'Son siparişini tekrarla, $summary',
                  ),
                );

          if (inline) {
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: MarketSpace.sm),
                action,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 10),
              busy ? Center(child: action) : action,
            ],
          );
        },
      ),
    );
  }
}

/// Üst üste binen küçük ürün görselleri ve kalanlar için "+N" balonu.
class _ThumbStack extends StatelessWidget {
  final List<String?> images;
  final int extra;
  final double size;
  final double step;

  const _ThumbStack({
    required this.images,
    required this.extra,
    required this.size,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final circles = images.length + (extra > 0 ? 1 : 0);
    return ExcludeSemantics(
      child: SizedBox(
        width: size + step * (circles - 1),
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < images.length; i++)
              Positioned(
                left: step * i,
                child: _Thumb(image: images[i], size: size),
              ),
            if (extra > 0)
              Positioned(
                left: step * images.length,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MarketPalette.greenSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '+$extra',
                    maxLines: 1,
                    style: MarketText.label(
                        color: MarketPalette.greenDark, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? image;
  final double size;

  const _Thumb({required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = image?.trim() ?? '';
    const fallback = Icon(
      Icons.inventory_2_outlined,
      size: 18,
      color: MarketPalette.subtle,
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: MarketPalette.line, spreadRadius: .5),
        ],
      ),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                optimizedImageUrl(url, width: MarketImageSize.thumb),
                fit: BoxFit.contain,
                cacheWidth: 120,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Son siparişin içeriğini gösterip sepete eklemeden önce onay alır.
class _RepeatOrderSheet extends StatelessWidget {
  final Order order;

  const _RepeatOrderSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return MarketSheetScaffold(
      header: MarketSheetHeader(
        title: 'Son siparişini tekrarla',
        subtitle: '${order.products.length} çeşit ürün · o günkü tutar '
            '${formatTl(order.totalAmount)}',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < order.products.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: MarketPalette.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${order.products[i].quantity}×',
                      style: MarketText.label(color: MarketPalette.inkSoft),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      productDisplayName(order.products[i].name),
                      style: MarketText.body(size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: MarketSpace.sm),
          const MarketNotice.info(
            icon: Icons.info_outline_rounded,
            text: 'Ürünler güncel fiyatlarıyla eklenir. Stokta olmayanlar atlanır.',
          ),
        ],
      ),
      footer: FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text('Sepete ekle'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.button),
        ),
      ),
    );
  }
}
