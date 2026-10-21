import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/review_service.dart';
import '../../viewmodels/referral_viewmodel.dart';
import 'market_ui.dart';

// Geri bildirim ekranlarında (detaylı anket, hızlı 👍/👎, tavsiye sorusu) ortak parçalar.
// Seçenek kimlikleri sunucudaki backend/lib/feedbackOptions.js ile aynıdır.

class FeedbackOption {
  final String id;
  final String label;
  const FeedbackOption(this.id, this.label);
}

const feedbackPositiveTags = [
  FeedbackOption('hizli', 'Hızlı geldi'),
  FeedbackOption('taze', 'Ürünler tazeydi'),
  FeedbackOption('kurye', 'Kurye nazikti'),
  FeedbackOption('fiyat', 'Fiyatlar uygundu'),
  FeedbackOption('kolay', 'Uygulama kolaydı'),
];

const feedbackNegativeTags = [
  FeedbackOption('gec', 'Geç geldi'),
  FeedbackOption('eksik', 'Eksik ürün vardı'),
  FeedbackOption('yanlis', 'Yanlış ürün geldi'),
  FeedbackOption('bozuk', 'Ürün bozuk/ezikti'),
  FeedbackOption('kurye_kotu', 'Kurye ilgisizdi'),
  FeedbackOption('paket', 'Paketleme kötüydü'),
  FeedbackOption('pahali', 'Fiyatlar yüksekti'),
  FeedbackOption('uygulama', 'Uygulamada sorun yaşadım'),
];

/// Ürün bazında sorun türleri
const feedbackIssueTypes = [
  FeedbackOption('bozuk', 'Bozuk'),
  FeedbackOption('eksik', 'Eksik'),
  FeedbackOption('yanlis', 'Yanlış'),
];

/// Bu etiketlerden biri seçilince siparişteki ürünler listelenir
const feedbackProductTags = {'eksik', 'yanlis', 'bozuk'};

/// Sunucunun gönderdiği sipariş özeti (GET /feedback/prompt → order / quick)
class FeedbackOrder {
  final String orderId;
  final String shortId;
  final String deliveryPointName;
  final List<FeedbackOrderProduct> products;

  const FeedbackOrder({
    required this.orderId,
    required this.shortId,
    required this.deliveryPointName,
    required this.products,
  });

  static FeedbackOrder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['orderId'];
    if (id is! String || id.isEmpty) return null;
    final products = json['products'] is List
        ? (json['products'] as List)
            .whereType<Map>()
            .map((item) => FeedbackOrderProduct(
                  productId: item['productId'] is String ? item['productId'] as String : null,
                  name: (item['name'] ?? '').toString(),
                  image: item['image'] is String ? item['image'] as String : null,
                  quantity: (item['quantity'] as num?)?.toInt() ?? 0,
                ))
            .where((item) => item.name.isNotEmpty)
            .toList()
        : <FeedbackOrderProduct>[];
    return FeedbackOrder(
      orderId: id,
      shortId: (json['shortId'] ?? '').toString(),
      deliveryPointName: (json['deliveryPointName'] ?? '').toString(),
      products: products,
    );
  }
}

class FeedbackOrderProduct {
  final String? productId;
  final String name;
  final String? image;
  final int quantity;

  const FeedbackOrderProduct({
    required this.productId,
    required this.name,
    required this.image,
    required this.quantity,
  });

  String get key => productId ?? name;
}

/// Seçilebilir hap
class FeedbackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool negative;

  const FeedbackChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = negative ? MarketPalette.red : MarketPalette.green;
    final soft = negative ? MarketPalette.redSoft : MarketPalette.greenSoft;
    final ink = negative ? MarketPalette.red : MarketPalette.greenDark;
    return Material(
      color: selected ? soft : MarketPalette.surfaceMuted,
      borderRadius: BorderRadius.circular(MarketRadius.pill),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(MarketRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MarketRadius.pill),
            border: Border.all(
              color: selected ? accent : MarketPalette.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: MarketText.label(color: selected ? ink : MarketPalette.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Yıldız satırı (ürün ve teslimat puanı için)
class FeedbackStars extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  const FeedbackStars({super.key, required this.value, this.onChanged, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            onPressed: onChanged == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged!(star);
                  },
            iconSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            constraints: const BoxConstraints(),
            tooltip: '$star yıldız',
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: star <= value ? MarketPalette.orange : MarketPalette.lineStrong,
            ),
          ),
      ],
    );
  }
}

/// Siparişteki ürünler: müşteri sorunlu ürünü ve sorunun türünü işaretler.
/// [selected]: ürün anahtarı → sorun türü (bozuk / eksik / yanlis)
class ProblemItemsPicker extends StatelessWidget {
  final List<FeedbackOrderProduct> products;
  final Map<String, String> selected;
  final ValueChanged<Map<String, String>> onChanged;
  final bool enabled;

  const ProblemItemsPicker({
    super.key,
    required this.products,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hangi üründe sorun vardı?', style: MarketText.heading(size: 15)),
        const SizedBox(height: 4),
        Text('Ürünü ve ne olduğunu işaretle; ekibimiz o ürünü kontrol edecek.',
            style: MarketText.caption()),
        const SizedBox(height: MarketSpace.md),
        for (final product in products.take(20))
          Padding(
            padding: const EdgeInsets.only(bottom: MarketSpace.sm),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: selected.containsKey(product.key)
                    ? MarketPalette.redSoft
                    : MarketPalette.canvas,
                borderRadius: BorderRadius.circular(MarketRadius.md),
                border: Border.all(
                  color: selected.containsKey(product.key)
                      ? MarketPalette.redLine
                      : MarketPalette.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.quantity > 1 ? '${product.name} ×${product.quantity}' : product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(size: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final issue in feedbackIssueTypes)
                        FeedbackChip(
                          label: issue.label,
                          negative: true,
                          selected: selected[product.key] == issue.id,
                          onTap: !enabled
                              ? null
                              : () {
                                  final next = Map<String, String>.from(selected);
                                  if (next[product.key] == issue.id) {
                                    next.remove(product.key);
                                  } else {
                                    next[product.key] = issue.id;
                                  }
                                  onChanged(next);
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sunucuya gidecek sorunlu ürün listesi
List<Map<String, String>> problemItemsPayload(
  List<FeedbackOrderProduct> products,
  Map<String, String> selected,
) {
  return [
    for (final product in products)
      if (selected[product.key] != null)
        {
          if (product.productId != null) 'productId': product.productId!,
          'name': product.name,
          'issue': selected[product.key]!,
        },
  ];
}

/// Teşekkür ekranı. Memnun müşteriye davet kodu ve mağaza puanı, memnun olmayan
/// müşteriye destek görüşmesi gösterilir.
class FeedbackThanks extends StatefulWidget {
  final bool happy;
  final String? supportChatId;

  const FeedbackThanks({super.key, required this.happy, this.supportChatId});

  @override
  State<FeedbackThanks> createState() => _FeedbackThanksState();
}

class _FeedbackThanksState extends State<FeedbackThanks> {
  @override
  void initState() {
    super.initState();
    if (widget.happy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final referral = context.read<ReferralViewModel>();
        if (referral.referral == null && !referral.isLoading) referral.loadReferralInfo();
      });
    }
  }

  void _share(String code, String link, int percent) {
    HapticFeedback.lightImpact();
    Share.share(
      '🎁 Benim Marketim\'e davetlisin!\n\n"$code" koduyla kayıt ol, ilk siparişinde %$percent indirim kazan!\n\n$link',
    );
  }

  @override
  Widget build(BuildContext context) {
    final happy = widget.happy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MarketIconTile(
            icon: happy ? Icons.favorite_rounded : Icons.support_agent_rounded,
            size: 60,
            background: happy ? MarketPalette.greenSoft : MarketPalette.orangeSoft,
            foreground: happy ? MarketPalette.green : MarketPalette.orangeInk,
          ),
        ),
        const SizedBox(height: MarketSpace.lg),
        Text(happy ? 'Teşekkürler!' : 'Üzgünüz, bunu düzelteceğiz',
            textAlign: TextAlign.center, style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text(
          happy
              ? 'Görüşün bize ulaştı. Memnun kalmana çok sevindik.'
              : widget.supportChatId != null
                  ? 'Destek ekibimiz yazdıklarını gördü ve sana sohbetten dönüş yapacak.'
                  : 'Yazdıklarını ekibimiz okuyacak ve gerekirse seninle iletişime geçecek.',
          textAlign: TextAlign.center,
          style: MarketText.body(color: MarketPalette.muted),
        ),
        if (happy)
          Consumer<ReferralViewModel>(
            builder: (context, vm, _) {
              final referral = vm.referral;
              if (referral == null || !referral.isActive || referral.code.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: MarketSpace.lg),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MarketPalette.limeSoft,
                    borderRadius: BorderRadius.circular(MarketRadius.md),
                    border: Border.all(color: MarketPalette.limeLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Arkadaşını getir, ikiniz de kazanın',
                          style: MarketText.heading(size: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Arkadaşın ilk siparişinde %${referral.inviteeDiscountPercent} indirim alır, sen de %${referral.rewardDiscountPercent} indirim kuponu kazanırsın.',
                        style: MarketText.caption(color: MarketPalette.inkSoft),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(MarketRadius.sm),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: referral.code));
                                showMarketSnack(context, 'Davet kodun kopyalandı',
                                    icon: Icons.copy_rounded);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                                  border: Border.all(color: MarketPalette.limeLine),
                                ),
                                child: Text(referral.code,
                                    style: MarketText.heading(size: 16, color: MarketPalette.greenDeep)
                                        .copyWith(letterSpacing: 1.5)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _share(referral.code, referral.link,
                                referral.inviteeDiscountPercent),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Paylaş'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: MarketSpace.xl),
        if (!happy && widget.supportChatId != null) ...[
          FilledButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop(true);
              router.push('/chat/${widget.supportChatId}');
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Destek görüşmesini aç'),
          ),
          const SizedBox(height: MarketSpace.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kapat'),
          ),
        ] else ...[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            child: const Text('Tamam'),
          ),
          if (happy) ...[
            const SizedBox(height: MarketSpace.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(true);
                ReviewService.instance.openStoreListing();
              },
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Google Play / App Store\'da da puan ver'),
            ),
          ],
        ],
      ],
    );
  }
}

/// Alt sayfa tutamacı
class FeedbackSheetHandle extends StatelessWidget {
  const FeedbackSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(bottom: MarketSpace.lg),
          decoration: BoxDecoration(
            color: MarketPalette.lineStrong,
            borderRadius: BorderRadius.circular(MarketRadius.pill),
          ),
        ),
      );
}

/// Klavyeyle birlikte yükselen, kaydırılabilir alt sayfa gövdesi
class FeedbackSheetBody extends StatelessWidget {
  final Widget child;
  const FeedbackSheetBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MarketSpace.xl,
          MarketSpace.md,
          MarketSpace.xl,
          MarketSpace.xl + bottomInset,
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

/// Ortak alt sayfa açıcı
Future<T?> showFeedbackSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MarketPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
    ),
    builder: (_) => FeedbackSheetBody(child: child),
  );
}
