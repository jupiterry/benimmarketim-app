import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'market_ui.dart';

// ---------------------------------------------------------------------------
// Reyon ve arama sayfalarının ortak filtre / sıralama parçaları
// ---------------------------------------------------------------------------

/// Yatay kayan çip satırı (filtre, sıralama). Sığmayan taraf kenarda yumuşakça
/// kaybolur; böylece çiplerin devamı olduğu belli olur ve çipler sert bir
/// kesikle bitmez. Yükseklik çipin dokunma alanı kadardır (48).
class BrowseChipRow extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const BrowseChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: MarketSpace.xl),
    this.spacing = MarketSpace.sm,
  });

  @override
  State<BrowseChipRow> createState() => _BrowseChipRowState();
}

class _BrowseChipRowState extends State<BrowseChipRow> {
  bool _fadeStart = false;
  bool _fadeEnd = false;

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final start = metrics.extentBefore > 1;
    final end = metrics.extentAfter > 1;
    if (start == _fadeStart && end == _fadeEnd) return false;
    void apply() {
      if (!mounted) return;
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }

    // Bildirim yerleşim sırasında gelirse durum kare bitince güncellenir.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => apply())
        ..ensureVisualUpdate();
    } else {
      apply();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.children.length,
      separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
      itemBuilder: (context, index) => Center(child: widget.children[index]),
    );

    return SizedBox(
      height: MarketSize.tapTarget,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) => _onMetrics(notification.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) => _onMetrics(notification.metrics),
          // Maske hep ağaçta kalır (yoksa liste kaydırma konumunu kaybeder);
          // kenar taşmıyorsa tamamen opaktır.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final fade = bounds.width > 0 ? 40 / bounds.width : 0.0;
              return LinearGradient(
                colors: [
                  _fadeStart ? Colors.transparent : Colors.black,
                  Colors.black,
                  Colors.black,
                  _fadeEnd ? Colors.transparent : Colors.black,
                ],
                stops: [0, fade, 1 - fade, 1],
              ).createShader(bounds);
            },
            child: list,
          ),
        ),
      ),
    );
  }
}

/// Çip satırının sonundaki "Temizle": tüm filtreleri ve sıralamayı sıfırlar.
class BrowseClearButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const BrowseClearButton({
    super.key,
    required this.onPressed,
    this.label = 'Temizle',
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 16),
      label: Text(label, semanticsLabel: 'Filtreleri temizle'),
      style: TextButton.styleFrom(
        foregroundColor: MarketPalette.greenDark,
        textStyle: MarketText.label(size: 13),
        minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Sıralama seçimi: başlıklı alt sayfada 56 pt'lik satırlar, seçili olanın
/// yanında ✓. Seçilen değeri döndürür (kapatılırsa null).
Future<T?> showBrowseSortSheet<T>(
  BuildContext context, {
  required Map<T, String> options,
  required T selected,
  String title = 'Sırala',
}) {
  return showMarketSheet<T>(
    context,
    builder: (sheetContext) => MarketSheetScaffold(
      header: MarketSheetHeader(title: title),
      bodyPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in options.entries)
            _SortOption(
              label: entry.value,
              selected: entry.key == selected,
              onTap: () => Navigator.of(sheetContext).pop(entry.key),
            ),
        ],
      ),
    ),
  );
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? MarketPalette.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: MarketText.label(
                        color: selected
                            ? MarketPalette.greenDeep
                            : MarketPalette.ink,
                        size: 15,
                        weight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.check_rounded,
                      color: MarketPalette.green,
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
