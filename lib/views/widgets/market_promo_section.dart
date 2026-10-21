import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banner.dart' as models;
import '../../viewmodels/banner_viewmodel.dart';
import 'market_ui.dart';
import '../../services/image_url.dart';

/// Banner görselleri yönetim panelinde metinle birlikte tasarlanıyor; bu yüzden
/// görselin üstüne ayrıca yazı bindirilmez (çift, okunmaz metin oluşuyordu).
/// Başlık/alt başlık erişilebilirlik etiketi ve görsel yüklenemezse yedek
/// kart olarak kullanılır.
const double _bannerAspect = 2.05;

class MarketPromoSection extends StatefulWidget {
  const MarketPromoSection({super.key});

  @override
  State<MarketPromoSection> createState() => _MarketPromoSectionState();
}

class _MarketPromoSectionState extends State<MarketPromoSection> {
  final PageController _controller = PageController(viewportFraction: .9);
  int _activeIndex = 0;

  /// Kampanyalar 6 sn'de bir kendiliğinden kayar. Kullanıcı kaydırınca
  /// durur, 8 sn sonra devam eder. Tek kampanyada, hareket azaltıldığında
  /// ve sekme/sayfa görünmüyorken (TickerMode kapalı) çalışmaz.
  static const Duration _autoplayEvery = Duration(seconds: 6);
  static const Duration _resumeAfter = Duration(seconds: 8);
  Timer? _autoplay;
  Timer? _resume;
  int _bannerCount = 0;
  bool _autoplayAllowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autoplayAllowed = TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Zamanlayıcıyı koşullara göre başlatır ya da durdurur (tekrar
  /// çağrılması güvenlidir).
  void _syncAutoplay() {
    final shouldRun = _autoplayAllowed && _bannerCount > 1 && _resume == null;
    if (!shouldRun) {
      _autoplay?.cancel();
      _autoplay = null;
      return;
    }
    _autoplay ??= Timer.periodic(_autoplayEvery, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_controller.hasClients || _bannerCount < 2) return;
    final next = (_activeIndex + 1) % _bannerCount;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Kullanıcı kampanyaları kendisi kaydırınca otomatik geçiş bir süre durur.
  bool _onScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails == null) return false;
    _autoplay?.cancel();
    _autoplay = null;
    _resume?.cancel();
    _resume = Timer(_resumeAfter, () {
      _resume = null;
      if (mounted) _syncAutoplay();
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Consumer<BannerViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading && viewModel.banners.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
            child: const MarketSkeletonPulse(
              semanticLabel: 'Kampanyalar yükleniyor',
              child: AspectRatio(
                aspectRatio: _bannerAspect,
                child: MarketSkeleton(
                    height: double.infinity, radius: MarketRadius.lg),
              ),
            ),
          );
        }

        final banners =
            viewModel.banners.where((banner) => banner.isActive).toList();
        if (_bannerCount != banners.length) {
          _bannerCount = banners.length;
          if (_activeIndex >= _bannerCount) _activeIndex = 0;
          _syncAutoplay();
        }

        // Süren kampanya yoksa yer kaplamaz (boş, tıklanmayan bir tanıtım
        // kartı göstermek yerine).
        if (banners.isEmpty) return const SizedBox.shrink();

        if (banners.length == 1) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
            child: AspectRatio(
              aspectRatio: _bannerAspect,
              child: _BannerCard(
                banner: banners.first,
                position: null,
                onTap: () => _openLink(banners.first.linkUrl),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: MarketSpace.xxl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth * .9 - 12;
              return Column(
                children: [
                  SizedBox(
                    height: itemWidth / _bannerAspect,
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: _onScrollStart,
                      child: PageView.builder(
                        controller: _controller,
                        padEnds: false,
                        itemCount: banners.length,
                        onPageChanged: (value) {
                          if (mounted) setState(() => _activeIndex = value);
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? gutter : 6,
                              right: index == banners.length - 1 ? gutter : 6,
                            ),
                            child: _BannerCard(
                              banner: banners[index],
                              position: '${index + 1}/${banners.length}',
                              onTap: () => _openLink(banners[index].linkUrl),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(banners.length, (index) {
                        final active = index == _activeIndex;
                        return AnimatedContainer(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: active ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: active
                                ? MarketPalette.green
                                : MarketPalette.lineStrong,
                            borderRadius:
                                BorderRadius.circular(MarketRadius.pill),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openLink(String? value) async {
    if (value == null || value.trim().isEmpty) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _BannerCard extends StatelessWidget {
  final models.Banner banner;

  /// Birden çok kampanya varsa "1/3" gibi sırası (ekran okuyucu için).
  final String? position;
  final VoidCallback onTap;

  const _BannerCard({
    required this.banner,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = banner.linkUrl?.trim().isNotEmpty == true;
    final title = [banner.title, banner.subtitle]
        .where((text) => text.trim().isNotEmpty)
        .join('. ');
    final prefix = position == null ? 'Kampanya' : 'Kampanya $position';
    final label = title.isEmpty ? prefix : '$prefix: $title';

    return Semantics(
      label: label,
      button: hasLink,
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: MarketPalette.greenDark,
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: hasLink ? onTap : null,
            child: banner.image.trim().isEmpty
                ? _FallbackPromo(title: banner.title, subtitle: banner.subtitle)
                : Image.network(
                    optimizedImageUrl(
                      banner.image,
                      width: MarketImageSize.banner,
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 1000,
                    errorBuilder: (_, __, ___) => _FallbackPromo(
                      title: banner.title,
                      subtitle: banner.subtitle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FallbackPromo extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FallbackPromo({this.title = '', this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final heading =
        title.trim().isNotEmpty ? title : 'İhtiyacın neyse\nhepsi burada.';
    final body = subtitle.trim().isNotEmpty
        ? subtitle
        : 'Kolayca seç, güvenle sipariş ver.';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MarketPalette.greenDark, MarketPalette.green],
        ),
        borderRadius: BorderRadius.circular(MarketRadius.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -70,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          const Positioned(
            right: 4,
            bottom: 0,
            child: Icon(
              Icons.shopping_basket_rounded,
              color: MarketPalette.lime,
              size: 64,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 72),
            // Dar ekranda ve büyük yazıda kart kısalır; metin tek satıra iner
            child: LayoutBuilder(
              builder: (context, box) {
                final tight = box.maxHeight < 130;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      heading,
                      maxLines: tight ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.title(
                          color: Colors.white, size: tight ? 18 : 22),
                    ),
                    SizedBox(height: tight ? 4 : 6),
                    Text(
                      body,
                      maxLines: tight ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.caption(
                        color: Colors.white.withValues(alpha: .8),
                        size: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
