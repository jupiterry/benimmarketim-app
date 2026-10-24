import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/delivery.dart';
import '../../services/turkish_text.dart';
import '../../viewmodels/delivery_viewmodel.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

/// Teslimat bölgesi seçici: arama kutulu, bölge tipine göre gruplu alt
/// sayfa ([includeDorms] ise yurtlar da listelenir). Seçilen bölgeyi döndürür;
/// kapatılırsa null.
///
/// Bölgeler [DeliveryViewModel]'den gelir; yüklenmediyse burada yüklenir.
Future<DeliveryZone?> showDeliveryZonePicker(
  BuildContext context, {
  String? selectedZoneId,
  bool includeDorms = true,
}) {
  final delivery = context.read<DeliveryViewModel>();
  if (delivery.zonesError != null && delivery.zones.isEmpty) {
    delivery.loadZones(force: true);
  } else {
    delivery.loadZones();
  }
  return showMarketSheet<DeliveryZone>(
    context,
    maxHeightFactor: .88,
    builder: (_) => ChangeNotifierProvider<DeliveryViewModel>.value(
      value: delivery,
      child: DeliveryZonePickerSheet(
        selectedZoneId: selectedZoneId,
        includeDorms: includeDorms,
      ),
    ),
  );
}

/// [showDeliveryZonePicker]'ın içeriği. Seçimde sayfayı bölgeyle kapatır.
class DeliveryZonePickerSheet extends StatefulWidget {
  final String? selectedZoneId;
  final bool includeDorms;

  const DeliveryZonePickerSheet({
    super.key,
    this.selectedZoneId,
    this.includeDorms = true,
  });

  @override
  State<DeliveryZonePickerSheet> createState() =>
      _DeliveryZonePickerSheetState();
}

class _DeliveryZonePickerSheetState extends State<DeliveryZonePickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  // Grupların sırası: önce ilçe merkezi, sonra eski mahalle/köy bölgeleri,
  // en son yurtlar.
  static const _groupOrder = [
    DeliveryZoneType.ilce,
    DeliveryZoneType.mahalle,
    DeliveryZoneType.koy,
    DeliveryZoneType.yurt,
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value.trim());

  void _clearQuery() {
    _search.clear();
    _setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryViewModel>();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final campaign = delivery.freeDeliveryEverywhere;

    final available = delivery.zones
        .where((z) => widget.includeDorms || !z.isDorm)
        .toList();
    final matches = _query.isEmpty
        ? available
        : available.where((z) => TurkishText.contains(z.name, _query)).toList();

    final Widget content;
    if (available.isEmpty && delivery.zonesLoading) {
      content = const SingleChildScrollView(
        child: MarketListSkeleton(
          count: 5,
          padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
        ),
      );
    } else if (available.isEmpty && delivery.zonesError != null) {
      content = MarketEmptyState.error(
        title: 'Bölgeler yüklenemedi',
        message: delivery.zonesError!,
        onRetry: () => delivery.loadZones(force: true),
      );
    } else if (available.isEmpty) {
      content = MarketEmptyState(
        icon: Icons.location_off_outlined,
        title: widget.includeDorms
            ? 'Şu an teslimat bölgesi yok'
            : 'Şu an adrese teslimat yapılmıyor',
        message: widget.includeDorms
            ? 'Teslimat bölgelerimiz açıldığında burada görünecek.'
            : 'Adrese teslimat açıldığında bölge burada görünecek. '
                'Şimdilik siparişini yurt teslimat noktasına verebilirsin.',
        secondaryLabel: 'Yenile',
        onSecondary: () => delivery.loadZones(force: true),
      );
    } else if (matches.isEmpty) {
      content = MarketEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aramana uyan bölge yok',
        message:
            'Bölge adını farklı yazmayı dene. Listede yoksa oraya henüz teslimat yapmıyoruz.',
        secondaryLabel: 'Aramayı temizle',
        onSecondary: _clearQuery,
      );
    } else {
      content = _buildList(matches, campaign: campaign);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MarketSheetHandle(),
                MarketSheetHeader(
                  title: 'Teslimat bölgeni seç',
                  subtitle: widget.includeDorms
                      ? 'Adresinin ya da yurdunun bölgesini seç. Ücret ve süre bölgeye göre değişir.'
                      : 'Adresinin bölgesini seç. Ücret ve süre bölgeye göre değişir.',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: _setQuery,
                    textInputAction: TextInputAction.search,
                    style: MarketText.body(size: 15),
                    decoration: InputDecoration(
                      hintText: 'Bölge ara',
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: MarketPalette.canvas,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Aramayı temizle',
                              onPressed: _clearQuery,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                if (campaign && available.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: MarketNotice.success(
                      icon: Icons.local_offer_rounded,
                      text: 'Kampanya: tüm bölgelerde teslimat ücretsiz',
                    ),
                  ),
                const Divider(height: 1, color: MarketPalette.line),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<DeliveryZone> zones, {required bool campaign}) {
    final rows = <Widget>[];
    for (final type in _groupOrder) {
      final group = zones.where((z) => z.type == type).toList();
      if (group.isEmpty) continue;
      rows.add(Padding(
        padding: EdgeInsets.fromLTRB(20, rows.isEmpty ? 14 : 22, 20, 8),
        child: Semantics(
          header: true,
          child: Text(
            TurkishText.toUpper(type.groupLabel),
            style: MarketText.eyebrow(color: MarketPalette.muted),
          ),
        ),
      ));
      for (final zone in group) {
        rows.add(_ZoneRow(
          zone: zone,
          campaign: campaign,
          selected: zone.id == widget.selectedZoneId,
          onTap: () => Navigator.of(context).pop(zone),
        ));
      }
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 16 + bottom),
      children: rows,
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final DeliveryZone zone;
  final bool campaign;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneRow({
    required this.zone,
    required this.campaign,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final free = zone.isFree || zone.deliveryFee <= 0;
    // Kampanyada bölgenin normal ücreti üstü çizili gösterilir.
    final struckFee = campaign && zone.deliveryFee > 0;
    final eta = zone.etaText.trim();
    final icon = switch (zone.type) {
      DeliveryZoneType.ilce => Icons.location_city_rounded,
      DeliveryZoneType.mahalle => Icons.location_city_rounded,
      DeliveryZoneType.koy => Icons.cottage_rounded,
      DeliveryZoneType.yurt => Icons.apartment_rounded,
    };

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? MarketPalette.greenSoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
            child: Row(
              children: [
                MarketIconTile(
                  icon: icon,
                  size: 40,
                  background:
                      selected ? MarketPalette.surface : MarketPalette.greenSoft,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: MarketText.label(size: 15),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: zoneFeeLabel(zone),
                              style: MarketText.caption(
                                color: free
                                    ? MarketPalette.greenDark
                                    : MarketPalette.inkSoft,
                                weight: FontWeight.w700,
                              ),
                            ),
                            if (struckFee) ...[
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: formatTlShort(zone.deliveryFee),
                                style: MarketText.oldPrice(),
                              ),
                            ],
                            if (eta.isNotEmpty) TextSpan(text: ' · $eta'),
                            if (zone.minimumOrderAmount > 0)
                              TextSpan(
                                text:
                                    ' · En az ${formatTlShort(zone.minimumOrderAmount)}',
                              ),
                          ],
                        ),
                        style: MarketText.caption(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: MarketPalette.green, semanticLabel: 'Seçili')
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: MarketPalette.subtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
