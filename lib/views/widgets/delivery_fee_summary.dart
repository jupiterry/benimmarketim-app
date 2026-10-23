import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/delivery.dart';
import '../../services/api_service.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/delivery_viewmodel.dart';
import '../../viewmodels/referral_viewmodel.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

/// Sepet ve ödeme ekranlarının teslimat ücreti satırı, ödenecek tutar ve
/// adres akışında siparişi engelleyen durumlar. Yalnızca adrese teslimat
/// açıkken (`DeliveryViewModel.canOrderToAddress`) kullanılır; yurt akışı
/// bugünkü "Teslimat: Ücretsiz" satırıyla kalır.

/// Sipariş ADDRESS_ORDERING_DISABLED ile reddedildi: ekran yurt akışına döner.
const String addressOrderingDisabledMessage =
    'Adrese teslimat şu an kapalı; yurt teslimatıyla devam edebilirsin.';

/// Adres akışında not alanının altındaki hatırlatma
const String addressNoteHint = 'Adresini not yerine adres alanına yaz.';

/// Kupon istekleri için seçili teslimat bölgesi: yalnızca adres akışında ve
/// bir adres/yurt seçiliyken; aksi hâlde null (istekler bölgesiz gider).
String? couponDeliveryZone(DeliveryViewModel? delivery) =>
    delivery != null && delivery.canOrderToAddress
        ? delivery.selectedZoneId
        : null;

/// Ödenecek tutar = ürünler − kupon + teslimat. Kupon yalnızca ürün tutarına
/// uygulanır; teslimat ücretini düşürmez.
double checkoutPayable({
  required double productsTotal,
  double couponDiscount = 0,
  DeliveryQuote? quote,
}) {
  final products =
      (productsTotal - couponDiscount).clamp(0.0, double.infinity).toDouble();
  return products + (quote?.payableFee ?? 0);
}

enum DeliveryFeeKind { campaign, free, paid }

/// Teklifin ekrandaki karşılığı.
class DeliveryFeeDisplay {
  final DeliveryFeeKind kind;

  /// Soldaki etiket: "Teslimat ücreti" (ücretli) ya da "Teslimat"
  final String label;

  /// Sağdaki değer: "₺40,00" ya da "Ücretsiz teslimat"
  final String value;

  /// Kampanyada üstü çizili gösterilen normal ücret
  final double? struckFee;

  /// Ücretli bölgede eşik ipucu: "₺360 daha ekle, teslimat ücretsiz"
  final String? hint;

  const DeliveryFeeDisplay({
    required this.kind,
    required this.label,
    required this.value,
    this.struckFee,
    this.hint,
  });

  static const String freeLabel = 'Ücretsiz teslimat';
  static const String campaignTag = 'Kampanya';

  factory DeliveryFeeDisplay.fromQuote(DeliveryQuote quote) {
    if (quote.isCampaign) {
      return DeliveryFeeDisplay(
        kind: DeliveryFeeKind.campaign,
        label: 'Teslimat',
        value: freeLabel,
        struckFee: quote.deliveryFee > 0 ? quote.deliveryFee : null,
      );
    }
    if (quote.payableFee <= 0) {
      return const DeliveryFeeDisplay(
        kind: DeliveryFeeKind.free,
        label: 'Teslimat',
        value: freeLabel,
      );
    }
    final remaining = quote.remainingForFree;
    return DeliveryFeeDisplay(
      kind: DeliveryFeeKind.paid,
      label: 'Teslimat ücreti',
      value: formatTl(quote.payableFee),
      hint: remaining != null && remaining > 0
          ? freeDeliveryHint(remaining)
          : null,
    );
  }
}

/// Adres akışında siparişi engelleyen durum.
class AddressOrderBlock {
  final String message;

  /// Kullanıcı başka bir adres seçmeli (kapalı/bulunamayan bölge)
  final bool pickAnother;

  /// Teklif hâlâ hesaplanıyor (geçici)
  final bool pending;

  /// Teklif alınamadı; tekrar denenebilir
  final bool retry;

  const AddressOrderBlock(
    this.message, {
    this.pickAnother = false,
    this.pending = false,
    this.retry = false,
  });
}

const String _pickAnotherSuffix = 'Lütfen başka bir adres seç.';

bool isZoneUnavailableCode(String? code) =>
    code == 'ZONE_CLOSED' || code == 'ZONE_NOT_FOUND';

/// Adres akışında siparişi engelleyen durum; null → sipariş verilebilir.
AddressOrderBlock? addressOrderBlock({
  required bool hasSelection,
  required bool selectionUsable,
  DeliveryQuote? quote,
  bool quoteLoading = false,
  ApiException? quoteError,
}) {
  if (!hasSelection) {
    return const AddressOrderBlock(
        'Siparişini verebilmek için bir teslimat adresi seç.');
  }
  if (quoteError != null && isZoneUnavailableCode(quoteError.code)) {
    return AddressOrderBlock('${quoteError.message} $_pickAnotherSuffix',
        pickAnother: true);
  }
  if (!selectionUsable) {
    return const AddressOrderBlock('$zoneClosedNote $_pickAnotherSuffix',
        pickAnother: true);
  }
  if (quote == null) {
    if (quoteError != null && !quoteLoading) {
      return AddressOrderBlock(quoteError.message, retry: true);
    }
    return const AddressOrderBlock('Teslimat ücreti hesaplanıyor…',
        pending: true);
  }
  if (!quote.meetsMinimum) return AddressOrderBlock(minimumOrderMessage(quote));
  return null;
}

/// Teslimat ücreti satırı: kampanya (normal ücret üstü çizili + "Kampanya"),
/// ücretsiz bölge/eşik ya da ücret ve altında eşik ipucu. Teklif yüklenirken
/// iskelet, hata olursa "Hesaplanamadı" (ve varsa "Tekrar dene").
class DeliveryFeeLine extends StatelessWidget {
  final DeliveryQuote? quote;
  final bool loading;
  final ApiException? error;
  final VoidCallback? onRetry;

  /// Satır yazı boyutu (ödeme özeti 13, sepet özeti 14)
  final double size;

  const DeliveryFeeLine({
    super.key,
    required this.quote,
    this.loading = false,
    this.error,
    this.onRetry,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = MarketText.body(color: MarketPalette.muted, size: size);
    final quote = this.quote;

    if (quote == null) {
      final failed = error != null && !loading;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text('Teslimat ücreti', style: labelStyle)),
            if (!failed)
              const MarketSkeletonPulse(
                semanticLabel: 'Teslimat ücreti hesaplanıyor',
                child: MarketSkeleton(width: 72, height: 14),
              )
            else ...[
              Text('Hesaplanamadı',
                  style: MarketText.label(color: MarketPalette.red, size: size)),
              if (onRetry != null && !isZoneUnavailableCode(error?.code)) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.greenDark,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ],
          ],
        ),
      );
    }

    final display = DeliveryFeeDisplay.fromQuote(quote);
    final free = display.kind != DeliveryFeeKind.paid;
    final struck = display.struckFee;
    final hint = display.hint;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(display.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle),
                    ),
                    if (display.kind == DeliveryFeeKind.campaign) ...[
                      const SizedBox(width: 6),
                      const MarketPill(
                        label: DeliveryFeeDisplay.campaignTag,
                        icon: Icons.celebration_rounded,
                        background: MarketPalette.limeSoft,
                        foreground: MarketPalette.greenDeep,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                display.value,
                style: MarketText.label(
                    color: free ? MarketPalette.green : MarketPalette.ink,
                    size: size),
              ),
            ],
          ),
          // Kampanya: normal ücret değerin altında üstü çizili
          if (struck != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formatTl(struck),
                textAlign: TextAlign.right,
                semanticsLabel: 'Normal ücret ${formatTl(struck)}',
                style: MarketText.oldPrice(size: size - 1),
              ),
            ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 15, color: MarketPalette.greenDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint,
                      style: MarketText.caption(
                          color: MarketPalette.greenDark,
                          weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Adres seçilmemişken sepetteki tahmini teslimat satırı: bölge listesinin en
/// düşük ücreti ("En düşük ₺40") ve "Teslimat ücreti bölgeye göre değişir".
class DeliveryFeeEstimateLine extends StatelessWidget {
  /// En düşük ödenecek ücret; null → bölgeler henüz yok/yüklenemedi
  final double? cheapestFee;

  /// Bölgeler yükleniyor
  final bool loading;

  /// Her bölgede teslimat ücretsiz (kampanya ya da hepsi ücretsiz)
  final bool freeEverywhere;
  final double size;

  const DeliveryFeeEstimateLine({
    super.key,
    required this.cheapestFee,
    this.loading = false,
    this.freeEverywhere = false,
    this.size = 13,
  });

  static const String variesNote = 'Teslimat ücreti bölgeye göre değişir';

  /// Sağdaki değer metni
  static String valueText(double? cheapestFee, {bool freeEverywhere = false}) {
    if (freeEverywhere) return 'Ücretsiz';
    // En ucuz bölge ücretsiz ama hepsi değil: "Ücretsiz" yanıltır
    if (cheapestFee == null || cheapestFee <= 0) return 'Bölgeye göre';
    return 'En düşük ${formatTlShort(cheapestFee)}';
  }

  @override
  Widget build(BuildContext context) {
    final value = valueText(cheapestFee, freeEverywhere: freeEverywhere);
    final free = value == 'Ücretsiz';
    final showNote = !freeEverywhere;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Teslimat',
                    style:
                        MarketText.body(color: MarketPalette.muted, size: size)),
              ),
              if (loading && cheapestFee == null)
                const MarketSkeletonPulse(
                  child: MarketSkeleton(width: 72, height: 14),
                )
              else
                Text(
                  value,
                  style: MarketText.label(
                      color: free ? MarketPalette.green : MarketPalette.ink,
                      size: size),
                ),
            ],
          ),
          if (showNote)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                cheapestFee != null && cheapestFee! <= 0
                    ? '$variesNote; bazı bölgelerde ücretsiz.'
                    : '$variesNote.',
                style: MarketText.caption(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sepeti ve teslimat seçimini izler: sepet, adres ya da yurt değişince
/// teslimat ücreti teklifi ister (DeliveryViewModel bekletir ve tekilleştirir)
/// ve kupon isteklerinin bölgesini (sepet ve cüzdan) günceller.
///
/// Dinleyiciler değişikliği bir mikro göreve erteler: build sırasında ya da
/// başka bir bildirimin içinde yeni bildirim tetiklenmez.
class DeliveryCheckoutSync {
  DeliveryCheckoutSync({
    required this.cart,
    required this.delivery,
    this.referral,
    this.onZoneChanged,
  });

  final CartViewModel cart;
  final DeliveryViewModel delivery;
  final ReferralViewModel? referral;

  /// Seçili bölge değişti (yurt seçildiyse sayfa kuponu noktaya göre de
  /// doğrulayabilir)
  final void Function(String? zoneId)? onZoneChanged;

  String? _quoteKey;
  String? _zone;
  bool _zoneSent = false;
  bool _scheduled = false;
  bool _started = false;
  bool _disposed = false;

  /// Dinlemeye başlar ve hemen bir kez eşitler: build dışında (ör. kare
  /// sonrası geri çağrıda) çağrılmalı.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    cart.addListener(_schedule);
    delivery.addListener(_schedule);
    _sync();
  }

  /// Aynı sepet ve bölge için teklifi yeniden ister (ör. sunucu siparişi
  /// BELOW_MINIMUM ile reddetti, hata sonrası "Tekrar dene").
  void refreshQuote() {
    if (_disposed) return;
    // Önce temizlenir; aynı anahtar için yeni istek ancak böyle gider.
    delivery.requestQuote(const []);
    _quoteKey = null;
    _sync();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _sync();
    });
  }

  void _sync() {
    final addressMode = delivery.canOrderToAddress;
    final zone = addressMode ? delivery.selectedZoneId : null;
    final items = cart.items;
    final key = [
      addressMode,
      zone,
      for (final item in items) '${item.product.id}x${item.quantity}',
    ].join('|');
    if (key != _quoteKey) {
      _quoteKey = key;
      delivery.requestQuote(addressMode && zone != null ? items : const []);
    }
    if (!_zoneSent || zone != _zone) {
      final changed = _zoneSent;
      _zoneSent = true;
      _zone = zone;
      cart.setDeliveryZone(zone);
      referral?.setDeliveryZone(zone);
      if (changed || zone != null) onZoneChanged?.call(zone);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      cart.removeListener(_schedule);
      delivery.removeListener(_schedule);
    }
  }
}
