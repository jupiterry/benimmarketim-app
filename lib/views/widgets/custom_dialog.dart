import 'package:flutter/material.dart';

import 'market_ui.dart';

/// Ortalı onay / bilgi penceresi: büyük simge, başlık, açıklama ve alt alta
/// iki buton (ana eylem üstte). Uzun metinlerde içerik kayar.
class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmButtonText;
  final String cancelButtonText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final IconData icon;

  final bool showCancelButton;

  /// Renk tonu; verilmezse [isDestructive]'e göre tehlike ya da marka.
  final MarketTone? tone;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmButtonText,
    required this.cancelButtonText,
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.showCancelButton = true,
    this.icon = Icons.info_outline_rounded,
    this.tone,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmButtonText,
    String cancelButtonText = 'Vazgeç',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    bool showCancelButton = true,
    IconData icon = Icons.info_outline_rounded,
    MarketTone? tone,
  }) {
    return showMarketDialog<void>(
      context,
      builder: (_) => CustomDialog(
        title: title,
        message: message,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
        showCancelButton: showCancelButton,
        icon: icon,
        tone: tone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? (isDestructive ? MarketTone.danger : MarketTone.brand);
    final (tileBackground, tileForeground) = switch (effectiveTone) {
      MarketTone.brand => (MarketPalette.greenSoft, MarketPalette.greenDark),
      MarketTone.danger => (MarketPalette.redSoft, MarketPalette.red),
      MarketTone.favorite => (MarketPalette.pinkSoft, MarketPalette.pink),
    };
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.lg),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarketIconTile(
                  icon: icon,
                  size: 56,
                  background: tileBackground,
                  foreground: tileForeground,
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: MarketText.title(size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: MarketText.body(color: MarketPalette.muted, size: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                // Butonlar alt alta: uzun metinler kırılmaz, ana eylem üstte.
                FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(MarketSize.button),
                    backgroundColor: effectiveTone == MarketTone.danger
                        ? MarketPalette.red
                        : MarketPalette.green,
                  ),
                  child: Text(confirmButtonText, textAlign: TextAlign.center),
                ),
                if (showCancelButton) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: MarketPalette.inkSoft,
                      minimumSize: const Size.fromHeight(MarketSize.tapTarget),
                    ),
                    child: Text(cancelButtonText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uygulamanın diyalog açıcısı: ortak karartma, ekran okuyucuya "kapat"
/// etiketi, yumuşak belirme (0.94 → 1 ölçek, 220 ms; "hareketi azalt" açıksa
/// animasyonsuz). [CustomDialog.show] ve [showMarketConfirm] bunu kullanır.
Future<T?> showMarketDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: MarketPalette.scrim,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: curved.drive(Tween<double>(begin: .94, end: 1)),
          child: child,
        ),
      );
    },
  );
}

/// Evet/hayır onayı: ana eyleme basılırsa true, "Vazgeç"e ya da dışarı
/// dokunulursa false döner.
///
/// ```dart
/// if (await showMarketConfirm(context, icon: Icons.delete_outline_rounded,
///     title: 'Sepet boşaltılsın mı?', message: '...', confirmLabel: 'Boşalt',
///     tone: MarketTone.danger)) { ... }
/// ```
Future<bool> showMarketConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Vazgeç',
  MarketTone tone = MarketTone.brand,
}) async {
  final result = await showMarketDialog<bool>(
    context,
    builder: (dialogContext) => CustomDialog(
      title: title,
      message: message,
      confirmButtonText: confirmLabel,
      cancelButtonText: cancelLabel,
      icon: icon,
      tone: tone,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onCancel: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  return result ?? false;
}
