import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../viewmodels/favorites_viewmodel.dart';
import 'widgets/market_palette.dart';
import 'widgets/market_product_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer<FavoritesViewModel>(
        builder: (context, favorites, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _FavoritesHeader(
                  count: favorites.favoritesCount,
                  onBack: () => context.pop(),
                  onClear: favorites.favorites.isEmpty
                      ? null
                      : () => _showClearDialog(context, favorites),
                ),
              ),
              if (favorites.isLoading)
                const SliverFillRemaining(child: _FavoritesLoading())
              else if (favorites.favorites.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFavorites(
                    onExplore: () => _goShopping(context),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KAYDETTİKLERİN',
                                style: GoogleFonts.inter(
                                  color: MarketPalette.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Favori ürünlerin',
                                style: GoogleFonts.manrope(
                                  color: MarketPalette.ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFECF0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${favorites.favoritesCount} ürün',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD84B68),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 920
                          ? 4
                          : width >= 620
                              ? 3
                              : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 304,
                          crossAxisSpacing: 13,
                          mainAxisSpacing: 13,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => MarketProductCard(
                            product: favorites.favorites[index],
                          ),
                          childCount: favorites.favorites.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _goShopping(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showClearDialog(
    BuildContext context,
    FavoritesViewModel favorites,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Color(0xFFFFECF0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.heart_broken_rounded,
            color: Color(0xFFD84B68),
          ),
        ),
        title: Text(
          'Favoriler temizlensin mi?',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: MarketPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Kaydettiğin tüm ürünler favori listenden kaldırılacak.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: MarketPalette.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              favorites.clearFavorites();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Favori listen temizlendi',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: MarketPalette.greenDark,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: MarketPalette.red,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  final int count;
  final VoidCallback onBack;
  final VoidCallback? onClear;

  const _FavoritesHeader({
    required this.count,
    required this.onBack,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        25,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF063F2B),
            Color(0xFF075B39),
            Color(0xFF117A48),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeaderButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const Spacer(),
              if (onClear != null)
                _HeaderButton(
                  icon: Icons.delete_sweep_outlined,
                  onTap: onClear!,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: MarketPalette.lime,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: MarketPalette.greenDeep,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favorilerim',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 0
                          ? 'Beğendiklerini burada biriktir'
                          : '$count ürün seni bekliyor',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: .68),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  final VoidCallback onExplore;

  const _EmptyFavorites({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 35, 28, 60),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECF0),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      color: Color(0xFFD84B68),
                      size: 62,
                    ),
                    Positioned(
                      right: 21,
                      top: 22,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: MarketPalette.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: MarketPalette.greenDeep,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 27),
              Text(
                'Favori listen henüz boş',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Beğendiğin ürünlerdeki kalp simgesine dokun. Sonra hepsine buradan kolayca ulaş.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: MarketPalette.muted,
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onExplore,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(230, 56),
                  backgroundColor: MarketPalette.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.explore_rounded),
                label: Text(
                  'Ürünleri Keşfet',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesLoading extends StatelessWidget {
  const _FavoritesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: MarketPalette.green),
    );
  }
}
