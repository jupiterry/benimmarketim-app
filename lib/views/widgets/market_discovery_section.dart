import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../viewmodels/category_viewmodel.dart';
import 'category_presentation.dart';
import 'market_palette.dart';

class MarketQuickActions extends StatelessWidget {
  const MarketQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.receipt_long_rounded,
              label: 'Siparişlerim',
              color: MarketPalette.green,
              background: MarketPalette.greenSoft,
              onTap: () => context.push('/orders'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.favorite_rounded,
              label: 'Favorilerim',
              color: const Color(0xFFD84B68),
              background: const Color(0xFFFFECF0),
              onTap: () => context.push('/favorites'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.print_rounded,
              label: 'Fotokopi',
              color: const Color(0xFF4C6FFF),
              background: const Color(0xFFEDF0FF),
              onTap: () => context.push('/photocopy-upload'),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketQuickDiscovery extends StatelessWidget {
  const MarketQuickDiscovery({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryViewModel>(
      builder: (context, viewModel, _) {
        final activeCategories = viewModel.getActiveCategories();
        final categories = activeCategories.take(8).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketSectionHeader(
                eyebrow: 'KATEGORİLER',
                title: 'Hızlı keşfet',
                subtitle: 'Aradığın ürüne birkaç dokunuşta ulaş',
                actionLabel: activeCategories.length > 8 ? 'Tümünü gör' : null,
                onAction: activeCategories.length > 8
                    ? () => _showAllCategories(context, activeCategories)
                    : null,
              ),
              const SizedBox(height: 16),
              if (viewModel.isLoading && categories.isEmpty)
                const _CategorySkeletonGrid()
              else if (categories.isEmpty)
                MarketEmptyInlineCard(
                  icon: Icons.category_outlined,
                  text: 'Kategoriler şu anda görüntülenemiyor.',
                  onRetry: viewModel.loadCategories,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 650 ? 6 : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 104,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryTile(
                          category: category,
                          emoji: categoryEmoji(category.name),
                          colorIndex: index,
                          onTap: () => context.push(
                            '/category-products',
                            extra: category,
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAllCategories(
    BuildContext pageContext,
    List<Category> categories,
  ) {
    showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .82,
          minChildSize: .55,
          maxChildSize: .94,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: MarketPalette.canvas,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DAD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 17, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tüm kategoriler',
                                style: GoogleFonts.manrope(
                                  color: MarketPalette.ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                              Text(
                                '${categories.length} kategoriyi keşfet',
                                style: GoogleFonts.inter(
                                  color: MarketPalette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 620 ? 5 : 3;
                        return GridView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                          itemCount: categories.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: 122,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                          ),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _CategoryTile(
                              category: category,
                              emoji: categoryEmoji(category.name),
                              colorIndex: index,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                pageContext.push(
                                  '/category-products',
                                  extra: category,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class MarketSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MarketSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.inter(
                  color: MarketPalette.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 21,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: MarketPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
      ],
    );
  }
}

class MarketEmptyInlineCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<void> Function() onRetry;

  const MarketEmptyInlineCard({
    super.key,
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MarketPalette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MarketPalette.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: MarketPalette.greenDark),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: MarketPalette.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: MarketPalette.surface,
            border: Border.all(color: MarketPalette.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: MarketPalette.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final String emoji;
  final int colorIndex;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.emoji,
    required this.colorIndex,
    required this.onTap,
  });

  static const backgrounds = [
    Color(0xFFE9F6ED),
    Color(0xFFFFF1DF),
    Color(0xFFEAF0FF),
    Color(0xFFFFEDEF),
    Color(0xFFE8F7F7),
    Color(0xFFF3ECFF),
    Color(0xFFFFF7D9),
    Color(0xFFEDF3E6),
  ];

  static const foregrounds = [
    Color(0xFF168A52),
    Color(0xFFCC6D1B),
    Color(0xFF4667D9),
    Color(0xFFD65069),
    Color(0xFF18888C),
    Color(0xFF7B52C7),
    Color(0xFFB98512),
    Color(0xFF5B7C3D),
  ];

  @override
  Widget build(BuildContext context) {
    final background = backgrounds[colorIndex % backgrounds.length];
    final foreground = foregrounds[colorIndex % foregrounds.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Ink(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: foreground.withValues(alpha: .10),
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 31, height: 1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                categoryDisplayName(category.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: MarketPalette.ink,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySkeletonGrid extends StatelessWidget {
  const _CategorySkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 104,
        crossAxisSpacing: 10,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, __) => Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEE9),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: 54,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E7E3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
