import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'market_palette.dart';

/// Durum çubuğu şeridinin rengi ve simgelerinin açık/koyu oluşu.
@immutable
class MarketStatusStyle {
  const MarketStatusStyle(this.color, {this.lightIcons = true});

  final Color color;

  /// Saat / pil simgeleri beyaz mı (koyu zemin) yoksa koyu mu (açık zemin).
  final bool lightIcons;

  /// Varsayılan: koyu yeşil şerit, beyaz simgeler.
  static const brand = MarketStatusStyle(MarketPalette.greenDeep);

  @override
  bool operator ==(Object other) =>
      other is MarketStatusStyle && other.color == color && other.lightIcons == lightIcons;

  @override
  int get hashCode => Object.hash(color, lightIcons);
}

/// Kök Navigator'ı izler: açık alt sayfa / diyalogların karartmasını
/// ([modalDim]) ve en üstteki sayfanın istediği şerit stilini ([status])
/// yayınlar. [MarketSystemFrame] bu değerlerle durum çubuğu şeridini boyar;
/// böylece bir alt sayfa açılınca şerit de sayfayla birlikte kararır.
///
/// GoRouter'a `observers: AppRouter.observers` ile bağlanır. Aynı anda tek bir
/// Navigator'a bağlanabilir (kök Navigator).
class MarketChromeObserver extends NavigatorObserver {
  MarketChromeObserver._();

  static final MarketChromeObserver instance = MarketChromeObserver._();

  final ValueNotifier<double> _modalDim = ValueNotifier<double>(0);
  final ValueNotifier<MarketStatusStyle> _status =
      ValueNotifier<MarketStatusStyle>(MarketStatusStyle.brand);

  /// Açık modal rotaların karartma oranı (0: yok, ~0.54: tam açık alt sayfa).
  /// Sayfa sürüklenip kapatılırken kare kare değişir.
  ValueListenable<double> get modalDim => _modalDim;

  /// En üstteki sayfanın şerit stili ([MarketStatusBand] ile seçilir).
  ValueListenable<MarketStatusStyle> get status => _status;

  /// Durum çubuğu simgeleri şu an beyaz mı.
  bool get lightStatusIcons => _status.value.lightIcons || _modalDim.value > .3;

  final List<PopupRoute<dynamic>> _popups = [];
  final List<PageRoute<dynamic>> _pages = [];
  final Expando<MarketStatusStyle> _styles = Expando<MarketStatusStyle>();
  NavigatorState? _seenNavigator;
  bool _publishScheduled = false;

  // --- NavigatorObserver ---------------------------------------------------

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncNavigator(route);
    _track(route);
    _schedulePublish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Modal rota kapanış animasyonu bitene kadar listede kalır; şerit
    // sayfanın karartmasıyla birlikte açılır.
    if (route is PageRoute) _pages.remove(route);
    _schedulePublish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _untrack(route);
    _schedulePublish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _untrack(oldRoute);
    if (newRoute != null) {
      _syncNavigator(newRoute);
      _track(newRoute);
    }
    _schedulePublish();
  }

  // --- MarketStatusBand kaydı ----------------------------------------------

  /// [route] en üstteyken şeridin [style] ile boyanmasını ister; `null` kaydı siler.
  void setRouteStyle(Route<dynamic> route, MarketStatusStyle? style) {
    if (_styles[route] == style) return;
    _styles[route] = style;
    _schedulePublish();
  }

  /// Test düzeneği için: izlenen rotaları ve yayınlanan değerleri sıfırlar.
  @visibleForTesting
  void debugReset() {
    for (final route in List.of(_popups)) {
      _untrack(route);
    }
    _pages.clear();
    _seenNavigator = null;
    _modalDim.value = 0;
    _status.value = MarketStatusStyle.brand;
  }

  // --- İç işleyiş ----------------------------------------------------------

  /// Yeni bir Navigator bağlandıysa (ör. yeniden başlatma, testler) eskisinden
  /// kalan rotalar unutulur.
  void _syncNavigator(Route<dynamic> route) {
    final navigator = route.navigator;
    if (navigator == null || identical(navigator, _seenNavigator)) return;
    _seenNavigator = navigator;
    for (final popup in List.of(_popups)) {
      if (!identical(popup.navigator, navigator)) _untrack(popup);
    }
    _pages.removeWhere((page) => !identical(page.navigator, navigator));
  }

  void _track(Route<dynamic> route) {
    if (route is PageRoute) {
      _pages
        ..remove(route)
        ..add(route);
    } else if (route is PopupRoute && !_popups.contains(route)) {
      final barrier = route.barrierColor;
      final animation = route.animation;
      if (barrier == null || barrier.a == 0 || animation == null) return;
      _popups.add(route);
      animation
        ..addListener(_onPopupTick)
        ..addStatusListener(_onPopupStatus);
    }
  }

  void _untrack(Route<dynamic> route) {
    if (route is PageRoute) {
      _pages.remove(route);
    } else if (route is PopupRoute && _popups.remove(route)) {
      route.animation
        ?..removeListener(_onPopupTick)
        ..removeStatusListener(_onPopupStatus);
    }
  }

  void _onPopupTick() => _schedulePublish();

  void _onPopupStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    for (final route in List.of(_popups)) {
      if (route.animation?.status == AnimationStatus.dismissed) _untrack(route);
    }
    _schedulePublish();
  }

  /// Navigator olayları çoğu zaman bir build sırasında gelir; o anda üstteki
  /// çerçeveyi yeniden çizdirmek hata verir. Değerler bu karenin sonunda
  /// yayınlanır; animasyon ve dokunma sırasında ise hemen.
  void _schedulePublish() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _publish();
      return;
    }
    if (_publishScheduled) return;
    _publishScheduled = true;
    binding.addPostFrameCallback((_) {
      _publishScheduled = false;
      _publish();
    });
  }

  void _publish() {
    // Kapanıp atılmış (navigator'ı boşalmış) rotalar unutulur.
    for (final route in List.of(_popups)) {
      if (route.navigator == null) _untrack(route);
    }
    _pages.removeWhere((page) => page.navigator == null);

    var keep = 1.0;
    for (final route in _popups) {
      final animation = route.animation;
      final barrier = route.barrierColor;
      if (animation == null || barrier == null) continue;
      final t = route.barrierCurve.transform(animation.value.clamp(0.0, 1.0));
      keep *= 1 - barrier.a * t;
    }
    _modalDim.value = (1 - keep).clamp(0.0, 1.0);

    _status.value =
        _pages.isEmpty ? MarketStatusStyle.brand : (_styles[_pages.last] ?? MarketStatusStyle.brand);
  }
}

/// Üstü açık renkli sayfalar (ör. ürün detayındaki açık yeşil vitrin) gövdesini
/// bununla sarar; sayfa en üstteyken durum çubuğu şeridi [color] olur ve
/// simgeler koyulaşır. Sayfa kapanınca şerit marka rengine döner.
///
/// ```dart
/// MarketStatusBand(color: MarketPalette.limeSoft, child: Scaffold(...))
/// ```
class MarketStatusBand extends StatefulWidget {
  const MarketStatusBand({
    super.key,
    required this.color,
    this.lightIcons = false,
    required this.child,
  });

  final Color color;
  final bool lightIcons;
  final Widget child;

  @override
  State<MarketStatusBand> createState() => _MarketStatusBandState();
}

class _MarketStatusBandState extends State<MarketStatusBand> {
  Route<dynamic>? _route;

  MarketStatusStyle get _style => MarketStatusStyle(widget.color, lightIcons: widget.lightIcons);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    if (_route != null) MarketChromeObserver.instance.setRouteStyle(_route!, null);
    _route = route;
    if (route != null) MarketChromeObserver.instance.setRouteStyle(route, _style);
  }

  @override
  void didUpdateWidget(covariant MarketStatusBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_route != null &&
        (oldWidget.color != widget.color || oldWidget.lightIcons != widget.lightIcons)) {
      MarketChromeObserver.instance.setRouteStyle(_route!, _style);
    }
  }

  @override
  void dispose() {
    if (_route != null) MarketChromeObserver.instance.setRouteStyle(_route!, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Durum çubuğu alanını (üst güvenli alan) tek yerde boyar ve sayfaları onun
/// altından başlatır. Şerit rengi üstteki sayfaya göre yumuşakça değişir;
/// alt sayfa / diyalog açıkken sayfayla aynı oranda kararır.
class MarketSystemFrame extends StatelessWidget {
  const MarketSystemFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = MarketChromeObserver.instance;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final content = SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: RepaintBoundary(child: child),
    );
    return ValueListenableBuilder<MarketStatusStyle>(
      valueListenable: chrome.status,
      builder: (context, style, content) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: style.color),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: content,
          builder: (context, base, content) {
            return ValueListenableBuilder<double>(
              valueListenable: chrome.modalDim,
              child: content,
              builder: (context, dim, content) {
                final light = style.lightIcons || dim > .3;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
                    statusBarBrightness: light ? Brightness.dark : Brightness.light,
                    systemStatusBarContrastEnforced: false,
                    systemNavigationBarColor: MarketPalette.surface,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarIconBrightness: Brightness.dark,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      Colors.black.withValues(alpha: dim),
                      base ?? style.color,
                    ),
                    child: content,
                  ),
                );
              },
            );
          },
        );
      },
      child: content,
    );
  }
}
