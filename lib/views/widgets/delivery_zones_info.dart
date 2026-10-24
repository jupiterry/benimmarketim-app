import 'package:flutter/material.dart';

import '../../models/delivery.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

// ---------------------------------------------------------------------------
// Mağaza bilgileri › Teslimat bölgeleri: bölge satırları, kısa özet ve tüm
// bölgelerin listelendiği alt sayfa (`GET /delivery/zones`).
// ---------------------------------------------------------------------------

/// Bu kadar bölgeye kadar liste profilde açık durur; fazlası özetlenir ve
/// "Tüm teslimat bölgeleri" alt sayfasında gösterilir.
const int deliveryZonesInlineLimit = 4;

/// Bölgeleri tipe göre gruplar (Yurtlar, İlçe merkezi, ...). Sunucunun
/// sıralaması grup içinde korunur; boş grup yer almaz.
List<(DeliveryZoneType, List<DeliveryZone>)> groupZonesByType(
    List<DeliveryZone> zones) {
  return [
    for (final type in DeliveryZoneType.values)
      if (zones.any((z) => z.type == type))
        (type, zones.where((z) => z.type == type).toList()),
  ];
}

/// "2 yurt · Devrek" (ilçe merkezi adıyla, diğerleri sayıyla)
String zoneCountsSummary(List<DeliveryZone> zones) {
  String unit(DeliveryZoneType type) => switch (type) {
        DeliveryZoneType.yurt => 'yurt',
        DeliveryZoneType.ilce => 'ilçe',
        DeliveryZoneType.mahalle => 'mahalle',
        DeliveryZoneType.koy => 'köy',
      };
  return [
    for (final (type, list) in groupZonesByType(zones))
      if (type == DeliveryZoneType.ilce)
        ...list.map((z) => z.name)
      else
        '${list.length} ${unit(type)}',
  ].join(' · ');
}

/// Ücret aralığı: "Tüm bölgelerde ücretsiz teslimat", "Teslimat ₺40",
/// "Teslimat bölgeye göre ücretsiz – ₺40", "Teslimat bölgeye göre ₺20 – ₺40".
String zoneFeeRangeSummary(List<DeliveryZone> zones) {
  if (zones.isEmpty) return '';
  final fees = [for (final z in zones) z.isFree ? 0.0 : z.deliveryFee];
  final low = fees.reduce((a, b) => a < b ? a : b);
  final high = fees.reduce((a, b) => a > b ? a : b);
  if (high <= 0) return 'Tüm bölgelerde ücretsiz teslimat';
  if (low == high) return 'Teslimat ${formatTlShort(high)}';
  final from = low <= 0 ? 'ücretsiz' : formatTlShort(low);
  return 'Teslimat bölgeye göre $from – ${formatTlShort(high)}';
}

/// Kampanya notu (her bölgede teslimat ücretsiz)
const String freeDeliveryCampaignNote =
    'Kampanya: tüm bölgelerde teslimat ücretsiz!';

IconData zoneTypeIcon(DeliveryZoneType type) => switch (type) {
      DeliveryZoneType.yurt => Icons.apartment_rounded,
      DeliveryZoneType.ilce => Icons.location_city_rounded,
      DeliveryZoneType.mahalle => Icons.home_work_outlined,
      DeliveryZoneType.koy => Icons.cottage_outlined,
    };

/// Bölge adı ve altında ücret · süre. Kampanyada normal ücret üstü çizili.
class DeliveryZoneLine extends StatelessWidget {
  final DeliveryZone zone;
  final bool campaign;

  const DeliveryZoneLine({super.key, required this.zone, this.campaign = false});

  @override
  Widget build(BuildContext context) {
    final struck = campaign && zone.isFree && zone.deliveryFee > 0;
    final free = zone.isFree || zone.deliveryFee <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(zone.name, style: MarketText.label(size: 14)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              if (struck) ...[
                TextSpan(
                  text: formatTlShort(zone.deliveryFee),
                  style: MarketText.oldPrice(),
                ),
                const TextSpan(text: ' '),
              ],
              TextSpan(
                text: zoneFeeLabel(zone),
                style: MarketText.caption(
                  color: free ? MarketPalette.greenDark : MarketPalette.inkSoft,
                  weight: FontWeight.w700,
                ),
              ),
              if (zone.etaText.trim().isNotEmpty)
                // Süre ("15-30 dk") satır sonunda bölünmez
                TextSpan(
                    text: ' · ${zone.etaText.trim().replaceAll(' ', '\u00A0')}'),
            ],
          ),
          style: MarketText.caption(),
        ),
      ],
    );
  }
}

/// Menü grubundaki bölge satırı: tipin simgesi + [DeliveryZoneLine].
class DeliveryZoneTile extends StatelessWidget {
  final DeliveryZone zone;
  final bool campaign;

  const DeliveryZoneTile({super.key, required this.zone, this.campaign = false});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            MarketIconTile(icon: zoneTypeIcon(zone.type), size: 40),
            const SizedBox(width: 14),
            Expanded(child: DeliveryZoneLine(zone: zone, campaign: campaign)),
          ],
        ),
      ),
    );
  }
}

/// Tüm teslimat bölgeleri: tipe göre gruplu liste.
Future<void> showDeliveryZonesSheet(
  BuildContext context, {
  required List<DeliveryZone> zones,
  bool campaign = false,
}) {
  return showMarketSheet<void>(
    context,
    builder: (_) => DeliveryZonesSheet(zones: zones, campaign: campaign),
  );
}

class DeliveryZonesSheet extends StatelessWidget {
  final List<DeliveryZone> zones;
  final bool campaign;

  const DeliveryZonesSheet({
    super.key,
    required this.zones,
    this.campaign = false,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupZonesByType(zones);
    return MarketSheetScaffold(
      header: const MarketSheetHeader(
        title: 'Teslimat bölgeleri',
        subtitle: 'Bölgene göre teslimat ücreti ve tahmini süre',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (campaign) ...[
            const MarketNotice(
              icon: Icons.celebration_outlined,
              text: freeDeliveryCampaignNote,
            ),
            const SizedBox(height: MarketSpace.lg),
          ],
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) const SizedBox(height: MarketSpace.xl),
            MarketMenuGroup(
              title: '${groups[g].$1.groupLabel} (${groups[g].$2.length})',
              children: [
                for (final zone in groups[g].$2)
                  DeliveryZoneTile(zone: zone, campaign: campaign),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
