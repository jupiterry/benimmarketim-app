import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/chat_viewmodel.dart';
import 'market_palette.dart';

class MarketHomeHeader extends StatelessWidget {
  const MarketHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, chat, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF063F2B),
                Color(0xFF075B39),
                Color(0xFF117A48),
              ],
              stops: [0, .58, 1],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -95,
                right: -65,
                child: _DecorativeCircle(size: 245, opacity: .055),
              ),
              const Positioned(
                left: -58,
                bottom: -95,
                child: _DecorativeCircle(size: 205, opacity: .04),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: MarketPalette.lime,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: MarketPalette.greenDeep,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BENİM MARKETİM',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Devrek • Mahallenin marketi',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: .66),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderActionButton(
                            icon: Icons.favorite_border_rounded,
                            onTap: () => context.push('/favorites'),
                          ),
                          const SizedBox(width: 8),
                          _HeaderActionButton(
                            icon: Icons.support_agent_rounded,
                            badgeCount: chat.totalUnreadCount,
                            onTap: () => context.push('/chat'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Merhaba',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Bugün neye ihtiyacın var?',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        button: true,
                        label: 'Ürünlerde ara',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/search'),
                            borderRadius: BorderRadius.circular(19),
                            child: Ink(
                              height: 58,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .14),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: MarketPalette.green,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Ürün, kategori veya marka ara',
                                      style: GoogleFonts.inter(
                                        color: MarketPalette.muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: MarketPalette.greenSoft,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.tune_rounded,
                                      color: MarketPalette.greenDark,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .12),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: MarketPalette.orange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MarketPalette.greenDeep,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
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
