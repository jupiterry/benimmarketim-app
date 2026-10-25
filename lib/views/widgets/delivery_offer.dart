import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/delivery_viewmodel.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

/// Müşteriye gösterilen teslimat ücreti durumu: ücretsiz mi, ücretliyse ne
/// kadar ve ne kadarlık sepette ücretsiz olur. Ana sayfa, ürün detayı ve
/// sepet aynı hesabı kullanır.
///
/// * Adrese teslimat kapalı (yurt akışı): teslimat ücretsiz.
/// * Kampanya: her yerde ücretsiz.
/// * Adres seçili ve teklif hesaplandı: teklifin sonucu.
/// * Adres seçili değil: adres bölgelerinin (Devrek) ücreti ve eşiği;
///   yurtlar ücretsizse ayrıca belirtilir.
class DeliveryOffer {
  final bool free;
  final bool campaign;

  /// Ücretli teslimatın tutarı
  final double fee;

  /// Bu tutardaki sepette teslimat ücretsiz (yoksa null)
  final double? threshold;

  /// Ücretsiz teslimata kalan tutar (eşik varsa ve henüz geçilmediyse)
  final double? remaining;

  /// Yurtlara teslimat ücretsiz (adrese ücretliyken belirtilir)
  final bool dormsFree;

  const DeliveryOffer._({
    required this.free,
    this.campaign = false,
    this.fee = 0,
    this.threshold,
    this.remaining,
    this.dormsFree = false,
  });

  static const freeDelivery = DeliveryOffer._(free: true);

  static DeliveryOffer of(DeliveryViewModel? delivery, double cartTotal) {
    if (delivery == null || !delivery.canOrderToAddress) return freeDelivery;
    if (delivery.freeDeliveryEverywhere) {
      return const DeliveryOffer._(free: true, campaign: true);
    }

    // Seçili adresin teklifi en doğru bilgidir
    final quote = delivery.selectedZoneId != null && delivery.selectionUsable
        ? delivery.quote
        : null;
    if (quote != null) {
      if (quote.isFree) {
        return DeliveryOffer._(free: true, campaign: quote.isCampaign);
      }
      final zone = delivery.zoneById(quote.zoneId);
      return DeliveryOffer._(
        free: false,
        fee: quote.deliveryFee,
        threshold: zone?.freeDeliveryThreshold,
        remaining: quote.remainingForFree,
      );
    }

    final zones = delivery.addressZones;
    final dormsFree = delivery.dormZones.isEmpty ||
        delivery.dormZones.every((z) => z.isFree || z.deliveryFee <= 0);
    if (zones.isEmpty) return freeDelivery;
    if (zones.every((z) => z.isFree || z.deliveryFee <= 0)) {
      return freeDelivery;
    }
    // En uygun ücretli bölge (Devrek tek bölge olduğunda o)
    final paid = zones.where((z) => !z.isFree && z.deliveryFee > 0).toList()
      ..sort((a, b) => a.deliveryFee.compareTo(b.deliveryFee));
    final zone = paid.first;
    return _paid(zone, cartTotal, dormsFree: dormsFree);
  }

  static DeliveryOffer _paid(DeliveryZone zone, double cartTotal,
      {required bool dormsFree}) {
    final threshold = zone.freeDeliveryThreshold;
    if (threshold != null && cartTotal >= threshold) {
      return DeliveryOffer._(free: true, threshold: threshold);
    }
    return DeliveryOffer._(
      free: false,
      fee: zone.deliveryFee,
      threshold: threshold,
      remaining: threshold == null || cartTotal <= 0
          ? null
          : (threshold - cartTotal).clamp(0, double.infinity).toDouble(),
      dormsFree: dormsFree,
    );
  }

  /// Kısa başlık: "Ücretsiz teslimat" / "Teslimat ₺40"
  String get title => free
      ? 'Ücretsiz teslimat'
      : 'Teslimat ${formatTlShort(fee)}';

  /// Ayrıntı: eşik, kalan tutar, yurt notu
  String? get detail {
    if (campaign) return 'Kampanya: tüm bölgelerde teslimat ücretsiz';
    if (free) {
      return threshold != null
          ? '${formatTlShort(threshold!)} üstü siparişte teslimat ücretsiz'
          : null;
    }
    final parts = [
      if (remaining != null && remaining! > 0)
        freeDeliveryHint(remaining!)
      else if (threshold != null)
        '${formatTlShort(threshold!)} üstü siparişte ücretsiz',
      if (dormsFree) 'yurtlara ücretsiz',
    ];
    if (parts.isEmpty) return null;
    final text = parts.join(' · ');
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Eşiğe ilerleme (0-1); eşik yoksa null
  double? get progress {
    final t = threshold;
    final r = remaining;
    if (free || t == null || t <= 0 || r == null) return null;
    return ((t - r) / t).clamp(0.0, 1.0);
  }

  /// Ana sayfa başlığındaki kısa çip metni
  String get chipLabel {
    if (free) return 'Ücretsiz teslimat';
    if (threshold != null) {
      return 'Teslimat ${formatTlShort(fee)} · ${formatTlShort(threshold!)} üstü ücretsiz';
    }
    return 'Teslimat ${formatTlShort(fee)}';
  }
}

/// Sağlayıcılardan teslimat durumunu okur (sepet tutarı dahil).
DeliveryOffer watchDeliveryOffer(BuildContext context) {
  final delivery = context.watch<DeliveryViewModel?>();
  final total = context.select<CartViewModel, double>((c) => c.totalPrice);
  return DeliveryOffer.of(delivery, total);
}

/// Ürün detayı ve sepette teslimat ücreti bandı: ücretsizse yeşil ve net,
/// ücretliyse tutar, eşik ve eşiğe ilerleme.
class DeliveryOfferBanner extends StatelessWidget {
  const DeliveryOfferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final offer = watchDeliveryOffer(context);
    final free = offer.free;
    final background = free ? MarketPalette.greenSoft : MarketPalette.surface;
    final border = free ? MarketPalette.greenLine : MarketPalette.lineStrong;
    final ink = free ? MarketPalette.greenDark : MarketPalette.ink;
    final detail = offer.detail;
    final progress = offer.progress;

    return Semantics(
      container: true,
      label: [offer.title, if (detail != null) detail].join('. '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: free ? MarketPalette.green : MarketPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                size: 20,
                color: free ? Colors.white : MarketPalette.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(offer.title,
                      style: MarketText.heading(size: 15, color: ink)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: MarketText.caption(
                        size: 12.5,
                        color: free
                            ? MarketPalette.greenDark
                            : MarketPalette.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MarketRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: MarketPalette.green,
                        backgroundColor: MarketPalette.line,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
