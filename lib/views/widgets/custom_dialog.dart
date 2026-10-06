import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'market_ui.dart';

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
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
            child: CustomDialog(
              title: title,
              message: message,
              confirmButtonText: confirmButtonText,
              cancelButtonText: cancelButtonText,
              onConfirm: onConfirm,
              onCancel: onCancel,
              isDestructive: isDestructive,
              showCancelButton: showCancelButton,
              icon: icon,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.lg),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarketIconTile(
              icon: icon,
              size: 60,
              background: isDestructive ? MarketPalette.redSoft : MarketPalette.greenSoft,
              foreground: isDestructive ? MarketPalette.red : MarketPalette.greenDark,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MarketText.title(size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MarketText.body(color: MarketPalette.muted, size: 14, height: 1.5),
            ),
            const SizedBox(height: 26),
            // Butonlar alt alta: uzun metinler kırılmaz, ana eylem üstte.
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor:
                    isDestructive ? MarketPalette.red : MarketPalette.green,
              ),
              child: Text(confirmButtonText),
            ),
            if (showCancelButton) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (onCancel != null) {
                    onCancel!();
                  } else {
                    context.pop();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: MarketPalette.inkSoft,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(cancelButtonText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
