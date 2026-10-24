import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/delivery.dart';
import '../../viewmodels/delivery_viewmodel.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

/// Ödeme ekranında teslimat yeri seçimi (adrese teslimat açıkken): seçili
/// kayıtlı adres ya da yurt, "Adres değiştir" sayfası ve hiç adres yokken
/// "Adres ekle" çağrısı. Yurt akışında kullanılmaz.

/// Teslimat yeri sayfasında yapılan seçim.
sealed class DeliveryDestinationChoice {
  const DeliveryDestinationChoice();
}

/// Kayıtlı adres seçildi
class PickSavedAddress extends DeliveryDestinationChoice {
  final String addressId;
  const PickSavedAddress(this.addressId);
}

/// Yurt (bölge olarak) seçildi
class PickDormZone extends DeliveryDestinationChoice {
  final String zoneId;
  const PickDormZone(this.zoneId);
}

/// "Yeni adres ekle"
class AddNewAddress extends DeliveryDestinationChoice {
  const AddNewAddress();
}

/// "Adreslerimi düzenle"
class ManageAddresses extends DeliveryDestinationChoice {
  const ManageAddresses();
}

/// Adresin teslimat bölgesi kapalı mı (listede görünür ama seçilemez)
bool isAddressZoneClosed(DeliveryViewModel delivery, DeliveryAddress address) =>
    !address.zoneEnabled ||
    (delivery.zonesLoaded && delivery.zoneById(address.zoneId) == null);

IconData deliveryZoneIcon(DeliveryZoneType type) => switch (type) {
      DeliveryZoneType.yurt => Icons.apartment_rounded,
      DeliveryZoneType.mahalle => Icons.home_rounded,
      DeliveryZoneType.ilce => Icons.home_rounded,
      DeliveryZoneType.koy => Icons.cottage_rounded,
    };

/// Yurt seçeneğinin başlığı: "Kız KYK Yurdu — girişte teslim"
String dormDestinationTitle(DeliveryZone zone) =>
    '${zone.name} — girişte teslim';

/// Adres sınırına ulaşıldığında gösterilen açıklama
String addressLimitNote(int max) =>
    'En fazla $max adres kaydedebilirsin. Yeni adres için Adreslerim\'den '
    'birini sil.';

/// "Tahmini teslimat: 30-60 dk"
String? etaLine(DeliveryZone? zone) {
  final eta = zone?.etaText.trim() ?? '';
  return eta.isEmpty ? null : 'Tahmini teslimat: $eta';
}

/// Ödeme ekranındaki "Teslimat adresi" bölümünün içeriği.
class DeliveryAddressPanel extends StatelessWidget {
  final DeliveryViewModel delivery;

  /// "Adres değiştir" / "Teslimat noktası seç": seçim sayfasını açar
  final VoidCallback onChange;

  /// "Adres ekle": adres formunu açar
  final VoidCallback onAddAddress;

  /// Yükleme hatasında "Tekrar dene"
  final VoidCallback onRetry;

  /// İlk sipariş teyit araması notu gösterilsin mi (bölge istiyorsa ve
  /// kullanıcının ilk siparişiyse)
  final bool showFirstOrderCallback;

  const DeliveryAddressPanel({
    super.key,
    required this.delivery,
    required this.onChange,
    required this.onAddAddress,
    required this.onRetry,
    this.showFirstOrderCallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final addressesPending =
        !delivery.addressesLoaded && delivery.addressesError == null;
    final zonesPending = !delivery.zonesLoaded && delivery.zonesError == null;
    final failed = (!delivery.addressesLoaded && delivery.addressesError != null) ||
        (!delivery.zonesLoaded && delivery.zonesError != null);

    if (failed && !delivery.addressesLoading && !delivery.zonesLoading) {
      return _LoadError(onRetry: onRetry);
    }
    if (addressesPending || zonesPending || failed) {
      return const _PanelSkeleton();
    }

    final dormId = delivery.selectedDormZoneId;
    final address = delivery.selectedAddress;
    final Widget selected;
    if (dormId != null) {
      final zone = delivery.selectedDormZone;
      selected = _SelectedDestination(
        icon: Icons.apartment_rounded,
        title: zone != null ? dormDestinationTitle(zone) : 'Teslimat noktası',
        lines: [if (zone != null) zoneFeeLabel(zone)],
        eta: etaLine(zone),
        closed: zone == null,
      );
    } else if (address != null) {
      final zone = delivery.zoneById(address.zoneId);
      final fieldsSummary = address.fields.summary;
      selected = _SelectedDestination(
        icon: deliveryZoneIcon(address.zoneType),
        title: address.title,
        lines: [
          if (address.title != address.zoneName && address.zoneName.isNotEmpty)
            address.zoneName,
          if (fieldsSummary.isNotEmpty)
            fieldsSummary
          else if (address.fields.directions.trim().isNotEmpty)
            address.fields.directions.trim(),
        ],
        eta: etaLine(zone),
        closed: isAddressZoneClosed(delivery, address),
      );
    } else {
      return _AddAddressPrompt(
        canAdd: delivery.canAddAddress,
        maxAddresses: delivery.maxAddresses,
        hasDorms: delivery.dormZones.isNotEmpty,
        onAdd: onAddAddress,
        onPickPoint: onChange,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selected,
        if (showFirstOrderCallback) ...[
          const SizedBox(height: 10),
          const MarketNotice.info(
            icon: Icons.phone_callback_rounded,
            text: firstOrderCallbackNote,
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onChange,
          icon: const Icon(Icons.swap_horiz_rounded, size: 20),
          label: const Text('Adres değiştir'),
          style: OutlinedButton.styleFrom(
            foregroundColor: MarketPalette.greenDark,
            minimumSize: const Size.fromHeight(MarketSize.control),
            side: const BorderSide(color: MarketPalette.greenLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedDestination extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final String? eta;
  final bool closed;

  const _SelectedDestination({
    required this.icon,
    required this.title,
    required this.lines,
    required this.eta,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: closed ? MarketPalette.surfaceMuted : MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(
          color: closed ? MarketPalette.lineStrong : MarketPalette.green,
          width: closed ? 1 : 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketIconTile(
                icon: icon,
                size: 44,
                background: closed ? Colors.white : MarketPalette.green,
                foreground: closed ? MarketPalette.subtle : Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MarketText.label(size: 15)),
                    for (final line in lines) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.body(
                            color: MarketPalette.inkSoft, size: 13),
                      ),
                    ],
                    if (eta != null && !closed) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 15, color: MarketPalette.greenDark),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              eta!,
                              style: MarketText.caption(
                                  color: MarketPalette.greenDark,
                                  weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (closed) ...[
            const SizedBox(height: 10),
            const MarketNotice.warning(
              icon: Icons.block_rounded,
              text: '$zoneClosedNote Başka bir adres seç.',
            ),
          ],
        ],
      ),
    );
  }
}

class _AddAddressPrompt extends StatelessWidget {
  final bool canAdd;
  final int maxAddresses;
  final bool hasDorms;
  final VoidCallback onAdd;
  final VoidCallback onPickPoint;

  const _AddAddressPrompt({
    required this.canAdd,
    required this.maxAddresses,
    required this.hasDorms,
    required this.onAdd,
    required this.onPickPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketPalette.limeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.limeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MarketIconTile(
                icon: Icons.add_location_alt_rounded,
                size: 44,
                background: Colors.white,
                foreground: MarketPalette.greenDeep,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teslimat adresini ekle',
                        style: MarketText.heading(
                            color: MarketPalette.greenDeep, size: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'Kapını haritada işaretle, adresini bir kez yaz; '
                      'sonraki siparişlerde hazır gelir.',
                      style: MarketText.caption(color: MarketPalette.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Adres ekle'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(MarketSize.control),
            ),
          ),
          if (!canAdd) ...[
            const SizedBox(height: 6),
            Text(addressLimitNote(maxAddresses),
                style: MarketText.caption(color: MarketPalette.orangeInk)),
          ],
          if (hasDorms)
            TextButton(
              onPressed: onPickPoint,
              style: TextButton.styleFrom(
                foregroundColor: MarketPalette.greenDark,
                minimumSize: const Size.fromHeight(MarketSize.control),
              ),
              child: const Text('Teslimat noktası seç'),
            ),
        ],
      ),
    );
  }
}

class _PanelSkeleton extends StatelessWidget {
  const _PanelSkeleton();

  @override
  Widget build(BuildContext context) {
    return MarketSkeletonPulse(
      semanticLabel: 'Adreslerin yükleniyor',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MarketPalette.canvas,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          border: Border.all(color: MarketPalette.line),
        ),
        child: const Row(
          children: [
            MarketSkeleton(width: 44, height: 44, radius: MarketRadius.sm),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarketSkeleton(width: 120, height: 14),
                  SizedBox(height: 8),
                  MarketSkeleton(height: 12),
                  SizedBox(height: 6),
                  MarketSkeleton(width: 160, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: MarketPalette.orangeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: MarketPalette.orangeInk, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Adreslerin yüklenemedi. Bağlantını kontrol edip tekrar dene.',
              style: MarketText.body(
                  color: MarketPalette.orangeInk,
                  size: 13,
                  weight: FontWeight.w600,
                  height: 1.4),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.orangeInk,
              minimumSize: const Size(MarketSize.control, MarketSize.control),
            ),
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Teslimat yeri seçim sayfası
// ---------------------------------------------------------------------------

/// Kayıtlı adresler (kapalı bölgedekiler pasif), yurtlar ve "Yeni adres
/// ekle". Seçim sayfayı kapatır ve çağırana döner; sayfa sonucu uygular.
Future<DeliveryDestinationChoice?> showDeliveryDestinationSheet(
  BuildContext context,
  DeliveryViewModel delivery,
) {
  return showMarketSheet<DeliveryDestinationChoice>(
    context,
    builder: (sheetContext) => _DestinationSheet(delivery: delivery),
  );
}

class _DestinationSheet extends StatelessWidget {
  final DeliveryViewModel delivery;

  const _DestinationSheet({required this.delivery});

  void _pick(BuildContext context, DeliveryDestinationChoice choice) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: delivery,
      builder: (context, _) {
        final addresses = delivery.addresses;
        final dorms = delivery.dormZones;
        final selectedDorm = delivery.selectedDormZoneId;
        final selectedAddress =
            selectedDorm == null ? delivery.selectedAddress?.id : null;
        final canAdd = delivery.canAddAddress;

        final children = <Widget>[];
        if (!delivery.addressesLoaded && delivery.addressesLoading) {
          children.add(const MarketListSkeleton(count: 2));
        } else if (!delivery.addressesLoaded &&
            delivery.addressesError != null) {
          children.add(_LoadError(onRetry: delivery.loadAddresses));
        } else if (addresses.isNotEmpty) {
          children.add(_groupTitle('Kayıtlı adreslerin'));
          for (final address in addresses) {
            final closed = isAddressZoneClosed(delivery, address);
            final zone = delivery.zoneById(address.zoneId);
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DestinationTile(
                icon: deliveryZoneIcon(address.zoneType),
                title: address.title,
                subtitle: address.summary,
                meta: closed
                    ? null
                    : zone != null
                        ? zoneSubtitle(zone)
                        : null,
                badge: address.isDefault ? 'Varsayılan' : null,
                selected: address.id == selectedAddress,
                closedNote: closed ? zoneClosedNote : null,
                onTap: closed
                    ? null
                    : () => _pick(context, PickSavedAddress(address.id)),
              ),
            ));
          }
        }

        if (dorms.isNotEmpty) {
          children.add(_groupTitle('Teslimat noktaları'));
          for (final zone in dorms) {
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DestinationTile(
                icon: Icons.apartment_rounded,
                title: dormDestinationTitle(zone),
                subtitle: null,
                meta: zoneSubtitle(zone),
                selected: zone.id == selectedDorm,
                onTap: () => _pick(context, PickDormZone(zone.id)),
              ),
            ));
          }
        }

        children
          ..add(const SizedBox(height: 4))
          ..add(OutlinedButton.icon(
            onPressed: canAdd ? () => _pick(context, const AddNewAddress()) : null,
            icon: const Icon(Icons.add_location_alt_outlined, size: 20),
            label: const Text('Yeni adres ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size.fromHeight(MarketSize.control),
              side: BorderSide(
                  color: canAdd ? MarketPalette.greenLine : MarketPalette.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MarketRadius.md),
              ),
            ),
          ));
        if (!canAdd) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(addressLimitNote(delivery.maxAddresses),
                style: MarketText.caption(color: MarketPalette.orangeInk)),
          ));
        }
        if (addresses.isNotEmpty) {
          children.add(TextButton(
            onPressed: () => _pick(context, const ManageAddresses()),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size.fromHeight(MarketSize.control),
            ),
            child: const Text('Adreslerimi düzenle'),
          ));
        }

        return MarketSheetScaffold(
          header: const MarketSheetHeader(
            title: 'Teslimat adresi',
            subtitle: 'Siparişin nereye gelsin?',
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
          bodyPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        );
      },
    );
  }

  Widget _groupTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(text.toUpperCase(), style: MarketText.eyebrow()),
      );
}

class _DestinationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? badge;
  final bool selected;
  final String? closedNote;
  final VoidCallback? onTap;

  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.meta,
    this.badge,
    required this.selected,
    this.closedNote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final semantics = [
      title,
      if (subtitle != null) subtitle!,
      if (meta != null) meta!,
      if (closedNote != null) closedNote!,
    ].join(', ');
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .6,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? MarketPalette.greenSoft : MarketPalette.canvas,
              borderRadius: BorderRadius.circular(MarketRadius.md),
              border: Border.all(
                color: selected ? MarketPalette.green : MarketPalette.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                MarketIconTile(
                  icon: icon,
                  size: 42,
                  background: selected ? MarketPalette.green : Colors.white,
                  foreground: selected ? Colors.white : MarketPalette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MarketText.label(size: 14)),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            MarketPill(label: badge!),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.caption(
                                color: MarketPalette.inkSoft)),
                      ],
                      if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(meta!, style: MarketText.caption()),
                      ],
                      if (closedNote != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          closedNote!,
                          style: MarketText.caption(
                              color: MarketPalette.red,
                              weight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : enabled
                          ? Icons.radio_button_unchecked_rounded
                          : Icons.block_rounded,
                  color: selected ? MarketPalette.green : MarketPalette.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
