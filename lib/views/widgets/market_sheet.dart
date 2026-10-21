import 'package:flutter/material.dart';

import 'market_ui.dart';

// ---------------------------------------------------------------------------
// Alt sayfa (bottom sheet) yapı taşları. market_ui.dart üzerinden de gelir.
//
// Kural: içinde büyük simge olan "an" sayfaları (teşekkür, kupon hatırlatma,
// puan isteme) ortalı [MarketPromptSheet]; form sayfaları (Ne oldu?, NPS,
// filtreler) sola hizalı [MarketSheetHeader] + [MarketSheetScaffold].
// ---------------------------------------------------------------------------

/// Uygulamanın alt sayfa açıcısı: beyaz zemin, üstte 30'luk köşe, ekranın en
/// fazla %[maxHeightFactor]'i, içerik kadar yükseklik (isScrollControlled) ve
/// ortak karartma. İçerik genellikle [MarketSheetScaffold] ya da
/// [MarketPromptSheet] olur.
Future<T?> showMarketSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  double maxHeightFactor = .92,
  Color backgroundColor = MarketPalette.surface,
  RouteSettings? routeSettings,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor,
    barrierColor: MarketPalette.scrim,
    showDragHandle: false,
    routeSettings: routeSettings,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
    ),
  );
}

/// Alt sayfanın üstündeki tutamak (44 × 5).
class MarketSheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const MarketSheetHandle({
    super.key,
    this.margin = const EdgeInsets.only(top: 10, bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          margin: margin,
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: MarketPalette.lineStrong,
            borderRadius: BorderRadius.circular(MarketRadius.pill),
          ),
        ),
      ),
    );
  }
}

/// Sola hizalı alt sayfa başlığı: isteğe bağlı geri düğmesi, üstte küçük bir
/// hap ([meta], ör. "Sipariş #6AD8"), başlık, açıklama ve 48 pt'lik "Kapat".
class MarketSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? meta;

  /// Verilirse solda "Geri" düğmesi çıkar (sayfa içinde bir önceki adım).
  final VoidCallback? onBack;

  /// Verilmezse sayfayı kapatır (Navigator.maybePop).
  final VoidCallback? onClose;
  final bool showClose;
  final EdgeInsetsGeometry padding;

  const MarketSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.onBack,
    this.onClose,
    this.showClose = true,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    final hasButtons = onBack != null || showClose;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            Transform.translate(
              offset: const Offset(-10, 0),
              child: MarketSheetIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Geri',
                onTap: onBack!,
              ),
            ),
          ],
          Expanded(
            child: Padding(
              // Tek satırlık başlık 48 pt'lik düğmelerle ortalanır.
              padding: EdgeInsets.only(top: hasButtons ? 10 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meta != null) ...[meta!, const SizedBox(height: 8)],
                  Semantics(
                    header: true,
                    child: Text(title, style: MarketText.title(size: 20)),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: MarketText.body(color: MarketPalette.muted, size: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 8),
            MarketSheetIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Kapat',
              onTap: onClose ?? () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Alt sayfa başlığındaki yuvarlak düğme: 36 pt gri daire, 48 pt dokunma alanı.
class MarketSheetIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const MarketSheetIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: MarketSize.tapTarget,
          height: MarketSize.tapTarget,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: MarketPalette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: MarketPalette.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alt sayfa iskeleti: tutamak, sabit başlık, kaydırılabilir gövde ve klavyenin
/// / ana ekran çubuğunun üstünde sabit duran alt kısım ([footer]).
///
/// İçerik kısaysa sayfa içerik kadar yükselir; uzunsa gövde kayar ve [footer]
/// ("Gönder") hep görünür kalır. [busy] true iken geri tuşu ve dışarı dokunma
/// sayfayı kapatmaz (sürükleyerek kapatmayı da engellemek için
/// showMarketSheet'e `enableDrag: false` verilir).
class MarketSheetScaffold extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? footer;
  final bool showHandle;
  final bool scrollable;
  final EdgeInsets bodyPadding;
  final EdgeInsets footerPadding;
  final bool busy;
  final ScrollController? scrollController;

  const MarketSheetScaffold({
    super.key,
    this.header,
    required this.body,
    this.footer,
    this.showHandle = true,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.footerPadding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
    this.busy = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Klavye açıkken alt güvenli alan zaten 0'dır.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final padding = footer == null
        ? bodyPadding.copyWith(bottom: bodyPadding.bottom + safeBottom)
        : bodyPadding;

    final content = scrollable
        ? SingleChildScrollView(
            controller: scrollController,
            padding: padding,
            child: body,
          )
        : Padding(padding: padding, child: body);

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) const MarketSheetHandle(),
            if (header != null) header!,
            Flexible(child: content),
            if (footer != null)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: MarketPalette.surface,
                  border: Border(top: BorderSide(color: MarketPalette.line)),
                ),
                child: Padding(
                  padding: footerPadding.copyWith(bottom: footerPadding.bottom + safeBottom),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ortalı "an" sayfası: büyük simge (ya da [illustration]), başlık, açıklama,
/// isteğe bağlı ek içerik, 54 pt ana buton ve altında yazı görünümlü ikinci
/// eylem ("Şimdi değil"). [showMarketSheet] ile açılır.
class MarketPromptSheet extends StatelessWidget {
  final IconData? icon;
  final Widget? illustration;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String? message;
  final Widget? child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;

  /// true iken ana buton dönen gösterge gösterir, sayfa kapatılamaz.
  final bool primaryLoading;
  final String? secondaryLabel;

  /// Verilmezse ikinci eylem sayfayı kapatır.
  final VoidCallback? onSecondary;
  final bool showClose;

  const MarketPromptSheet({
    super.key,
    this.icon,
    this.illustration,
    this.iconBackground = MarketPalette.lime,
    this.iconForeground = MarketPalette.greenDeep,
    required this.title,
    this.message,
    this.child,
    required this.primaryLabel,
    this.onPrimary,
    this.primaryIcon,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.showClose = false,
  });

  @override
  Widget build(BuildContext context) {
    final art = illustration ??
        (icon == null
            ? null
            : MarketIconTile(
                icon: icon!,
                size: 64,
                background: iconBackground,
                foreground: iconForeground,
              ));
    return MarketSheetScaffold(
      busy: primaryLoading,
      header: showClose
          ? Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: MarketSheetIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Kapat',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      bodyPadding: EdgeInsets.fromLTRB(24, showClose ? 0 : 8, 24, 16),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (art != null) ...[Center(child: art), const SizedBox(height: 16)],
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: MarketText.title(size: 22)),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: MarketText.body(color: MarketPalette.muted, size: 14),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 16), child!],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: primaryLoading ? null : onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(MarketSize.button),
              disabledBackgroundColor: primaryLoading ? MarketPalette.green : null,
              disabledForegroundColor: primaryLoading ? Colors.white : null,
            ),
            child: primaryLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (primaryIcon != null) ...[
                        Icon(primaryIcon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(primaryLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: primaryLoading
                  ? null
                  : (onSecondary ?? () => Navigator.of(context).maybePop()),
              style: TextButton.styleFrom(
                foregroundColor: MarketPalette.inkSoft,
                minimumSize: const Size.fromHeight(MarketSize.tapTarget),
              ),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
