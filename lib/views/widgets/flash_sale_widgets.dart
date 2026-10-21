import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/flash_sale.dart';
import '../../viewmodels/flash_sale_viewmodel.dart';
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
    final value = widget.endDate.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  @override
  void initState() {
    super.initState();
    _start();
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// Ürün kartındaki "⚡ %20" rozeti.
class FlashBadge extends StatelessWidget {
  final double discountPercentage;

  const FlashBadge({super.key, required this.discountPercentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        gradient: flashSaleGradient,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.red.withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 2),
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

/// Kartın görsel alanına konan küçük geri sayım.
class FlashTimerChip extends StatelessWidget {
  final DateTime endDate;

  const FlashTimerChip({super.key, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return FlashCountdown(
      endDate: endDate,
      builder: (context, remaining) => Semantics(
        label: 'Flash sale bitimine ${formatFlashRemaining(remaining)}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
          decoration: BoxDecoration(
            color: MarketPalette.ink.withValues(alpha: .86),
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
      ),
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

/// Süren flash sale ürünlerinin yatay rafı. [productIds] verilirse yalnızca
/// o ürünler (ör. açık kategorideki ürünler) gösterilir. Kampanya yoksa
/// hiç yer kaplamaz.
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

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: flashSaleGradient,
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
                          Text('Flash Sale', style: MarketText.title(size: 22)),
                          const SizedBox(height: 2),
                          Text(
                            sales.length == 1
                                ? 'Sınırlı süreli indirim'
                                : '${sales.length} üründe sınırlı süreli indirim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.caption(size: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FlashTimerChip(endDate: sales.first.endDate),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: marketProductCardHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 13),
                  itemBuilder: (context, index) => SizedBox(
                    width: 172,
                    child: MarketProductCard(
                      product: sales[index].product,
                      hero: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
