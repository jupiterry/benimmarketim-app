import 'package:flutter/material.dart';

import '../../services/meta_app_events_service.dart';
import 'legal_links.dart';
import 'market_ui.dart';

bool _askedThisSession = false;
bool _answeredThisSession = false;

/// Bu açılışta reklam ölçümü sayfası gösterildi ve kullanıcı karar verdi mi.
/// Sipariş sonrası anket aynı açılışta ikinci bir pencere açmamak için buna
/// bakar. Karar verildiyse sayfa bir daha gelmez, anket sonraki açılışta
/// sorulur. Sayfa karar verilmeden kapatıldıysa (Android: ✕, geri, dışarı
/// dokunma) false kalır: sayfa her açılışta yeniden geleceği için anketi
/// engellemek onu kapatan kullanıcıya hiç anket gösterilmemesi demek olurdu.
bool get metaConsentPromptedThisSession => _answeredThisSession;

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
  final granted = await showMarketSheet<bool>(
    context,
    isDismissible: !ios,
    enableDrag: !ios,
    builder: (_) => _MetaConsentSheet(ios: ios),
  );
  if (granted == null) return;
  _answeredThisSession = true;
  await service.setConsent(granted);
}

/// Ekran görüntüsü testleri için açıklama sayfası (uygulamada kullanılmaz).
@visibleForTesting
Widget debugMetaConsentSheet({required bool ios}) => _MetaConsentSheet(ios: ios);

class _MetaConsentSheet extends StatelessWidget {
  final bool ios;

  const _MetaConsentSheet({required this.ios});

  @override
  Widget build(BuildContext context) {
    final Widget actions;
    if (ios) {
      actions = FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
        child: const Text('Devam'),
      );
    } else {
      // KVKK: iki seçenek eşit boyutta ve eşit görünürlükte
      actions = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
              child: const Text('İzin verme'),
            ),
          ),
          const SizedBox(width: MarketSpace.md),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
              child: const Text('İzin ver'),
            ),
          ),
        ],
      );
    }

    return MarketSheetScaffold(
      // iOS'ta sayfa kaydırılarak kapatılamaz; tutamak yanıltıcı olur
      showHandle: !ios,
      header: Padding(
        padding: EdgeInsets.only(top: ios ? 20 : 0),
        child: MarketSheetHeader(
          title: ios ? 'Reklam ölçümü hakkında' : 'Reklam ölçümüne izin veriyor musun?',
          meta: const MarketPill(icon: Icons.insights_rounded, label: 'Gizlilik tercihi'),
          // Kapatmak "karar verilmedi" demektir (kaydırarak kapatmakla aynı)
          showClose: !ios,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reklamlarımızın işe yarayıp yaramadığını görmek için bazı kullanım '
            'bilgilerini Meta (Facebook) ile paylaşmak istiyoruz.',
            style: MarketText.body(color: MarketPalette.inkSoft),
          ),
          const SizedBox(height: MarketSpace.lg),
          const _ConsentPoint(
            icon: Icons.ios_share_rounded,
            title: 'Paylaşılanlar',
            text: 'Uygulamanın açılması, sepete ürün eklenmesi ve verilen siparişler '
                'gibi kullanım bilgileri, cihazının reklam kimliğiyle birlikte.',
          ),
          const _ConsentPoint(
            icon: Icons.lock_outline_rounded,
            title: 'Paylaşılmayanlar',
            text: 'Adın, telefon numaran ve teslimat bilgilerin.',
          ),
          _ConsentPoint(
            icon: Icons.tune_rounded,
            title: 'Karar senin',
            text: '${ios ? 'Birazdan iPhone sana izin soracak. ' : ''}'
                'İzin vermesen de uygulamayı aynı şekilde kullanırsın. Kararını '
                'Ayarlar > Gizlilik bölümünden istediğin zaman değiştirebilirsin.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => LegalLinks.open(context, LegalLinks.privacy),
              style: TextButton.styleFrom(
                foregroundColor: MarketPalette.greenDark,
                minimumSize: const Size(0, MarketSize.control),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Gizlilik Politikası'),
            ),
          ),
        ],
      ),
      footer: actions,
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ConsentPoint({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MarketSpace.md),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MarketPalette.greenSoft,
                borderRadius: BorderRadius.circular(MarketRadius.xs),
              ),
              child: Icon(icon, size: 17, color: MarketPalette.greenDark),
            ),
            const SizedBox(width: MarketSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MarketText.label(size: 13)),
                  const SizedBox(height: 2),
                  Text(text, style: MarketText.body(color: MarketPalette.muted, size: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
