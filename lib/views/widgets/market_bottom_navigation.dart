import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/cart_viewmodel.dart';
import 'market_mascot.dart';
import 'market_ui.dart';

/// Ana sayfa / Sepet / Hesabım alt menüsü.
///
/// Normalde içeriğin üstünde yüzen yuvarlak bir kart olarak durur; arkasında
/// yalnızca boyanan (dokunuşu etkilemeyen) yumuşak bir zemin geçişi vardır,
/// böylece kayan içerik menünün altında ve çevresinde kesik görünmez.
/// Sepet sekmesinde sepet doluyken ödeme çubuğuyla tek parça bir alt blok
/// oluşturmak için tam genişliğe yapışır ([attached]).
class MarketBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MarketBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Kısa ekranlarda (ör. 320x568) menü daha alçak durur.
  static double barHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640 ? 64 : 70;

  /// Menünün ekranın altında kapladığı toplam yükseklik (alt boşluk ve ev
  /// çubuğu payı dahil). Sayfalar genelde bunun yerine
  /// `MediaQuery.paddingOf(context).bottom` kullanır (extendBody).
  static double occupiedHeight(BuildContext context) =>
      barHeight(context) + math.max(MediaQuery.paddingOf(context).bottom, 12);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartViewModel, int>((c) => c.totalItems);
    final attached = selectedIndex == 1 && cartCount > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final inset = MediaQuery.paddingOf(context).bottom;
    final height = barHeight(context);
    final small = height < 70;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // İçeriğin menünün arkasında yavaşça kaybolduğu zemin geçişi
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: attached ? 0 : 1,
              duration: duration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MarketPalette.canvas.withValues(alpha: 0),
                      MarketPalette.canvas.withValues(alpha: .94),
                      MarketPalette.canvas,
                    ],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          height: attached ? height + inset : height,
          margin: attached
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(16, 0, 16, math.max(inset, 12)),
          padding: attached
              ? EdgeInsets.fromLTRB(10, 6, 10, 6 + inset)
              : const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: MarketPalette.surface,
            border: attached ? null : Border.all(color: MarketPalette.line),
            borderRadius: BorderRadius.circular(attached ? 0 : MarketRadius.lg),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep
                    .withValues(alpha: attached ? 0 : .10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Yapışık halde üstte ince ayırıcı çizgi
              Positioned(
                top: -6,
                left: -10,
                right: -10,
                height: 1,
                child: AnimatedOpacity(
                  opacity: attached ? 1 : 0,
                  duration: duration,
                  child: const ColoredBox(color: MarketPalette.line),
                ),
              ),
              AnimatedAlign(
                alignment: Alignment(-1 + selectedIndex.toDouble(), 0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubicEmphasized,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                  ),
                ),
              ),
              Row(children: [
                _NavigationItem(
                  icon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  selected: selectedIndex == 0,
                  small: small,
                  onTap: () => onSelected(0),
                ),
                _NavigationItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Sepet',
                  badgeCount: cartCount,
                  selected: selectedIndex == 1,
                  small: small,
                  onTap: () => onSelected(1),
                ),
                _NavigationItem(
                  icon: Icons.person_rounded,
                  label: 'Hesabım',
                  selected: selectedIndex == 2,
                  small: small,
                  onTap: () => onSelected(2),
                ),
              ]),
              // Maskot: seçili sekmenin üst kenarında oturur, sekme
              // değişince oraya zıplar, sepete ürün eklenince sevinir.
              Positioned.fill(
                child: IgnorePointer(
                  child: _NavMascot(
                    index: selectedIndex,
                    cartCount: cartCount,
                    size: small ? 34 : 40,
                    // Ödeme çubuğuna yapışıkken üstte yer yok: menünün içinde
                    inside: attached,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Alt menünün üstünde duran hareketli maskot.
///
/// * Sekme değişince yeni sekmeye kavisli bir zıplamayla gider, giderken
///   gittiği yöne eğilir; yere inerken hafifçe basılır.
/// * Sepete ürün eklenince (sepet adedi artınca) yerinde sevinçle zıplar.
/// * Boşta birkaç saniyede bir kısa bir "kafa sallama" yapar; arada hiç
///   kare çizilmez (pil dostu).
/// * Hareket azaltma açıksa sabit durur, sekme değişince doğrudan yerine
///   geçer.
class _NavMascot extends StatefulWidget {
  final int index;
  final int cartCount;
  final double size;

  /// Menünün üst kenarı yerine içinde, sekmenin sağında durur
  final bool inside;

  const _NavMascot({
    required this.index,
    required this.cartCount,
    required this.size,
    this.inside = false,
  });

  @override
  State<_NavMascot> createState() => _NavMascotState();
}

enum _MascotMove { travel, cheer, idle }

class _NavMascotState extends State<_NavMascot> with TickerProviderStateMixin {
  static const _idleEvery = Duration(seconds: 6);

  late final AnimationController _hop = AnimationController(vsync: this);
  Timer? _idleTimer;
  _MascotMove _move = _MascotMove.idle;

  /// Zıplamanın başladığı ve gittiği sekme (konum ikisi arasında)
  late double _from = widget.index.toDouble();
  late double _to = widget.index.toDouble();

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _scheduleIdle();
  }

  @override
  void didUpdateWidget(covariant _NavMascot old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      _from = _position;
      _to = widget.index.toDouble();
      _play(_MascotMove.travel, const Duration(milliseconds: 760));
    } else if (widget.cartCount > old.cartCount) {
      _play(_MascotMove.cheer, const Duration(milliseconds: 780));
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _hop.dispose();
    super.dispose();
  }

  /// Şu anki yatay konum (sekme numarası cinsinden, kesirli)
  double get _position {
    if (_move != _MascotMove.travel || !_hop.isAnimating) return _to;
    // Yatay yol yalnızca havadayken alınır (çömelme ve iniş yerinde)
    final t = _phase(_hop.value, _flightStart, _flightEnd);
    return _from + (_to - _from) * Curves.easeInOutCubic.transform(t);
  }

  // Sıçramanın evreleri (0-1): çömelme → uçuş → iniş/toparlanma
  static const _flightStart = .18;
  static const _flightEnd = .78;

  /// [a]-[b] aralığını 0-1'e açar
  static double _phase(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  /// İnişten sonra sönen yaylanma (basılma ↔ uzama)
  static double _settle(double t) =>
      math.sin(t * math.pi * 3) * (1 - t) * (1 - t);

  void _play(_MascotMove move, Duration duration) {
    _idleTimer?.cancel();
    if (_reduceMotion) {
      _from = _to;
      _hop.value = 0;
      _scheduleIdle();
      return;
    }
    setState(() => _move = move);
    _hop
      ..duration = duration
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (!mounted) return;
        _from = _to;
        _scheduleIdle();
      });
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleEvery, () {
      if (!mounted) return;
      // Sekme görünmüyorsa (TickerMode kapalı) beklemeye devam
      if (!TickerMode.valuesOf(context).enabled || _reduceMotion) {
        _scheduleIdle();
        return;
      }
      _play(_MascotMove.idle, const Duration(milliseconds: 1100));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tabWidth = constraints.maxWidth / 3;
      // "Üstte" ↔ "içte" geçişi anında değil, zıplamayla aynı sürede: maskot
      // menünün üstünden kalkıp kavisle içine iner (ya da tersi).
      return TweenAnimationBuilder<double>(
        tween: Tween(end: widget.inside ? 1.0 : 0.0),
        duration:
            _reduceMotion ? Duration.zero : const Duration(milliseconds: 760),
        curve: Curves.easeInOutCubic,
        builder: (context, insideT, mascot) => AnimatedBuilder(
          animation: _hop,
          child: mascot,
          builder: (context, child) {
            final size = widget.size * (1 - .2 * insideT);
            // Ayakların bastığı çizgi: menünün üst kenarı ya da içte alt kısım
            final ground = lerpDouble(
              size * .14,
              (constraints.maxHeight + size) / 2,
              insideT,
            )!;
            final t = _hop.isAnimating ? _hop.value : 0.0;
            final arc = math.sin(math.pi * t);
            var lift = 0.0;
            var tilt = 0.0;
            var squash = 0.0;
            switch (_move) {
              case _MascotMove.travel:
                final dir = (_to - _from).sign;
                final crouch = _phase(t, 0, _flightStart);
                final flight = _phase(t, _flightStart, _flightEnd);
                final land = _phase(t, _flightEnd, 1);
                if (t < _flightStart) {
                  // Hazırlık: çömelip gidilecek yöne hafif yaslanır
                  final c = Curves.easeOut.transform(crouch);
                  squash = .12 * c;
                  tilt = -dir * .08 * c;
                } else if (t < _flightEnd) {
                  // Uçuş: parabol; kalkışta uzar, tepe noktasında dengelenir
                  final f = flight;
                  lift = math.sin(math.pi * f) * 26;
                  squash = -.10 * math.sin(math.pi * f) * (1 - f);
                  tilt = dir * .26 * math.sin(math.pi * f);
                } else {
                  // İniş: basılır, sonra yaylanarak toparlanır
                  squash = .14 * (1 - land) + _settle(land) * .06;
                  tilt = dir * .06 * (1 - land) * math.cos(land * math.pi * 2);
                }
              case _MascotMove.cheer:
                // Çömel, iki sıçrama, yaylanarak dur
                if (t < .12) {
                  squash = .12 * Curves.easeOut.transform(t / .12);
                } else if (t < .82) {
                  final f = (t - .12) / .70;
                  final hop = math.sin(math.pi * 2 * f).abs();
                  lift = hop * 18 * (f < .5 ? 1 : .75);
                  squash = -.08 * hop;
                  tilt = math.sin(math.pi * 4 * f) * .18;
                } else {
                  final l = (t - .82) / .18;
                  squash = .12 * (1 - l) + _settle(l) * .05;
                }
              case _MascotMove.idle:
                // Yumuşak kafa sallama ve ufak bir nefes
                final e = Curves.easeInOut.transform(t);
                lift = math.sin(math.pi * e) * 3;
                tilt = math.sin(math.pi * 2 * e) * .10;
                squash = -math.sin(math.pi * e) * .03;
            }
            // Seçili sekmenin sağ üst köşesi: simge ve sepet rozetini örtmez
            final x = tabWidth * (_position + 1) - size - 6;
            final y = ground - size - lift;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Gölge: zıplarken küçülür
                Positioned(
                  left: x + size * .2,
                  top: ground - size * .14 - 3,
                  width: size * .6,
                  height: 5,
                  child: Opacity(
                    opacity: .18 * (1 - (lift / 24).clamp(0.0, .8)),
                    child: const DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: StadiumBorder(),
                        color: MarketPalette.greenDeep,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x,
                  top: y,
                  width: size,
                  height: size,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..rotateZ(tilt)
                      ..scaleByDouble(1 + squash, 1 - squash, 1, 1),
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
        child: ExcludeSemantics(
          child: RepaintBoundary(child: MarketMascot(size: widget.size)),
        ),
      );
    });
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool small;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.small,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        onTap: onTap,
        label: badgeCount > 0 ? '$label, $badgeCount ürün' : label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: selected ? MarketPalette.greenDark : MarketPalette.muted,
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, color, _) => SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, color: color, size: 24),
                        if (badgeCount > 0)
                          Positioned(
                            right: -12,
                            top: -9,
                            child: MarketCountBadge(count: badgeCount),
                          ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: small ? 2 : 4),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.15),
                        style: MarketText.body(
                          color: color ?? MarketPalette.muted,
                          size: small ? 11 : 12,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          height: 1.3,
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
    );
  }
}
