import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'widgets/market_mascot.dart';
import 'widgets/market_ui.dart';

/// İlk açılış tanıtımı. Açılış ekranının devamı gibi görünür: koyu yeşil zemin
/// üstünde görsel, altta beyaz panelde başlık, açıklama ve ilerleme.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  static const _items = [
    (
      icon: null,
      title: 'Marketin artık cebinde',
      description:
          'Aradığını bul, sepetini hazırla, siparişini birkaç dokunuşla ver.',
    ),
    (
      icon: Icons.local_shipping_rounded,
      title: 'Siparişini anlık takip et',
      // Bir sonraki adımda istenen bildirim izninin nedenini anlatır
      description:
          'Siparişin hazırlanınca ve yola çıkınca bildirimle haber verelim.',
    ),
    (
      icon: Icons.support_agent_rounded,
      title: 'İhtiyacın olunca bize yaz',
      description:
          'Canlı destek, fotokopi hizmeti ve sana özel fırsatlar hep elinin altında.',
    ),
  ];

  bool get _isLast => _page == _items.length - 1;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    // Yeni kullanıcı bir sonraki açılışta "Yenilikler" ekranını görmesin
    try {
      final info = await PackageInfo.fromPlatform();
      await prefs.setString('last_seen_version', info.version);
    } catch (_) {
      // Sürüm okunamazsa yalnızca "Yenilikler" bir kez görünür
    }
    // Bildirim izni ilk kez burada sorulur (açılışta değil).
    await NotificationService.instance.requestPermissionIfNeeded();
    if (mounted) context.go('/home');
  }

  void _goTo(int page) {
    if (page < 0 || page >= _items.length) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final narrow = size.width < 360;
    final gutter = MarketSpace.gutterOf(context);
    // Beyaz panel ekranın yaklaşık üçte biri; büyük yazıda biraz uzar, yine
    // sığmazsa içerik panelde kayar.
    final textGrowth = MediaQuery.textScalerOf(context).scale(10) / 10;
    final panelHeight =
        (size.height * .32).clamp(240.0, 300.0) * textGrowth.clamp(1.0, 1.3) + padding.bottom;
    final item = _items[_page];

    return Scaffold(
      backgroundColor: MarketPalette.greenDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BackdropPainter())),
          Column(
            children: [
              SizedBox(height: padding.top),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 8, 8, 0),
                child: Row(
                  children: [
                    const MarketWordmark(height: 28),
                    const Spacer(),
                    if (!_isLast)
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: .82),
                          minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
                          textStyle: MarketText.label(size: 14),
                        ),
                        child: const Text('Atla'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (_, index) => _Illustration(icon: _items[index].icon),
                ),
              ),
              // Panel de kaydırılabilir: yatay sürükleme sayfayı değiştirir
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200) _goTo(_page + 1);
                  if (velocity > 200) _goTo(_page - 1);
                },
                child: Container(
                  height: panelHeight,
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      narrow ? 20 : 24, narrow ? 22 : 28, narrow ? 20 : 24, 16 + padding.bottom),
                  decoration: const BoxDecoration(
                    color: MarketPalette.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [...previous, if (current != null) current],
                            ),
                            child: Column(
                              key: ValueKey(_page),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  liveRegion: true,
                                  child: Text(
                                    item.title,
                                    style: narrow
                                        ? MarketText.title(size: 24)
                                        : MarketText.display(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.description,
                                  style: MarketText.body(
                                    color: MarketPalette.muted,
                                    size: narrow ? 14 : 15,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Semantics(
                            label: 'Sayfa ${_page + 1} / ${_items.length}',
                            child: ExcludeSemantics(
                              child: Row(
                                children: List.generate(
                                  _items.length,
                                  (index) => AnimatedContainer(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 250),
                                    width: index == _page ? 28 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 7),
                                    decoration: BoxDecoration(
                                      color: index == _page
                                          ? MarketPalette.green
                                          : MarketPalette.lineStrong,
                                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _isLast ? _finish() : _goTo(_page + 1),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, MarketSize.button),
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLast ? 'Alışverişe başla' : 'Devam',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sayfa görseli: ilk sayfada maskot, diğerlerinde lime kutuda simge. Boyut
/// kalan alana göre ayarlanır (küçük ekranda kesilmez).
class _Illustration extends StatelessWidget {
  final IconData? icon;

  const _Illustration({required this.icon});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = math.min(constraints.maxHeight, constraints.maxWidth);
        final size = icon == null
            ? math.min(220.0, room * .78)
            : math.min(160.0, room * .62);
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Görselin arkasındaki yumuşak ışık (açılış ekranındaki gibi)
              Container(
                width: size * 1.6,
                height: size * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MarketPalette.lime.withValues(alpha: .26),
                      MarketPalette.lime.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              if (icon == null)
                MarketMascot(size: size)
              else
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: MarketPalette.lime,
                    borderRadius: BorderRadius.circular(MarketRadius.xl),
                  ),
                  child: Icon(icon, size: size * .48, color: MarketPalette.greenDeep),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Açılış ekranındaki dekor halkalarının aynısı.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lime = Paint()..color = MarketPalette.lime.withValues(alpha: .09);
    final green = Paint()..color = MarketPalette.green.withValues(alpha: .25);
    canvas.drawCircle(Offset(size.width * .92, size.height * .06), 150, lime);
    canvas.drawCircle(Offset(size.width * .02, size.height * .34), 170, green);
    canvas.drawCircle(Offset(size.width * .14, size.height * .1), 34, lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
