import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../viewmodels/settings_viewmodel.dart';
import 'market_ui.dart';

/// Havale / EFT hesap bilgileri. Bilgiler yönetim panelinde
/// Ayarlar → Ödeme bölümünden girilir; IBAN girilmemişse müşteriye
/// hesap bilgisinin ayrıca iletileceği söylenir.
class BankTransferCard extends StatelessWidget {
  const BankTransferCard({
    super.key,
    required this.settings,
    this.orderNumber,
  });

  final SettingsViewModel settings;

  /// Sipariş verildiyse açıklamaya yazılacak kısa sipariş numarası
  final String? orderNumber;

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    showMarketSnack(context, message, icon: Icons.copy_rounded);
  }

  @override
  Widget build(BuildContext context) {
    if (!settings.hasBankTransferInfo) {
      return const MarketNotice(
        icon: Icons.info_outline_rounded,
        text:
            'Hesap bilgileri sipariş sonrasında sana mesajla iletilecek. Ödemeyi bu bilgilerle yapabilirsin.',
      );
    }

    final reference = (orderNumber ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  size: 18, color: MarketPalette.greenDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Havale / EFT bilgileri',
                    style: MarketText.label(size: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (settings.bankAccountName.isNotEmpty)
            _InfoRow(label: 'Alıcı', value: settings.bankAccountName),
          if (settings.bankName.isNotEmpty)
            _InfoRow(label: 'Banka', value: settings.bankName),
          const SizedBox(height: 4),
          Material(
            color: MarketPalette.greenSoft,
            borderRadius: BorderRadius.circular(MarketRadius.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(MarketRadius.sm),
              onTap: () => _copy(context, settings.bankIban, 'IBAN kopyalandı'),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IBAN', style: MarketText.caption()),
                          const SizedBox(height: 2),
                          SelectableText(
                            settings.bankIbanFormatted,
                            style: MarketText.label(
                              size: 14,
                              color: MarketPalette.greenDeep,
                            ).copyWith(letterSpacing: .3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded,
                        size: 18, color: MarketPalette.greenDark),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (reference.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(MarketRadius.xs),
              onTap: () =>
                  _copy(context, reference, 'Sipariş numarası kopyalandı'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(
                    style: MarketText.caption(color: MarketPalette.orangeInk),
                    children: [
                      const TextSpan(text: 'Açıklamaya sipariş numaranı yaz: '),
                      TextSpan(
                        text: reference,
                        style: MarketText.caption(
                          color: MarketPalette.orangeInk,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Text(
              'Ödemeyi sipariş sonrasında yap; açıklamaya sipariş numaranı yaz.',
              style: MarketText.caption(color: MarketPalette.orangeInk),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: MarketText.caption()),
          ),
          Expanded(
            child: Text(value,
                style: MarketText.label(size: 13, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
