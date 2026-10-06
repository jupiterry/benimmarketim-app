import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../viewmodels/category_viewmodel.dart';
import 'category_presentation.dart';
import 'market_ui.dart';

class MarketQuickActions extends StatelessWidget {
  const MarketQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.receipt_long_rounded,
              label: 'Siparişler',
              color: MarketPalette.greenDark,
              background: MarketPalette.greenSoft,
              onTap: () => context.push('/orders'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.favorite_rounded,
              label: 'Favoriler',
              color: MarketPalette.pink,
              background: MarketPalette.pinkSoft,
              onTap: () => context.push('/favorites'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.print_rounded,
              label: 'Fotokopi',
              color: MarketPalette.blue,
              background: MarketPalette.blueSoft,
              onTap: () => context.push('/photocopy-upload'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.card_giftcard_rounded,
              label: 'Davet et',
              color: MarketPalette.orangeInk,
              background: MarketPalette.orangeSoft,
              onTap: () => context.push('/referral'),
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
        final activeCategories = _pinnedFirst(
          _mergeSameName(viewModel.getActiveCategories()),
        );
        final categories = activeCategories.take(8).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketSectionHeader(
                eyebrow: 'KATEGORİLER',
                title: 'Hızlı keşfet',
                subtitle: 'Aradığın ürüne birkaç dokunuşta ulaş',
                actionLabel: activeCategories.length > 8 ? 'Tümü' : null,
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
                    const spacing = 10.0;
                    final itemWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                            columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 12,
                      children: List.generate(categories.length, (index) {
                        final category = categories[index];
                        return SizedBox(
                          width: itemWidth,
                          height: 112,
                          child: _CategoryTile(
                            category: category,
                            emoji: categoryEmoji(category.name),
                            colorIndex: index,
                            onTap: () => context.push(
                              '/category-products',
                              extra: category,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Aynı görünen ada sahip kategoriler (ör. "tozicecekler" ve yazım hatalı
  /// "tozicecekleri") tek kutuda gösterilir; ürün sayısı en çok olan kalır.
  static List<Category> _mergeSameName(List<Category> categories) {
    final best = <String, Category>{};
    for (final category in categories) {
      final label = categoryDisplayName(category.name);
      final current = best[label];
      if (current == null || (category.order ?? 0) > (current.order ?? 0)) {
        best[label] = category;
      }
    }
    return categories.where((c) => best[categoryDisplayName(c.name)] == c).toList();
  }

  /// "Yiyecekler" her zaman en başta; diğerlerinin sırası korunur.
  static const _pinnedKeys = ['yiyecekler'];

  static List<Category> _pinnedFirst(List<Category> categories) {
    final pinned = <Category>[];
    for (final key in _pinnedKeys) {
      pinned.addAll(
        categories.where((c) => normalizedCategoryKey(c.name) == key),
      );
    }
    return [...pinned, ...categories.where((c) => !pinned.contains(c))];
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
                  top: Radius.circular(MarketRadius.xl),
                ),
              ),
              child: Column(
                children: [
                  const _SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tüm kategoriler', style: MarketText.title()),
                              const SizedBox(height: 3),
                              Text(
                                '${categories.length} kategoriyi keşfet',
                                style: MarketText.caption(size: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
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
                            mainAxisExtent: 124,
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: MarketPalette.lineStrong,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
      ),
    );
  }
}

/// Ana sayfa bölüm başlığı (eski API korunur; görünüm [MarketSectionTitle]).
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
    return MarketSectionTitle(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
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
    return MarketCard(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          MarketIconTile(icon: icon, size: 44),
          const SizedBox(width: 13),
          Expanded(
            child: Text(text, style: MarketText.body(color: MarketPalette.muted, size: 13)),
          ),
          TextButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yenile'),
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
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: MarketPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.md),
          side: const BorderSide(color: MarketPalette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MarketIconTile(
                  icon: icon,
                  size: 38,
                  background: background,
                  foreground: color,
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(size: 12),
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

  @override
  Widget build(BuildContext context) {
    final background = backgrounds[colorIndex % backgrounds.length];
    final name = categoryDisplayName(category.name);

    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        child: Column(
          children: [
            Ink(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(MarketRadius.lg),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32, height: 1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: MarketText.label(size: 12, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
        mainAxisExtent: 112,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => const Column(
        children: [
          MarketSkeleton(width: 70, height: 70, radius: MarketRadius.lg),
          SizedBox(height: 10),
          MarketSkeleton(width: 54, height: 10, radius: MarketRadius.xs),
        ],
      ),
    );
  }
}
