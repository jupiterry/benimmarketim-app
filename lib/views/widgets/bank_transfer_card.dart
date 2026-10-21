import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../viewmodels/settings_viewmodel.dart';
import 'market_ui.dart';

/// Havale / EFT hesap bilgileri. Bilgiler yönetim panelinde
/// Ayarlar → Ödeme bölümünden girilir; IBAN girilmemişse müşteriye
/// hesap bilgisinin ayrıca iletileceği söylenir.
///
/// Her satırın kendi "Kopyala" düğmesi vardır (satırın kendisine dokunmak da
/// kopyalar); bankacılık uygulamasına tek tek yapıştırılabilir.
class BankTransferCard extends StatelessWidget {
  const BankTransferCard({
    super.key,
    required this.settings,
    this.orderNumber,
    this.amount,
  });

  final SettingsViewModel settings;

  /// Sipariş verildiyse açıklamaya yazılacak kısa sipariş numarası
  /// ("#" ile ya da onsuz; kopyalanırken "#" atılır, bazı bankalar kabul etmez)
  final String? orderNumber;

  /// Gönderilecek tutar (verilirse "Tutar" satırı çıkar)
  final double? amount;

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    showMarketSnack(context, message, icon: Icons.copy_rounded);
  }

  /// Bankacılık uygulamalarının tutar alanına yapıştırılabilir biçim: "338,60"
  static String _plainAmount(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    if (!settings.hasBankTransferInfo) {
      return const MarketNotice(
        icon: Icons.info_outline_rounded,
        text:
            'Hesap bilgileri sipariş sonrasında sana mesajla iletilecek. Ödemeyi bu bilgilerle yapabilirsin.',
      );
    }

    final reference = (orderNumber ?? '').trim().replaceAll('#', '');
    final total = amount;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.greenLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dar kartta düğmeler yalnızca simge olarak kalır (değere yer açılır).
          final iconOnly = constraints.maxWidth < 300;
          final rows = <Widget>[
            if (settings.bankAccountName.isNotEmpty)
              _CopyRow(
                label: 'Alıcı',
                value: settings.bankAccountName,
                iconOnly: iconOnly,
                semanticsLabel: 'Alıcı adını kopyala',
                onCopy: () => _copy(
                    context, settings.bankAccountName, 'Alıcı adı kopyalandı'),
              ),
            if (settings.bankName.isNotEmpty)
              _CopyRow(label: 'Banka', value: settings.bankName),
            _CopyRow(
              label: 'IBAN',
              value: settings.bankIbanFormatted,
              emphasized: true,
              iconOnly: iconOnly,
              semanticsLabel: "IBAN'ı kopyala",
              onCopy: () =>
                  _copy(context, settings.bankIban, 'IBAN kopyalandı'),
            ),
            if (total != null && total > 0)
              _CopyRow(
                label: 'Tutar',
                value: formatTl(total),
                emphasized: true,
                iconOnly: iconOnly,
                semanticsLabel: 'Tutarı kopyala',
                onCopy: () =>
                    _copy(context, _plainAmount(total), 'Tutar kopyalandı'),
              ),
            if (reference.isNotEmpty)
              _CopyRow(
                label: 'Açıklama',
                value: reference,
                emphasized: true,
                iconOnly: iconOnly,
                semanticsLabel: 'Sipariş numarasını kopyala',
                onCopy: () =>
                    _copy(context, reference, 'Sipariş numarası kopyalandı'),
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded,
                        size: 18, color: MarketPalette.greenDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Havale / EFT bilgileri',
                            style: MarketText.label(size: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, endIndent: 4, color: MarketPalette.line),
                rows[i],
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: MarketNotice.warning(
                  icon: Icons.info_outline_rounded,
                  text: reference.isNotEmpty
                      ? 'Havale açıklamasına sipariş numaranı yazmayı unutma.'
                      : 'Ödemeyi sipariş sonrasında yap; açıklamaya sipariş numaranı yaz.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Etiket + değer satırı; [onCopy] verilirse sağda "Kopyala" düğmesi çıkar ve
/// satırın kendisine dokunmak da kopyalar.
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    this.onCopy,
    this.semanticsLabel,
    this.emphasized = false,
    this.iconOnly = false,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final String? semanticsLabel;
  final bool emphasized;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MarketText.caption(size: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: MarketText.label(
                    size: 14,
                    color: emphasized
                        ? MarketPalette.greenDeep
                        : MarketPalette.ink,
                    weight: emphasized ? FontWeight.w800 : FontWeight.w600,
                  ).copyWith(letterSpacing: emphasized ? .3 : null),
                ),
              ],
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            _CopyButton(
              onTap: onCopy!,
              iconOnly: iconOnly,
              semanticsLabel: semanticsLabel ?? '$label kopyala',
            ),
          ] else
            // Düğmesiz satırların metni de aynı hizada biter.
            const SizedBox(width: 4),
        ],
      ),
    );
    if (onCopy == null) return content;
    return InkWell(
      onTap: onCopy,
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(MarketRadius.sm),
      child: content,
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.onTap,
    required this.iconOnly,
    required this.semanticsLabel,
  });

  final VoidCallback onTap;
  final bool iconOnly;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      backgroundColor: MarketPalette.greenSoft,
      foregroundColor: MarketPalette.greenDark,
      minimumSize: const Size(MarketSize.control, 36),
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 12),
      shape: const StadiumBorder(),
      textStyle: MarketText.label(size: 13),
    );
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: semanticsLabel,
        child: iconOnly
            ? TextButton(
                onPressed: onTap,
                style: style,
                child: const Icon(Icons.copy_rounded, size: 18),
              )
            : TextButton.icon(
                onPressed: onTap,
                style: style,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Kopyala'),
              ),
      ),
    );
  }
}
