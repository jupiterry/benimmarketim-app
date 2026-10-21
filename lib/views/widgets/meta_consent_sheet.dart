import 'package:flutter/material.dart';

import '../../services/meta_app_events_service.dart';
import 'legal_links.dart';
import 'market_ui.dart';

bool _askedThisSession = false;

/// Reklam ölçümü (Meta) kararı henüz verilmediyse bir kez sorar. Karar
/// verilmeden kapatılırsa ölçüm kapalı kalır ve bir sonraki açılışta yeniden
/// sorulur. Karar verilmişse hiçbir şey göstermeden hemen döner.
///
/// iOS'ta karar sistemin izleme penceresinde (ATT) verilir. Apple kuralı
/// gereği önceki açıklama ekranında reddetme düğmesi olmaz; tek düğme
/// ("Devam") her zaman sistem penceresine götürür ve pencere kaydırılarak
/// kapatılamaz.
Future<void> maybeAskMetaConsent(BuildContext context) async {
  final service = MetaAppEventsService.instance;
  if (!service.isSupported || _askedThisSession) return;
  await service.init();
  if (service.consent != MetaTrackingConsent.unknown) return;
  _askedThisSession = true;

  // Ana sayfa yerleşsin diye kısa bir bekleme
  await Future<void>.delayed(const Duration(milliseconds: 900));
  if (!context.mounted) return;

  final ios = service.isIos;
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: !ios,
    enableDrag: !ios,
    backgroundColor: MarketPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
    ),
    builder: (_) => _MetaConsentSheet(ios: ios),
  );
  if (granted == null) return;
  await service.setConsent(granted);
}

class _MetaConsentSheet extends StatelessWidget {
  final bool ios;

  const _MetaConsentSheet({required this.ios});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MarketSpace.xl,
          MarketSpace.md,
          MarketSpace.xl,
          MarketSpace.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: MarketSpace.lg),
                  decoration: BoxDecoration(
                    color: MarketPalette.lineStrong,
                    borderRadius: BorderRadius.circular(MarketRadius.pill),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: MarketIconTile(
                  icon: Icons.insights_rounded,
                  size: 48,
                  background: MarketPalette.greenSoft,
                  foreground: MarketPalette.greenDark,
                ),
              ),
              const SizedBox(height: MarketSpace.md),
              Text(
                ios
                    ? 'Reklam ölçümü hakkında'
                    : 'Reklam ölçümüne izin veriyor musun?',
                style: MarketText.title(),
              ),
              const SizedBox(height: MarketSpace.sm),
              Text(
                'Reklamlarımızın işe yarayıp yaramadığını görmek için uygulamanın '
                'açılması, sepete ürün eklenmesi ve verilen siparişler gibi '
                'kullanım bilgilerini cihazının reklam kimliğiyle birlikte '
                'Meta (Facebook) ile paylaşmak istiyoruz.',
                style: MarketText.body(color: MarketPalette.inkSoft),
              ),
              const SizedBox(height: MarketSpace.sm),
              Text(
                'Adın, telefon numaran ve teslimat bilgilerin paylaşılmaz. '
                '${ios ? 'Birazdan iPhone sana izin soracak. ' : ''}'
                'İzin vermesen de uygulamayı aynı şekilde kullanırsın. Kararını '
                'Ayarlar > Gizlilik bölümünden istediğin zaman değiştirebilirsin.',
                style: MarketText.body(color: MarketPalette.muted, size: 13),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => LegalLinks.open(context, LegalLinks.privacy),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: MarketPalette.greenDark,
                  ),
                  child: const Text('Gizlilik Politikası'),
                ),
              ),
              const SizedBox(height: MarketSpace.md),
              if (ios)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Devam'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('İzin verme'),
                      ),
                    ),
                    const SizedBox(width: MarketSpace.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('İzin ver'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
