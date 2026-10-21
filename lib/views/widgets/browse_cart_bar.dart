import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'market_ui.dart';

/// Reyon, arama ve favoriler gibi alt menüsü olmayan sayfalarda sepete kısa
/// yol: koyu yeşil, yüzen "Sepete git" çubuğu. Sepetteki ürün sayısını,
/// toplamı ve minimum sepete kalan tutarı gösterir; dokununca Sepet sekmesi
/// açılır.
///
/// `Scaffold(extendBody: true, bottomNavigationBar: const BrowseCartBar())`
/// ile kullanılır: Scaffold bildirim çubuklarını çubuğun üstüne yerleştirir ve
/// gövdenin `MediaQuery.paddingOf(context).bottom` değeri çubuğun yüksekliğini
/// içerir (listelerin alt boşluğu buna göre verilir). Sepet boşken ya da
/// klavye açıkken çubuk aşağı kayarak gizlenir ve yer kaplamaz.
class BrowseCartBar extends StatelessWidget {
  const BrowseCartBar({super.key});

  /// Kısa ekranlarda (ör. 320x568) çubuk biraz daha alçak durur.
  static double barHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640 ? 56 : 60;

  @override
  Widget build(BuildContext context) {
    final (count, total) = context.select<CartViewModel, (int, double)>(
      (cart) => (cart.totalItems, cart.totalPrice),
    );
    final minimum = context.select<SettingsViewModel, double>(
      (settings) => settings.minimumOrderAmount,
    );
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final visible = count > 0 && !keyboardOpen;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      // Çıkarken çubuk yerini koruyup aşağı kayar, sonra yer kaplamaz.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [...previous, if (current != null) current],
      ),
      child: visible
          ? _CartBar(
              key: const ValueKey('browse-cart-bar'),
              count: count,
              total: total,
              minimum: minimum,
            )
          : const SizedBox.shrink(key: ValueKey('browse-cart-bar-hidden')),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int count;
  final double total;
  final double minimum;

  const _CartBar({
    super.key,
    required this.count,
    required this.total,
    required this.minimum,
  });

  void _openCart(BuildContext context) {
    context.go('/home', extra: <String, dynamic>{'initialTabIndex': 1});
  }

  /// Metnin tek satırdaki genişliği (yazı boyutu ayarı dahil, yukarı yuvarlı).
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final height = BrowseCartBar.barHeight(context);
    // Dar ekranda / büyük yazıda ok simgesi düşer, alt satır iki satıra
    // inebilir (yazı küçültülmez); çubuk da gerektiği kadar uzar.
    final compact = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final remaining = minimum - total;
    final belowMinimum = minimum > 0 && remaining > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelStyle = MarketText.label(
      color: Colors.white,
      size: 15,
      weight: FontWeight.w800,
    );
    // "Sepete git" kısalmaz: dar ekran + büyük yazı + 4 haneli tutarda toplam
    // küçülerek kalan yere sığar. Satır genişliği: ekran - dış (16 + 16) ve
    // iç (10 + 16) boşluk; sabitler: kutu 40 + 12, ara 10, ok 8 + 20.
    final rowWidth = MediaQuery.sizeOf(context).width - 32 - 26;
    final totalMax = math.max(
      56.0,
      rowWidth -
          (40 + 12 + 10 + (compact ? 0 : 8 + 20)) -
          _textWidth(context, 'Sepete git', labelStyle),
    );

    final semantics = StringBuffer(
      'Sepete git, $count ürün, toplam ${formatTl(total)}',
    );
    if (belowMinimum) {
      semantics.write(', minimum sepete ${formatTl(remaining)} kaldı');
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // İçeriğin çubuğun arkasında yavaşça kaybolduğu zemin geçişi
        // (ana sayfa alt menüsüyle aynı)
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MarketPalette.canvas.withValues(alpha: 0),
                    MarketPalette.canvas.withValues(alpha: .9),
                    MarketPalette.canvas,
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(inset, 12)),
          child: Semantics(
            container: true,
            button: true,
            label: semantics.toString(),
            excludeSemantics: true,
            onTap: () => _openCart(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MarketRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: MarketPalette.greenDeep.withValues(alpha: .18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: MarketPalette.greenDeep,
                borderRadius: BorderRadius.circular(MarketRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openCart(context),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                          child: Row(
                            children: [
                              _BasketTile(count: count),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sepete git',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: labelStyle,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      belowMinimum
                                          ? 'Min. sepete ${formatTl(remaining)}\u00A0kaldı'
                                          : '$count ürün',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: MarketText.caption(
                                        color: belowMinimum
                                            ? MarketPalette.lime
                                            : Colors.white
                                                .withValues(alpha: .74),
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: totalMax),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AnimatedSwitcher(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 160),
                                    child: Text(
                                      formatTl(total),
                                      key: ValueKey(total),
                                      maxLines: 1,
                                      style: MarketText.price(
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: MarketPalette.lime,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Minimum sepete ilerleme: çubuğun alt kenarında ince
                        // lime çizgi
                        if (belowMinimum)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 3,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                end: (total / minimum).clamp(0.0, 1.0),
                              ),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                value: value,
                                minHeight: 3,
                                color: MarketPalette.lime,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .16),
                              ),
                            ),
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
    );
  }
}

/// Lime sepet kutusu + ürün sayısı rozeti (alt menüdeki sepet simgesiyle aynı).
class _BasketTile extends StatelessWidget {
  final int count;

  const _BasketTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const MarketIconTile(
          icon: Icons.shopping_bag_rounded,
          size: 40,
          background: MarketPalette.lime,
          foreground: MarketPalette.greenDeep,
        ),
        Positioned(
          right: -6,
          top: -5,
          child: MarketCountBadge(
            count: count,
            outline: MarketPalette.greenDeep,
          ),
        ),
      ],
    );
  }
}
