import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/delivery.dart';
import '../services/api_service.dart';
import '../viewmodels/delivery_viewmodel.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/delivery_ui.dart';
import 'widgets/market_ui.dart';

/// Adreslerim: kayıtlı teslimat adresleri (en fazla [DeliveryViewModel.maxAddresses]).
/// Adres ekleme, düzenleme, silme ve varsayılan yapma buradan yapılır.
/// Adrese teslimat kapanırsa liste yerine bilgi gösterilir.
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  /// İşlem süren adres (silme / varsayılan yapma); bu sırada diğer
  /// eylemler pasif kalır.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delivery = context.read<DeliveryViewModel>();
      unawaited(delivery.loadZones());
      unawaited(delivery.loadAddresses());
    });
  }

  Future<void> _refresh() async {
    final delivery = context.read<DeliveryViewModel>();
    await Future.wait([
      delivery.refreshAccess(),
      delivery.loadAddresses(),
      delivery.loadZones(force: true),
    ]);
  }

  /// Bölge sonradan kapandıysa adres listede kalır ama sipariş verilemez.
  bool _isClosed(DeliveryViewModel delivery, DeliveryAddress address) {
    if (!address.zoneEnabled) return true;
    return delivery.zonesLoaded && delivery.zoneById(address.zoneId) == null;
  }

  Future<void> _add() async {
    final saved = await context.push<DeliveryAddress>('/addresses/new');
    if (saved != null && mounted) {
      showMarketSnack(context, 'Adresin kaydedildi',
          icon: Icons.where_to_vote_rounded);
    }
  }

  Future<void> _edit(DeliveryAddress address) async {
    final saved =
        await context.push<DeliveryAddress>('/addresses/edit', extra: address);
    if (saved != null && mounted) {
      showMarketSnack(context, 'Adresin güncellendi',
          icon: Icons.where_to_vote_rounded);
    }
  }

  Future<void> _delete(DeliveryAddress address) async {
    if (_busyId != null) return;
    final delivery = context.read<DeliveryViewModel>();
    final others = delivery.addresses.length > 1;
    final confirmed = await showMarketConfirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Adres silinsin mi?',
      message: address.isDefault && others
          ? '“${address.title}” kayıtlı adreslerinden kaldırılacak. Varsayılan adresin diğer adreslerinden biri olacak.'
          : '“${address.title}” kayıtlı adreslerinden kaldırılacak. Verdiğin siparişler etkilenmez.',
      confirmLabel: 'Sil',
      tone: MarketTone.danger,
    );
    if (!confirmed || !mounted) return;
    await _run(address.id, () => delivery.deleteAddress(address.id),
        success: 'Adres silindi', fallback: 'Adres silinemedi. Tekrar dene.');
  }

  Future<void> _makeDefault(DeliveryAddress address) async {
    if (_busyId != null) return;
    final delivery = context.read<DeliveryViewModel>();
    await _run(address.id, () => delivery.setDefaultAddress(address.id),
        success: '“${address.title}” varsayılan adresin oldu',
        fallback: 'Varsayılan adres değiştirilemedi. Tekrar dene.');
  }

  Future<void> _run(
    String id,
    Future<void> Function() task, {
    required String success,
    required String fallback,
  }) async {
    setState(() => _busyId = id);
    String? error;
    try {
      await task();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = fallback;
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    if (error != null) {
      showMarketSnack(context, error, error: true);
    } else {
      showMarketSnack(context, success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryViewModel>();
    final available = delivery.canOrderToAddress;
    final addresses = delivery.addresses;
    final loaded = delivery.addressesLoaded;
    final showList = available && loaded && addresses.isNotEmpty;

    final String subtitle;
    if (!available) {
      subtitle = 'Teslimat adreslerin';
    } else if (!loaded) {
      subtitle = 'Adreslerin yükleniyor';
    } else if (addresses.isEmpty) {
      subtitle = 'Adresini bir kez kaydet, siparişte hızlıca seç';
    } else {
      subtitle = '${addresses.length}/${delivery.maxAddresses} adres kayıtlı';
    }

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: MarketScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: MarketHeader(
                title: 'Adreslerim',
                subtitle: subtitle,
                icon: Icons.location_on_rounded,
                compact: true,
              ),
            ),
            ..._buildBody(delivery),
          ],
        ),
      ),
      bottomNavigationBar: showList ? _buildAddBar(delivery) : null,
    );
  }

  List<Widget> _buildBody(DeliveryViewModel delivery) {
    if (!delivery.canOrderToAddress) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MarketEmptyState(
            icon: Icons.local_shipping_outlined,
            tint: MarketPalette.blue,
            tintSoft: MarketPalette.blueSoft,
            title: 'Adrese teslimat şu an kapalı',
            message:
                'Şu an adresine teslimat yapamıyoruz. Siparişini teslimat noktalarımızdan birine verebilirsin; adrese teslimat açılınca adreslerin burada olacak.',
            actionLabel: 'Alışverişe dön',
            actionIcon: Icons.storefront_rounded,
            onAction: () => context.go('/home'),
          ),
        ),
      ];
    }

    if (!delivery.addressesLoaded) {
      if (delivery.addressesError != null && !delivery.addressesLoading) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: MarketEmptyState.error(
              title: 'Adreslerin yüklenemedi',
              message: delivery.addressesError!,
              onRetry: () => delivery.loadAddresses(),
            ),
          ),
        ];
      }
      return const [
        SliverToBoxAdapter(child: _AddressListSkeleton()),
      ];
    }

    final addresses = delivery.addresses;
    if (addresses.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MarketEmptyState(
            icon: Icons.add_location_alt_outlined,
            title: 'Henüz kayıtlı adresin yok',
            message:
                'Evini, işini ya da sık sipariş verdiğin yeri kaydet; siparişte tek dokunuşla seç.',
            actionLabel: 'Adres ekle',
            actionIcon: Icons.add_rounded,
            onAction: _add,
          ),
        ),
      ];
    }

    final gutter = MarketSpace.gutterOf(context);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 24),
        sliver: SliverList.list(
          children: [
            if (delivery.addressesError != null) ...[
              MarketNotice.warning(
                icon: Icons.sync_problem_rounded,
                text:
                    'Adreslerin yenilenemedi; son kaydedilen hâli görüyorsun.',
                trailing: TextButton(
                  onPressed: delivery.addressesLoading
                      ? null
                      : () => delivery.loadAddresses(),
                  child: const Text('Yenile'),
                ),
              ),
              const SizedBox(height: 14),
            ],
            for (var i = 0; i < addresses.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _AddressCard(
                address: addresses[i],
                closed: _isClosed(delivery, addresses[i]),
                busy: _busyId == addresses[i].id,
                actionsEnabled: _busyId == null,
                onEdit: () => _edit(addresses[i]),
                onDelete: () => _delete(addresses[i]),
                onMakeDefault: () => _makeDefault(addresses[i]),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildAddBar(DeliveryViewModel delivery) {
    final canAdd = delivery.canAddAddress;
    return MarketBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canAdd) ...[
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: MarketPalette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En fazla ${delivery.maxAddresses} adres kaydedebilirsin; yenisini eklemek için birini sil.',
                    style: MarketText.caption(size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: canAdd && _busyId == null ? _add : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(MarketSize.button),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            label: const Text('Adres ekle'),
          ),
        ],
      ),
    );
  }
}

/// Tek adres kartı: başlık, bölge, adres özeti, tarif ve eylemler.
class _AddressCard extends StatelessWidget {
  final DeliveryAddress address;
  final bool closed;
  final bool busy;
  final bool actionsEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  const _AddressCard({
    required this.address,
    required this.closed,
    required this.busy,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  IconData get _icon {
    final label = address.label.trim().toLowerCase();
    if (label == 'ev') return Icons.home_rounded;
    if (label == 'iş') return Icons.work_rounded;
    return switch (address.zoneType) {
      DeliveryZoneType.yurt => Icons.apartment_rounded,
      DeliveryZoneType.koy => Icons.cottage_rounded,
      DeliveryZoneType.mahalle => Icons.location_on_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fields = address.fields;
    final summary = fields.summary;
    final directions = fields.directions.trim();
    // Etiket yoksa başlık zaten bölge adıdır; alt satırda tekrarlanmaz.
    final showZoneLine = address.label.trim().isNotEmpty;

    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketIconTile(
          icon: _icon,
          background: closed ? MarketPalette.fill : MarketPalette.greenSoft,
          foreground: closed ? MarketPalette.muted : MarketPalette.greenDark,
        ),
        const SizedBox(width: MarketSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(address.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.heading()),
                  if (address.isDefault)
                    const MarketPill(
                      label: 'Varsayılan',
                      icon: Icons.star_rounded,
                    ),
                ],
              ),
              if (showZoneLine) ...[
                const SizedBox(height: 3),
                Text(address.zoneName,
                    style: MarketText.label(
                        color: MarketPalette.inkSoft, size: 13)),
              ],
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(summary, style: MarketText.body(size: 13)),
              ],
              if (directions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  directions,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(size: 12),
                ),
              ],
              if (fields.location != null) ...[
                const SizedBox(height: 8),
                const MarketPill(
                  label: 'Konum ekli',
                  icon: Icons.my_location_rounded,
                  background: MarketPalette.blueSoft,
                  foreground: MarketPalette.blue,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return MarketCard(
      onTap: actionsEnabled ? onEdit : null,
      color: closed ? MarketPalette.surfaceMuted : MarketPalette.surface,
      shadow: !closed,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: closed ? Opacity(opacity: .55, child: details) : details,
          ),
          if (closed) ...[
            const SizedBox(height: MarketSpace.md),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: MarketNotice.warning(
                icon: Icons.block_rounded,
                text: '$zoneClosedNote Siparişte bu adresi seçemezsin.',
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dar ekranda / büyük yazıda eylemler alt satıra iner.
              Expanded(
                child: Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: actionsEnabled ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Düzenle'),
                      style: TextButton.styleFrom(
                        foregroundColor: MarketPalette.greenDark,
                        minimumSize: const Size(0, MarketSize.control),
                      ),
                    ),
                    if (!address.isDefault && !closed)
                      TextButton.icon(
                        onPressed: actionsEnabled ? onMakeDefault : null,
                        icon: const Icon(Icons.star_outline_rounded, size: 18),
                        label: const Text('Varsayılan yap'),
                        style: TextButton.styleFrom(
                          foregroundColor: MarketPalette.greenDark,
                          minimumSize: const Size(0, MarketSize.control),
                        ),
                      ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: MarketPalette.green),
                  ),
                )
              else
                IconButton(
                  onPressed: actionsEnabled ? onDelete : null,
                  tooltip: 'Adresi sil',
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: MarketPalette.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressListSkeleton extends StatelessWidget {
  const _AddressListSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    return MarketListSkeleton(
      count: 3,
      padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 24),
    );
  }
}
