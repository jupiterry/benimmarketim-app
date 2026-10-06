import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banner.dart' as models;
import '../../viewmodels/banner_viewmodel.dart';
import 'market_ui.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading && viewModel.banners.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: AspectRatio(
              aspectRatio: _bannerAspect,
              child: MarketSkeleton(height: double.infinity, radius: MarketRadius.lg),
            ),
          );
        }

        final banners =
            viewModel.banners.where((banner) => banner.isActive).toList();

        if (banners.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: AspectRatio(
              aspectRatio: _bannerAspect,
              child: _FallbackPromo(),
            ),
          );
        }

        if (banners.length == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: AspectRatio(
              aspectRatio: _bannerAspect,
              child: _BannerCard(
                banner: banners.first,
                onTap: () => _openLink(banners.first.linkUrl),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth * .9 - 12;
              return Column(
                children: [
                  SizedBox(
                    height: itemWidth / _bannerAspect,
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
                            left: index == 0 ? 20 : 6,
                            right: index == banners.length - 1 ? 20 : 6,
                          ),
                          child: _BannerCard(
                            banner: banners[index],
                            onTap: () => _openLink(banners[index].linkUrl),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(banners.length, (index) {
                      final active = index == _activeIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: active ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? MarketPalette.green
                              : MarketPalette.lineStrong,
                          borderRadius: BorderRadius.circular(MarketRadius.xs),
                        ),
                      );
                    }),
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
  final VoidCallback onTap;

  const _BannerCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasLink = banner.linkUrl?.trim().isNotEmpty == true;
    final label = [banner.title, banner.subtitle]
        .where((text) => text.trim().isNotEmpty)
        .join('. ');

    return Semantics(
      label: label.isEmpty ? 'Kampanya' : label,
      button: hasLink,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withValues(alpha: .12),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                    banner.image,
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
    final heading = title.trim().isNotEmpty ? title : 'İhtiyacın neyse\nhepsi burada.';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  heading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.title(color: Colors.white, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(
                    color: Colors.white.withValues(alpha: .8),
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
