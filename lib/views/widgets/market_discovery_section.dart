import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import 'category_presentation.dart';
import 'market_ui.dart';

/// Ana sayfa bölümlerinin kenar boşluğu: 360 pt'den dar telefonda 16,
/// diğerlerinde 20.
double homeGutter(BuildContext context) => MarketSpace.gutterOf(context);

// ---------------------------------------------------------------------------
// Kategoriler
// ---------------------------------------------------------------------------

class MarketQuickDiscovery extends StatelessWidget {
  const MarketQuickDiscovery({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    return Consumer<CategoryViewModel>(
      builder: (context, viewModel, _) {
        final categories = _pinnedFirst(
          _mergeSameName(viewModel.getActiveCategories()),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MarketSectionHeader(title: 'Kategoriler'),
              const SizedBox(height: MarketSpace.md),
              if (viewModel.isLoading && categories.isEmpty)
                const _CategoryGrid.skeleton()
              else if (categories.isEmpty)
                MarketEmptyInlineCard(
                  icon: Icons.category_outlined,
                  text: 'Kategoriler yüklenemedi.',
                  onRetry: viewModel.loadCategories,
                )
              else
                _CategoryGrid(
                  categories: categories,
                  onSelected: (category) =>
                      context.push('/category-products', extra: category),
                  onShowAll: () => _showAllCategories(context, categories),
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
    showMarketSheet<void>(
      pageContext,
      builder: (sheetContext) => MarketSheetScaffold(
        header: MarketSheetHeader(
          title: 'Tüm kategoriler',
          subtitle: '${categories.length} kategori',
        ),
        body: _CategoryGrid(
          categories: categories,
          sheet: true,
          onSelected: (category) {
            Navigator.pop(sheetContext);
            pageContext.push('/category-products', extra: category);
          },
        ),
      ),
    );
  }
}

/// Kategori ızgarası. Sütun sayısı ekran genişliğine ve yazı boyutuna göre
/// seçilir (dar ekranda ve büyük yazıda 3 sütun: adlar kelime ortasından
/// bölünmez). Ana sayfada iki satır gösterilir; sığmayanlar son kutudaki
/// "Tümü" ile açılan alt sayfadadır.
class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final ValueChanged<Category>? onSelected;
  final VoidCallback? onShowAll;
  final bool sheet;
  final bool loading;

  const _CategoryGrid({
    required this.categories,
    required this.onSelected,
    this.onShowAll,
    this.sheet = false,
  }) : loading = false;

  const _CategoryGrid.skeleton()
      : categories = const [],
        onSelected = null,
        onShowAll = null,
        sheet = false,
        loading = true;

  static const double _crossSpacing = 8;
  static const double _mainSpacing = 12;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 650
            ? 6
            : (width / scaler.scale(1) >= 330 ? 4 : 3);
        final columnWidth = (width - (columns - 1) * _crossSpacing) / columns;
        final box = (columnWidth - 8).clamp(40.0, 64.0);
        final extent = box + 6 + scaler.scale(12) * 1.2 * 2 + 2;
        final slots = columns * 2;

        final tiles = <Widget>[];
        if (loading) {
          for (var i = 0; i < slots; i++) {
            tiles.add(_CategorySkeletonTile(box: box));
          }
        } else {
          final collapse = !sheet && categories.length > slots;
          final visible =
              collapse ? categories.take(slots - 1) : categories;
          for (final category in visible) {
            tiles.add(_CategoryTile(
              category: category,
              box: box,
              onTap: () => onSelected?.call(category),
            ));
          }
          if (collapse) {
            tiles.add(_AllCategoriesTile(
              box: box,
              count: categories.length,
              onTap: onShowAll,
            ));
          }
        }

        final grid = GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: _crossSpacing,
          mainAxisSpacing: _mainSpacing,
          childAspectRatio: columnWidth / extent,
          children: tiles,
        );
        return loading
            ? MarketSkeletonPulse(
                semanticLabel: 'Kategoriler yükleniyor',
                child: grid,
              )
            : grid;
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final double box;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.box,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = categoryDisplayName(category.name);
    return _TileFrame(
      box: box,
      background: categoryTint(category.name),
      label: name,
      semanticLabel: name,
      onTap: onTap,
      child: Text(
        categoryEmoji(category.name),
        style: MarketText.emoji(box * .46),
      ),
    );
  }
}

class _AllCategoriesTile extends StatelessWidget {
  final double box;
  final int count;
  final VoidCallback? onTap;

  const _AllCategoriesTile({
    required this.box,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      box: box,
      background: MarketPalette.greenSoft,
      label: 'Tümü',
      labelColor: MarketPalette.greenDark,
      labelWeight: FontWeight.w700,
      semanticLabel: 'Tüm kategoriler, $count kategori',
      onTap: onTap,
      child: const Icon(
        Icons.grid_view_rounded,
        size: 26,
        color: MarketPalette.greenDark,
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  final double box;
  final Color background;
  final String label;
  final Color labelColor;
  final FontWeight labelWeight;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  const _TileFrame({
    required this.box,
    required this.background,
    required this.label,
    this.labelColor = MarketPalette.ink,
    this.labelWeight = FontWeight.w600,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: Column(
            children: [
              Ink(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(MarketRadius.lg),
                ),
                child: Center(child: child),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: MarketText.label(
                  color: labelColor,
                  size: 12,
                  weight: labelWeight,
                ).copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySkeletonTile extends StatelessWidget {
  final double box;

  const _CategorySkeletonTile({required this.box});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MarketSkeleton(width: box, height: box, radius: MarketRadius.lg),
        const SizedBox(height: 8),
        MarketSkeleton(width: box * .8, height: 10, radius: MarketRadius.xs),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bölüm başlığı ve satır içi hata kartı
// ---------------------------------------------------------------------------

/// Ana sayfa bölüm başlığı: 18 pt başlık, isteğe bağlı tek satır alt başlık
/// ve "Tümü ›" eylemi (44 pt dokunma alanı). Üst etiket (eyebrow) yoktur;
/// bölümler arasındaki hiyerarşi sade ve aynı kalır.
class MarketSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  final Widget? trailing;

  const MarketSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.heading(size: 18),
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(actionLabel!, semanticsLabel: '$actionLabel: $title'),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              textStyle: MarketText.label(size: 13),
              minimumSize: const Size(MarketSize.control, MarketSize.control),
              padding: const EdgeInsets.only(left: 10, right: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

/// Bir bölüm yüklenemediğinde yerinde gösterilen kart ("Tekrar dene").
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
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          MarketIconTile(
            icon: icon,
            size: 40,
            background: MarketPalette.surfaceMuted,
            foreground: MarketPalette.muted,
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: Text(
              text,
              style: MarketText.body(color: MarketPalette.inkSoft, size: 13),
            ),
          ),
          TextButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tekrar dene'),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size(MarketSize.control, MarketSize.control),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kısayollar
// ---------------------------------------------------------------------------

/// Siparişlerim, favori sepetler, fotokopi ve davet kısayollarını tek bir
/// panelde toplar. Misafire üstte giriş satırı gösterilir.
class HomeShortcutsPanel extends StatelessWidget {
  const HomeShortcutsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = homeGutter(context);
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
      child: MarketCard(
        padding: EdgeInsets.zero,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!loggedIn) ...[
              const _GuestLoginRow(),
              const Divider(height: 1, thickness: 1, color: MarketPalette.line),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 1) / 2;
                final horizontal = cellWidth >= 160 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.15;
                Widget cell(_Shortcut s) =>
                    Expanded(child: _ShortcutCell(shortcut: s, horizontal: horizontal));
                const divider = VerticalDivider(
                    width: 1, thickness: 1, color: MarketPalette.line);
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [cell(_shortcuts[0]), divider, cell(_shortcuts[1])],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: MarketPalette.line),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [cell(_shortcuts[2]), divider, cell(_shortcuts[3])],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _shortcuts = [
    _Shortcut(
      title: 'Siparişlerim',
      subtitle: 'Takip et',
      icon: Icons.receipt_long_rounded,
      background: MarketPalette.greenSoft,
      foreground: MarketPalette.greenDark,
      route: '/orders',
    ),
    _Shortcut(
      // Tam adlar ("Favori sepetlerim", "Arkadaşını getir") hücrede iki
      // satıra bölünüyor; kısa ad + açıklama satırı yeterince net.
      title: 'Favori sepetler',
      subtitle: 'Hazır listelerin',
      icon: Icons.bookmarks_outlined,
      background: MarketPalette.limeSoft,
      foreground: MarketPalette.greenDark,
      route: '/saved-carts',
    ),
    _Shortcut(
      title: 'Fotokopi',
      subtitle: 'Belgeni yükle',
      icon: Icons.print_rounded,
      background: MarketPalette.blueSoft,
      foreground: MarketPalette.blue,
      route: '/photocopy-upload',
    ),
    _Shortcut(
      title: 'Davet et',
      subtitle: 'Birlikte kazanın',
      icon: Icons.card_giftcard_rounded,
      background: MarketPalette.orangeSoft,
      foreground: MarketPalette.orangeInk,
      route: '/referral',
    ),
  ];
}

class _Shortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String route;

  const _Shortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.route,
  });
}

class _ShortcutCell extends StatelessWidget {
  final _Shortcut shortcut;
  final bool horizontal;

  const _ShortcutCell({required this.shortcut, required this.horizontal});

  @override
  Widget build(BuildContext context) {
    final icon = MarketIconTile(
      icon: shortcut.icon,
      size: 36,
      background: shortcut.background,
      foreground: shortcut.foreground,
    );
    return Semantics(
      button: true,
      label: '${shortcut.title}, ${shortcut.subtitle}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(shortcut.route),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.all(MarketSpace.md),
            child: horizontal
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shortcut.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MarketText.label(size: 13),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              shortcut.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MarketText.caption(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(height: 6),
                      Text(
                        shortcut.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: MarketText.label(size: 12),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GuestLoginRow extends StatelessWidget {
  const _GuestLoginRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          const MarketIconTile(
            icon: Icons.login_rounded,
            size: 40,
            background: MarketPalette.limeSoft,
            foreground: MarketPalette.greenDark,
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eylemi yanındaki "Giriş yap" düğmesi söyler; başlık kısa kalır
                Text(
                  'Avantajları kaçırma',
                  style: MarketText.label(size: 14, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Siparişlerini takip et, görevlere katıl.',
                  style: MarketText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: MarketSpace.sm),
          FilledButton.tonal(
            onPressed: () => context.push('/login'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, MarketSize.control),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: MarketPalette.greenSoft,
              foregroundColor: MarketPalette.greenDark,
              textStyle: MarketText.label(size: 13),
            ),
            child: const Text('Giriş yap'),
          ),
        ],
      ),
    );
  }
}
