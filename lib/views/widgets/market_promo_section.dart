import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banner.dart' as models;
import '../../viewmodels/banner_viewmodel.dart';
import 'market_palette.dart';

class MarketPromoSection extends StatefulWidget {
  const MarketPromoSection({super.key});

  @override
  State<MarketPromoSection> createState() => _MarketPromoSectionState();
}

class _MarketPromoSectionState extends State<MarketPromoSection> {
  final PageController _controller = PageController(viewportFraction: .92);
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
            child: _PromoSkeleton(),
          );
        }

        final banners =
            viewModel.banners.where((banner) => banner.isActive).toList();

        if (banners.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: _FallbackPromo(),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            children: [
              SizedBox(
                height: 190,
                child: PageView.builder(
                  controller: _controller,
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
              if (banners.length > 1) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (index) {
                    final active = index == _activeIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: active ? 24 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color:
                            active ? MarketPalette.green : MarketPalette.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),
              ],
            ],
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
    final hasText =
        banner.title.trim().isNotEmpty || banner.subtitle.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: banner.linkUrl?.trim().isNotEmpty == true ? onTap : null,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: MarketPalette.greenDark,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.greenDeep.withValues(alpha: .14),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  banner.image,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, __, ___) => const _FallbackPromo(),
                ),
                if (hasText)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.transparent,
                          Color(0x3D000000),
                          Color(0xC7000000),
                        ],
                      ),
                    ),
                  ),
                if (hasText)
                  Positioned(
                    left: 20,
                    right: 44,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MarketPalette.lime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SANA ÖZEL',
                            style: GoogleFonts.inter(
                              color: MarketPalette.greenDeep,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        if (banner.title.trim().isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(
                            banner.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                        ],
                        if (banner.subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            banner.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackPromo extends StatelessWidget {
  const _FallbackPromo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MarketPalette.greenDark, MarketPalette.green],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            bottom: -72,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MarketPalette.lime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'BENİM MARKETİM',
                  style: GoogleFonts.inter(
                    color: MarketPalette.greenDeep,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'İhtiyacın neyse\nhepsi burada.',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kolayca seç, güvenle sipariş ver.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: .74),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Positioned(
            right: 8,
            bottom: 8,
            child: Icon(
              Icons.shopping_basket_rounded,
              color: MarketPalette.lime,
              size: 72,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoSkeleton extends StatelessWidget {
  const _PromoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEE9),
        borderRadius: BorderRadius.circular(26),
      ),
    );
  }
}
