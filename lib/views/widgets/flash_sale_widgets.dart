import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/flash_sale.dart';
import '../../models/product.dart';
import '../../services/image_url.dart';
import '../../services/server_clock.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
import 'category_presentation.dart';
import 'market_product_card.dart';
import 'market_ui.dart';

/// Flash sale rozetlerinin ortak geçişi (kırmızıdan turuncuya).
const flashSaleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [MarketPalette.red, MarketPalette.orange],
);

String _two(int value) => value.toString().padLeft(2, '0');

/// Kalan süre: "02:14:33", bir günden uzunsa "2 gün 04:10".
String formatFlashRemaining(Duration remaining) {
  if (remaining <= Duration.zero) return '00:00:00';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;
  if (days > 0) return '$days gün ${_two(hours)}:${_two(minutes)}';
  return '${_two(remaining.inHours)}:${_two(minutes)}:${_two(seconds)}';
}

/// [endDate]'e kadar saniyede bir yeniden çizilir; süre bitince durur.
/// Kalan süre sunucu saatine göre hesaplanır ([ServerClock]); sunucu saati
/// sonradan öğrenilip fark değişirse sayaç yeniden başlar.
class FlashCountdown extends StatefulWidget {
  final DateTime endDate;
  final Widget Function(BuildContext context, Duration remaining) builder;

  const FlashCountdown({
    super.key,
    required this.endDate,
    required this.builder,
  });

  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  Timer? _timer;

  Duration get _remaining {
    final value = widget.endDate.difference(ServerClock.instance.now());
    return value.isNegative ? Duration.zero : value;
  }

  @override
  void initState() {
    super.initState();
    ServerClock.instance.addListener(_onClockChanged);
    _start();
  }

  void _onClockChanged() {
    if (!mounted) return;
    setState(_start);
  }

  @override
  void didUpdateWidget(covariant FlashCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endDate != widget.endDate) _start();
  }

  void _start() {
    _timer?.cancel();
    if (_remaining == Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == Duration.zero) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    ServerClock.instance.removeListener(_onClockChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// Ürün kartındaki "⚡ %20" rozeti. Düz kırmızı zemin: beyaz metin her
/// yerinde okunur (gradyanın turuncu ucunda kontrast ~2:1'e düşüyordu).
class FlashBadge extends StatelessWidget {
  final double discountPercentage;

  const FlashBadge({super.key, required this.discountPercentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      decoration: BoxDecoration(
        color: MarketPalette.red,
        borderRadius: BorderRadius.circular(MarketRadius.xs),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.red.withValues(alpha: .22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 1),
          Text(
            '%${discountPercentage.round()}',
            style: MarketText.label(
              color: Colors.white,
              size: 12,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekran okuyucu için dakika hassasiyetinde kalan süre: "3 saat 12 dakika".
/// (Saniye saniye değişen etiket sürekli yeniden okunuyordu.)
String spokenFlashRemaining(Duration remaining) {
  if (remaining <= Duration.zero) return 'Kampanya sona erdi';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final String text;
  if (days > 0) {
    text = hours > 0 ? '$days gün $hours saat' : '$days gün';
  } else if (remaining.inHours > 0) {
    text = minutes > 0 ? '$hours saat $minutes dakika' : '$hours saat';
  } else if (minutes > 0) {
    text = '$minutes dakika';
  } else {
    text = 'bir dakikadan az';
  }
  return 'Kampanyanın bitmesine $text';
}

/// Kartın görsel alanına ve flash sale başlığına konan küçük geri sayım.
/// Son bir saatte kırmızıya döner.
class FlashTimerChip extends StatelessWidget {
  final DateTime endDate;

  const FlashTimerChip({super.key, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return FlashCountdown(
      endDate: endDate,
      builder: (context, remaining) {
        final urgent = remaining < const Duration(hours: 1);
        return Semantics(
          label: spokenFlashRemaining(remaining),
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
            decoration: BoxDecoration(
              color: urgent
                  ? MarketPalette.red
                  : MarketPalette.ink.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(MarketRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  formatFlashRemaining(remaining),
                  style: MarketText.code(color: Colors.white, size: 11)
                      .copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ürün detayında fiyatın altındaki büyük flash sale kartı.
class FlashSaleBanner extends StatelessWidget {
  final FlashSale sale;

  const FlashSaleBanner({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final total = sale.endDate.difference(sale.startDate);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: flashSaleGradient,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.red.withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FlashCountdown(
        endDate: sale.endDate,
        builder: (context, remaining) {
          final elapsed = total.inSeconds <= 0
              ? 1.0
              : (1 - remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);
          final days = remaining.inDays;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flash Sale',
                          style: MarketText.heading(
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '%${sale.discountPercentage.round()} indirim · sınırlı süre',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.caption(
                            color: Colors.white.withValues(alpha: .86),
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                label: 'Bitimine ${formatFlashRemaining(remaining)}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    if (days > 0) ...[
                      _TimeBox(value: '$days', label: 'Gün'),
                      const SizedBox(width: 8),
                    ],
                    _TimeBox(
                      value: _two(remaining.inHours % 24),
                      label: 'Saat',
                    ),
                    const SizedBox(width: 8),
                    _TimeBox(
                      value: _two(remaining.inMinutes % 60),
                      label: 'Dakika',
                    ),
                    const SizedBox(width: 8),
                    _TimeBox(
                      value: _two(remaining.inSeconds % 60),
                      label: 'Saniye',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(MarketRadius.pill),
                child: LinearProgressIndicator(
                  value: elapsed,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: .25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                remaining == Duration.zero
                    ? 'Kampanya sona erdi'
                    : 'Kampanya bitince fiyat normale döner',
                style: MarketText.caption(
                  color: Colors.white.withValues(alpha: .86),
                  size: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String label;

  const _TimeBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(MarketRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: MarketText.code(color: Colors.white, size: 20)
                  .copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: MarketText.caption(
                color: Colors.white.withValues(alpha: .86),
                size: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Süren flash sale ürünlerinin bandı. [productIds] verilirse yalnızca
/// o ürünler (ör. açık kategorideki ürünler) gösterilir. Kampanya yoksa
/// hiç yer kaplamaz.
///
/// Tek ürün varsa yatay bir vitrin kartı, birden çok ürün varsa kart rafı
/// gösterilir. Geri sayım başlıkta bir kez, en erken biten kampanyaya göre
/// gösterilir.
class FlashSaleShelf extends StatelessWidget {
  final Set<String>? productIds;
  final EdgeInsetsGeometry padding;

  const FlashSaleShelf({
    super.key,
    this.productIds,
    this.padding = const EdgeInsets.only(top: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FlashSaleViewModel>(
      builder: (context, flash, _) {
        final ids = productIds;
        final sales = flash.activeFlashSales
            .where((sale) => !sale.product.isHidden)
            .where((sale) => ids == null || ids.contains(sale.productId))
            .toList();
        if (sales.isEmpty) return const SizedBox.shrink();

        final endsAt = sales
            .map((sale) => sale.endDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final width = MediaQuery.sizeOf(context).width;
        final gutter = MarketSpace.gutterOf(context);
        final spotlight = sales.length == 1 && width < 620;

        return Padding(
          padding: padding,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [MarketPalette.redSoft, MarketPalette.orangeSoft],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: _FlashHeader(count: sales.length, endsAt: endsAt),
                  ),
                  const SizedBox(height: MarketSpace.md),
                  if (spotlight)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: _FlashSpotlightTile(sale: sales.first),
                    )
                  else
                    SizedBox(
                      height: marketProductCardExtent(context),
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        itemCount: sales.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: MarketSpace.md),
                        itemBuilder: (context, index) => SizedBox(
                          width: width < 360 ? 140 : 156,
                          child: MarketProductCard(
                            product: sales[index].product,
                            hero: false,
                            showFlashTimer: sales[index].endDate != endsAt,
                          ),
                        ),
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
}

class _FlashHeader extends StatelessWidget {
  final int count;
  final DateTime endsAt;

  const _FlashHeader({required this.count, required this.endsAt});

  /// [FlashTimerChip]'in yazı dışındaki genişliği (iç boşluk + simge).
  static const double _chipChrome = 6 + 8 + 13 + 4;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final titleStyle = MarketText.heading(size: 18);
    final subtitle = count == 1
        ? 'Sınırlı süreli indirim'
        : '$count üründe sınırlı süreli indirim';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Geri sayım başlığın yanına sığmıyorsa (dar ekran, büyük yazı, gün
        // süren kampanya) alt başlığın altına iner; "Flash Sale" kesilmez.
        final remaining = endsAt.difference(ServerClock.instance.now());
        final chipWidth = _chipChrome +
            textWidth(
              formatFlashRemaining(remaining),
              MarketText.code(color: Colors.white, size: 11)
                  .copyWith(letterSpacing: 0),
            );
        final besideTitle = constraints.maxWidth - 36 - 10 - 8 - chipWidth >=
            textWidth('Flash Sale', titleStyle);
        final timer = FlashTimerChip(endDate: endsAt);

        return Row(
          crossAxisAlignment: besideTitle
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: flashSaleGradient,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child:
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Flash Sale',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.caption(),
                  ),
                  if (!besideTitle) ...[
                    const SizedBox(height: 6),
                    timer,
                  ],
                ],
              ),
            ),
            if (besideTitle) ...[
              const SizedBox(width: 8),
              timer,
            ],
          ],
        );
      },
    );
  }
}

/// Tek flash sale ürünü için yatay vitrin kartı (rafın yarısı boş kalmasın).
class _FlashSpotlightTile extends StatelessWidget {
  final FlashSale sale;

  const _FlashSpotlightTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final product = context.select<FlashSaleViewModel, Product>(
      (flash) => flash.latest(sale.product),
    );
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final imageSize = narrow ? 96.0 : 112.0;
    final showOld = product.price > product.actualPrice;
    final savings = product.price - product.actualPrice;
    // Rozet yüzdesi ürünün kendi flash sale özetinden (yoksa kampanyadan)
    final discount =
        product.flashSale?.discountPercentage ?? sale.discountPercentage;
    final name = productDisplayName(product.name);

    final label = StringBuffer('$name, ${formatTl(product.actualPrice)}');
    if (showOld) {
      label.write(', eski fiyat ${formatTl(product.price)}, '
          '%${discount.round()} indirim');
    }
    if (product.isOutOfStock) label.write(', stokta yok');

    return Semantics(
      container: true,
      label: label.toString(),
      child: Material(
        color: MarketPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          side: const BorderSide(color: MarketPalette.redLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/product', extra: product),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: imageSize,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MarketPalette.surface,
                                borderRadius:
                                    BorderRadius.circular(MarketRadius.md),
                                border: Border.all(color: MarketPalette.line),
                              ),
                              child: product.image.isEmpty
                                  ? const Icon(Icons.inventory_2_outlined,
                                      color: MarketPalette.subtle, size: 34)
                                  : Image.network(
                                      optimizedImageUrl(product.image,
                                          width: MarketImageSize.card),
                                      fit: BoxFit.contain,
                                      cacheWidth: 300,
                                      excludeFromSemantics: true,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.inventory_2_outlined,
                                          color: MarketPalette.subtle,
                                          size: 34),
                                    ),
                            ),
                          ),
                          Positioned(
                            left: 6,
                            top: 6,
                            child: FlashBadge(discountPercentage: discount),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MarketSpace.md),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: imageSize),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 40),
                                    child: Text(
                                      product.category.trim().isEmpty
                                          ? 'Flash Sale'
                                          : categoryDisplayName(
                                              product.category),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MarketText.caption(
                                          size: 11, weight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 40),
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: MarketText.label(size: 14)
                                          .copyWith(height: 1.3),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          formatTl(product.actualPrice),
                                          style: MarketText.price(
                                              color: MarketPalette.red,
                                              size: 18),
                                        ),
                                        if (showOld) ...[
                                          const SizedBox(width: 6),
                                          Text(formatTl(product.price),
                                              style: MarketText.oldPrice()),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: showOld
                                      ? ExcludeSemantics(
                                          child: Text(
                                            '${formatTl(savings)} tasarruf',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: MarketText.label(
                                                color: MarketPalette.greenDark,
                                                size: 12),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                if (product.isOutOfStock)
                                  const MarketPill(
                                    label: 'Stokta yok',
                                    background: MarketPalette.fill,
                                    foreground: MarketPalette.muted,
                                  )
                                else
                                  MarketCartButton(product: product),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Favori düğmesi kartın sağ üst köşesinde (görselde rozetle
              // çakışmasın diye)
              Positioned(
                top: 4,
                right: 4,
                child: MarketFavoriteButton(product: product),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
