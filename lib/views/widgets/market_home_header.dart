import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/home_page_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'home_quick_carts.dart';
import 'market_discovery_section.dart';
import 'market_mascot.dart';
import 'market_ui.dart';

/// Ana sayfanın kayıp giden üst kısmı: marka, teslimat yeri, selamlama ve
/// mağaza / sepet durumu. Arama ve asistan, altındaki sabit bantta durur
/// ([HomeSearchBandDelegate]); ikisi aynı düz koyu yeşil tondadır, aralarında
/// ek yeri görünmez.
class MarketHomeHeader extends StatefulWidget {
  const MarketHomeHeader({super.key});

  @override
  State<MarketHomeHeader> createState() => _MarketHomeHeaderState();
}

class _MarketHomeHeaderState extends State<MarketHomeHeader> {
  /// Son siparişte seçilen teslimat noktası ('girlsDorm' / 'boysDorm').
  String? _lastPoint;

  @override
  void initState() {
    super.initState();
    _loadLastPoint();
    homeRefreshSignal.addListener(_loadLastPoint);
  }

  @override
  void dispose() {
    homeRefreshSignal.removeListener(_loadLastPoint);
    super.dispose();
  }

  Future<void> _loadLastPoint() async {
    String? point;
    try {
      final prefs = await SharedPreferences.getInstance();
      point = prefs.getString(lastDeliveryPointPrefsKey);
    } catch (_) {
      return;
    }
    if (mounted && point != _lastPoint) setState(() => _lastPoint = point);
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<ChatViewModel, int>((c) => c.totalUnreadCount);
    final name = context.select<AuthViewModel, String?>((a) => a.user?.name);
    final firstName = (name ?? '').trim().split(RegExp(r'\s+')).first;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final gutter = homeGutter(context);

    final place = context.select<SettingsViewModel, String?>((settings) {
      return switch (_lastPoint) {
        'girlsDorm' => settings.girlsDormName,
        'boysDorm' => settings.boysDormName,
        _ => null,
      };
    });
    // Dar ekranda ve büyük yazıda şehir adı düşer, satır kesilmez
    final roomy =
        !narrow && MediaQuery.textScalerOf(context).scale(1) <= 1.15;
    final placeText =
        place ?? (roomy ? 'Devrek • Yurda teslimat' : 'Yurda teslimat');

    return ColoredBox(
      color: MarketPalette.greenDeep,
      child: ClipRect(
        child: Stack(
          children: [
            const Positioned(
              top: 4,
              right: -70,
              child: _DecorativeCircle(size: 176, opacity: .05),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 46),
                    child: Row(
                      children: [
                        MarketMascot(size: narrow ? 36 : 40),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MarketWordmark(height: narrow ? 26 : 28),
                              const SizedBox(height: 2),
                              Semantics(
                                label: 'Teslimat: $placeText',
                                excludeSemantics: true,
                                child: Row(
                                  children: [
                                    const Icon(Icons.place_rounded,
                                        size: 12, color: MarketPalette.lime),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        placeText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MarketText.caption(
                                          color: Colors.white
                                              .withValues(alpha: .72),
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        MarketHeaderButton(
                          icon: Icons.favorite_border_rounded,
                          tooltip: 'Favorilerim',
                          onTap: () => context.push('/favorites'),
                        ),
                        const SizedBox(width: 8),
                        MarketHeaderButton(
                          icon: Icons.support_agent_rounded,
                          tooltip: 'Canlı destek',
                          badgeCount: unread,
                          onTap: () => context.push('/chat'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    header: true,
                    child: Text(
                      firstName.isEmpty
                          ? _greeting()
                          : '${_greeting()}, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.title(
                        color: Colors.white,
                        size: narrow ? 22 : 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: MarketSpace.md),
                  const _StoreStatusRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Türkiye saatine göre selamlama ("İyi geceler" bir vedalaşma olduğu için
  /// akşam ve gece "İyi akşamlar" kullanılır).
  static String _greeting() {
    final hour = turkeyTime(DateTime.now()).hour;
    if (hour >= 5 && hour < 11) return 'Günaydın';
    if (hour >= 11 && hour < 18) return 'Merhaba';
    return 'İyi akşamlar';
  }
}

/// Mağaza saatleri ve sepetin en az tutara uzaklığı: müşterinin sipariş
/// vermeden önce bilmesi gerekenler.
class _StoreStatusRow extends StatelessWidget {
  const _StoreStatusRow();

  @override
  Widget build(BuildContext context) {
    final total = context.select<CartViewModel, double>((c) => c.totalPrice);
    return Consumer<SettingsViewModel>(
      builder: (context, settings, _) {
        final status = HomeStoreStatus.of(settings);
        final minimum = settings.minimumOrderAmount;

        final Widget statusChip;
        if (status.allDay) {
          statusChip = const _HeaderChip(
            leading: _Dot(color: MarketPalette.lime),
            label: '7/24 açık',
          );
        } else if (status.open && status.minutesToClose <= 60) {
          statusChip = _HeaderChip(
            leading: const _Dot(color: MarketPalette.orange),
            label: 'Kapanışa ${status.minutesToClose} dk',
            background: MarketPalette.orange.withValues(alpha: .18),
          );
        } else if (status.open) {
          statusChip = _HeaderChip(
            leading: const _Dot(color: MarketPalette.lime),
            label: 'Açık • Kapanış ${status.closesAt}',
          );
        } else {
          statusChip = _HeaderChip(
            leading: const _Dot(color: MarketPalette.orange),
            label: 'Kapalı • Açılış ${status.opensAt}',
          );
        }

        final Widget basketChip;
        if (total <= 0) {
          basketChip = _HeaderChip(
            leading: Icon(
              Icons.shopping_basket_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: .85),
            ),
            label: 'Min. sepet ${formatTlShort(minimum)}',
          );
        } else if (total < minimum) {
          basketChip = _HeaderChip(
            leading: Icon(
              Icons.shopping_basket_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: .85),
            ),
            label: 'Min. sepete ${formatTlShort(minimum - total)} kaldı',
          );
        } else {
          basketChip = const _HeaderChip(
            leading: Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: MarketPalette.lime,
            ),
            label: 'Min. sepet tamam',
          );
        }

        return Wrap(
          spacing: MarketSpace.sm,
          runSpacing: MarketSpace.sm,
          children: [statusChip, basketChip],
        );
      },
    );
  }
}

/// Sipariş saatleri durumunun tek hesabı (başlık çipi ve kapalı uyarısı).
/// Saatler Türkiye saatine göre (UTC+3), gece yarısını geçen aralıklar dahil.
class HomeStoreStatus {
  final bool allDay;
  final bool open;

  /// Kapanışa kalan dakika (açıkken anlamlı).
  final int minutesToClose;
  final String opensAt;
  final String closesAt;

  const HomeStoreStatus._({
    required this.allDay,
    required this.open,
    required this.minutesToClose,
    required this.opensAt,
    required this.closesAt,
  });

  factory HomeStoreStatus.of(SettingsViewModel settings) {
    String hhmm(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final allDay = settings.orderStartHour == 0 &&
        settings.orderStartMinute == 0 &&
        settings.orderEndHour == 0 &&
        settings.orderEndMinute == 0;
    final now = turkeyTime(DateTime.now());
    final current = now.hour * 60 + now.minute;
    final end = settings.orderEndHour * 60 + settings.orderEndMinute;
    return HomeStoreStatus._(
      allDay: allDay,
      open: settings.isWithinOrderHours,
      minutesToClose: (end - current + 1440) % 1440,
      opensAt: hhmm(settings.orderStartHour, settings.orderStartMinute),
      closesAt: hhmm(settings.orderEndHour, settings.orderEndMinute),
    );
  }
}

/// Mağaza kapalıyken akışın en üstünde duran uyarı: sepet hazırlanabilir ama
/// sipariş açılış saatinde verilebilir.
class HomeStoreClosedNotice extends StatelessWidget {
  const HomeStoreClosedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final status = HomeStoreStatus.of(context.watch<SettingsViewModel>());
    final show = !status.open && !status.allDay;
    final gutter = homeGutter(context);
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show
          ? Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.lg, gutter, 0),
              child: MarketNotice.warning(
                icon: Icons.schedule_rounded,
                text: 'Şu an sipariş almıyoruz. Açılış saatimiz '
                    '${status.opensAt}; sepetini şimdiden hazırlayabilirsin.',
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final Widget leading;
  final String label;
  final Color? background;

  const _HeaderChip({
    required this.leading,
    required this.label,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(MarketRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MarketText.label(
                color: Colors.white,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Ana sayfada başlığın altında duran arama + asistan bandı. Uzun sayfada
/// her yerden aramaya ve asistana tek dokunuşla ulaşılsın diye yeterince
/// uzun ekranlarda üstte sabit kalır; kısa ekranlarda yukarı kaydırınca
/// geri gelir.
class HomeSearchBandDelegate extends SliverPersistentHeaderDelegate {
  final double gutter;
  final bool compactAssistant;
  final bool reduceMotion;

  const HomeSearchBandDelegate({
    required this.gutter,
    required this.compactAssistant,
    required this.reduceMotion,
  });

  static const double extent = 72;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ColoredBox(
        // Köşelerin arkası, içerik henüz bandın altına girmemişken zemin
        // rengindedir; içerik altına girince köşelerde görünür.
        color: overlapsContent ? Colors.transparent : MarketPalette.canvas,
        child: AnimatedContainer(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: MarketPalette.greenDeep,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(MarketRadius.xl),
            ),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep
                    .withValues(alpha: overlapsContent ? .18 : 0),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 16),
          child: Row(
            children: [
              const Expanded(child: _SearchField()),
              const SizedBox(width: MarketSpace.sm),
              _AssistantButton(compact: compactAssistant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeSearchBandDelegate oldDelegate) =>
      oldDelegate.gutter != gutter ||
      oldDelegate.compactAssistant != compactAssistant ||
      oldDelegate.reduceMotion != reduceMotion;
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ürün ara',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: InkWell(
          onTap: () => context.push('/search'),
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded,
                    color: MarketPalette.green, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ürün veya marka ara',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.body(color: MarketPalette.muted, size: 14),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bantta, aramanın yanındaki "Asistan" düğmesi (eski yüzen maskot
/// düğmesinin yerini alır: ürünlerin "+" düğmelerini örtmez).
class _AssistantButton extends StatelessWidget {
  final bool compact;

  const _AssistantButton({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Benim Asistanım',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Benim Asistanım',
        excludeFromSemantics: true,
        child: Material(
          color: MarketPalette.lime,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: InkWell(
            onTap: () => context.push('/cart-assistant'),
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: SizedBox(
              height: 52,
              width: compact ? 52 : null,
              child: compact
                  ? const Icon(Icons.auto_awesome_rounded,
                      size: 22, color: MarketPalette.greenDeep)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 20, color: MarketPalette.greenDeep),
                          const SizedBox(width: 6),
                          Text(
                            'Asistan',
                            style: MarketText.label(
                              color: MarketPalette.greenDeep,
                              size: 13,
                              weight: FontWeight.w800,
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

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
