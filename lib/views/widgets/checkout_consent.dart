import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/legal_documents.dart';
import 'market_ui.dart';

/// Ödeme ekranındaki zorunlu onay: "Ön Bilgilendirme Formu'nu ve Mesafeli
/// Satış Sözleşmesi'ni okudum, onaylıyorum." Metin adlarına dokununca o
/// anki siparişe göre hazırlanan metin açılır.
class CheckoutConsent extends StatefulWidget {
  final bool accepted;
  final bool error;
  final ValueChanged<bool> onChanged;

  /// Metinler açılırken o anki sipariş bilgileri
  final LegalOrderData Function() data;

  const CheckoutConsent({
    super.key,
    required this.accepted,
    required this.error,
    required this.onChanged,
    required this.data,
  });

  @override
  State<CheckoutConsent> createState() => _CheckoutConsentState();
}

class _CheckoutConsentState extends State<CheckoutConsent> {
  late final TapGestureRecognizer _preInfoTap;
  late final TapGestureRecognizer _contractTap;

  @override
  void initState() {
    super.initState();
    _preInfoTap = TapGestureRecognizer()
      ..onTap = () => showLegalDocument(
            context,
            buildPreInformationForm(widget.data(), formatTl),
          );
    _contractTap = TapGestureRecognizer()
      ..onTap = () => showLegalDocument(
            context,
            buildDistanceSalesContract(widget.data(), formatTl),
          );
  }

  @override
  void dispose() {
    _preInfoTap.dispose();
    _contractTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = MarketText.label(size: 13, color: MarketPalette.greenDark)
        .copyWith(decoration: TextDecoration.underline);
    final borderColor = widget.error
        ? MarketPalette.red
        : widget.accepted
            ? MarketPalette.green
            : MarketPalette.line;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: widget.error ? MarketPalette.redSoft : MarketPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MarketRadius.md),
            side: BorderSide(color: borderColor, width: widget.error ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onChanged(!widget.accepted),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: widget.accepted,
                    onChanged: (v) => widget.onChanged(v ?? false),
                    activeColor: MarketPalette.green,
                    side: BorderSide(
                      color: widget.error
                          ? MarketPalette.red
                          : MarketPalette.lineStrong,
                      width: 1.6,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          style: MarketText.body(
                              size: 13, color: MarketPalette.inkSoft),
                          children: [
                            TextSpan(
                              text: 'Ön Bilgilendirme Formu',
                              style: link,
                              recognizer: _preInfoTap,
                            ),
                            const TextSpan(text: '\'nu ve '),
                            TextSpan(
                              text: 'Mesafeli Satış Sözleşmesi',
                              style: link,
                              recognizer: _contractTap,
                            ),
                            const TextSpan(text: '\'ni okudum, onaylıyorum.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.error)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: MarketPalette.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Siparişi vermek için metinleri onaylaman gerekiyor.',
                    style: MarketText.caption(
                        color: MarketPalette.red, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Yasal metni tam ekran alt sayfada gösterir.
Future<void> showLegalDocument(BuildContext context, LegalDocument document) {
  return showMarketSheet<void>(
    context,
    maxHeightFactor: .94,
    builder: (sheetContext) => _LegalDocumentSheet(document: document),
  );
}

class _LegalDocumentSheet extends StatelessWidget {
  final LegalDocument document;

  const _LegalDocumentSheet({required this.document});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MarketSheetHandle(),
        MarketSheetHeader(
          title: document.title,
          subtitle: 'Bu siparişe göre hazırlandı',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              for (final section in document.sections) ...[
                Semantics(
                  header: true,
                  child:
                      Text(section.title, style: MarketText.heading(size: 15)),
                ),
                const SizedBox(height: 6),
                for (final p in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(p,
                        style: MarketText.body(
                            size: 13, color: MarketPalette.inkSoft)),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.buttonSm),
              ),
              child: const Text('Okudum'),
            ),
          ),
        ),
      ],
    );
  }
}
