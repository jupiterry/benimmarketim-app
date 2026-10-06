import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/market_ui.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

enum _Filter { all, active, delivered, cancelled }

const _activeStatuses = {'Hazırlanıyor', 'Yolda'};

class _OrdersPageState extends State<OrdersPage> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      final orders = await apiService.getUserOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      final apiService = ApiService();
      final success = await apiService.cancelOrder(orderId);
      if (!mounted) return;
      if (success) {
        showMarketSnack(context, 'Sipariş iptal edildi');
        _loadOrders(); // Listeyi yenile
      } else {
        showMarketSnack(context, 'Sipariş iptal edilemedi', error: true);
      }
    } catch (e) {
      AppLogger.debug('Sipariş iptal hatası: $e');
      if (mounted) {
        showMarketSnack(context, 'Sipariş iptal edilemedi. Lütfen tekrar dene.', error: true);
      }
    }
  }

  /// Siparişteki ürünlerin güncel halini (fiyat, stok) sunucudan alıp sepete
  /// ekler. Stokta olmayan ya da artık satılmayan ürünler atlanır.
  Future<void> _reorder(Order order) async {
    final cart = context.read<CartViewModel>();
    final api = ApiService();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    var added = 0;
    var skipped = 0;
    for (final item in order.products) {
      final product = await _currentProduct(api, item);
      if (product == null || product.isOutOfStock || product.isHidden) {
        skipped++;
        continue;
      }
      for (var i = 0; i < item.quantity; i++) {
        cart.addToCart(product);
      }
      added++;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Loading kapat

    if (added == 0) {
      showMarketSnack(
        context,
        'Bu siparişteki ürünler şu an satışta değil.',
        error: true,
      );
      return;
    }
    showMarketSnack(
      context,
      skipped == 0
          ? '$added ürün sepete eklendi'
          : '$added ürün sepete eklendi, $skipped ürün stokta yok',
    );
    context.go('/home', extra: <String, dynamic>{'initialTabIndex': 1});
  }

  Future<Product?> _currentProduct(ApiService api, OrderProduct item) async {
    try {
      final id = item.productId;
      if (id != null) return await api.getProductById(id);

      // Eski kayıtlarda ürün ID'si yoksa yalnızca adı birebir eşleşen ürün
      // kabul edilir; benzer adlı farklı bir ürün sepete girmez.
      final result = await api.searchProducts(query: item.name);
      final wanted = item.name.trim().toLowerCase();
      for (final product in result.products) {
        if (product.name.trim().toLowerCase() == wanted) return product;
      }
      return null;
    } catch (e) {
      AppLogger.debug('Tekrar sipariş: ürün alınamadı (${item.name}): $e');
      return null;
    }
  }

  Future<void> _startOrderSupport(Order order) async {
    // Sipariş saatleri kontrolü
    final settingsViewModel = context.read<SettingsViewModel>();
    if (!settingsViewModel.isWithinOrderHours) {
      showMarketSnack(
        context,
        'Canlı destek sipariş saatlerinde aktif. ${settingsViewModel.orderHoursMessage}',
        icon: Icons.schedule_rounded,
        error: true,
      );
      return;
    }

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatViewModel = context.read<ChatViewModel>();
      final chat = await chatViewModel.startChat(orderId: order.id);

      if (mounted) {
        Navigator.of(context).pop(); // Loading kapat
      }

      if (chat != null && mounted) {
        // Sipariş bilgisi içeren otomatik mesaj gönder
        final orderMessage =
            '📦 Sipariş #${order.id.substring(0, 8)} hakkında destek istiyorum.\n'
            '📅 Tarih: ${_formatDate(order.createdAt)}\n'
            '💰 Tutar: ${formatTl(order.totalAmount)}\n'
            '📊 Durum: ${order.status}';

        await chatViewModel.sendMessage(orderMessage);

        // Chat sayfasına git
        if (!mounted) return;
        context.push('/chat/${chat.id}');
      } else if (mounted) {
        showMarketSnack(context, 'Destek başlatılamadı', error: true);
      }
    } catch (e) {
      AppLogger.debug('Destek başlatma hatası: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Loading kapat
        showMarketSnack(context, 'Destek başlatılamadı. Lütfen tekrar dene.', error: true);
      }
    }
  }

  bool _matches(Order order) => switch (_filter) {
        _Filter.all => true,
        _Filter.active => _activeStatuses.contains(order.status),
        _Filter.delivered => order.status == 'Teslim Edildi',
        _Filter.cancelled => order.status == 'İptal Edildi',
      };

  int _count(_Filter filter) => switch (filter) {
        _Filter.all => _orders.length,
        _Filter.active => _orders.where((o) => _activeStatuses.contains(o.status)).length,
        _Filter.delivered => _orders.where((o) => o.status == 'Teslim Edildi').length,
        _Filter.cancelled => _orders.where((o) => o.status == 'İptal Edildi').length,
      };

  @override
  Widget build(BuildContext context) {
    final visible = _orders.where(_matches).toList();
    final activeCount = _count(_Filter.active);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: MarketHeader(
                title: 'Siparişlerim',
                subtitle: _isLoading
                    ? 'Siparişlerin yükleniyor'
                    : activeCount > 0
                        ? '$activeCount aktif siparişin var'
                        : 'Tüm siparişlerin tek yerde',
                icon: Icons.receipt_long_rounded,
                compact: true,
                actions: [
                  MarketHeaderButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Yenile',
                    onTap: _loadOrders,
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(child: MarketListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MarketEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Siparişler yüklenemedi',
                  message: _error!.contains('Oturum')
                      ? 'Oturumunun süresi dolmuş. Lütfen tekrar giriş yap.'
                      : 'Bağlantını kontrol edip yeniden deneyebilirsin.',
                  actionLabel: 'Tekrar dene',
                  actionIcon: Icons.refresh_rounded,
                  onAction: _loadOrders,
                  tint: MarketPalette.red,
                  tintSoft: MarketPalette.redSoft,
                ),
              )
            else if (_orders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MarketEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Henüz siparişin yok',
                  message: 'İlk siparişini verdiğinde tüm süreci buradan takip edebilirsin.',
                  actionLabel: 'Ürünleri keşfet',
                  actionIcon: Icons.explore_rounded,
                  onAction: () => context.go('/home'),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _buildFilters()),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MarketEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Bu filtrede sipariş yok',
                    message: 'Başka bir filtre seçerek diğer siparişlerine bakabilirsin.',
                    actionLabel: 'Tümünü göster',
                    actionIcon: Icons.list_alt_rounded,
                    onAction: () => setState(() => _filter = _Filter.all),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, index) => _buildOrderCard(visible[index]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const labels = {
      _Filter.all: 'Tümü',
      _Filter.active: 'Aktif',
      _Filter.delivered: 'Teslim edildi',
      _Filter.cancelled: 'İptal',
    };
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        children: [
          for (final entry in labels.entries) ...[
            ChoiceChip(
              label: Text('${entry.value} (${_count(entry.key)})'),
              selected: _filter == entry.key,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final style = _statusStyle(order.status);
    final expanded = _expanded.contains(order.id);
    final products = expanded ? order.products : order.products.take(3).toList();
    final hidden = order.products.length - products.length;
    final itemCount = order.products.fold<int>(0, (s, p) => s + p.quantity);

    return MarketCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() {
        expanded ? _expanded.remove(order.id) : _expanded.add(order.id);
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                MarketIconTile(
                  icon: style.icon,
                  size: 44,
                  background: style.background,
                  foreground: style.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sipariş #${_shortId(order.id)}', style: MarketText.heading(size: 16)),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(order.createdAt)} • $itemCount ürün',
                        style: MarketText.caption(),
                      ),
                    ],
                  ),
                ),
                MarketPill(label: order.status, background: style.background, foreground: style.color),
              ],
            ),
          ),
          if (order.status != 'İptal Edildi')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _StatusSteps(status: order.status),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: MarketNotice(
                icon: Icons.info_outline_rounded,
                text: 'Bu sipariş iptal edildi.',
                background: MarketPalette.redSoft,
                foreground: MarketPalette.red,
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                for (final product in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        _productImage(product.image),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MarketText.label(size: 13, weight: FontWeight.w600),
                              ),
                              Text('${product.quantity} adet × ${formatTl(product.price)}',
                                  style: MarketText.caption()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTl(product.price * product.quantity),
                          style: MarketText.label(size: 13),
                        ),
                      ],
                    ),
                  ),
                if (hidden > 0 || expanded)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expanded ? 'Daha az göster' : '+$hidden ürün daha',
                            style: MarketText.label(color: MarketPalette.green, size: 13),
                          ),
                          Icon(
                            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: MarketPalette.green,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (expanded) ...[
                  if (order.deliveryPointName.isNotEmpty)
                    _detailRow(Icons.location_on_outlined, 'Teslimat', order.deliveryPointName),
                  if (order.note.trim().isNotEmpty)
                    _detailRow(Icons.sticky_note_2_outlined, 'Not', order.note.trim()),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
            decoration: const BoxDecoration(
              color: MarketPalette.canvas,
              border: Border(top: BorderSide(color: MarketPalette.line)),
            ),
            child: Row(
              children: [
                _action(Icons.support_agent_rounded, 'Destek', MarketPalette.blue,
                    MarketPalette.blueSoft, () => _startOrderSupport(order)),
                if (order.status == 'Hazırlanıyor') ...[
                  const SizedBox(width: 8),
                  _action(Icons.close_rounded, 'İptal et', MarketPalette.red,
                      MarketPalette.redSoft, () => _showCancelDialog(order.id)),
                ],
                if (order.status == 'Teslim Edildi' ||
                    order.status == 'İptal Edildi') ...[
                  const SizedBox(width: 8),
                  _action(Icons.replay_rounded, 'Tekrarla', MarketPalette.greenDark,
                      MarketPalette.greenSoft, () => _reorder(order)),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Toplam', style: MarketText.caption()),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatTl(order.totalAmount),
                            style: MarketText.price(color: MarketPalette.greenDark, size: 18)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MarketPalette.muted),
          const SizedBox(width: 8),
          Text('$label: ', style: MarketText.caption(weight: FontWeight.w700)),
          Expanded(child: Text(value, style: MarketText.caption(color: MarketPalette.ink))),
        ],
      ),
    );
  }

  Widget _productImage(String? image) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MarketPalette.canvas,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
      ),
      child: image == null || image.isEmpty
          ? const Icon(Icons.shopping_bag_outlined, color: MarketPalette.subtle, size: 19)
          : Image.network(
              image,
              fit: BoxFit.contain,
              cacheWidth: 120,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shopping_bag_outlined,
                color: MarketPalette.subtle,
                size: 19,
              ),
            ),
    );
  }

  Widget _action(IconData icon, String label, Color color, Color background, VoidCallback onTap) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(MarketRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(label, style: MarketText.label(color: color, size: 13)),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color color, Color background}) _statusStyle(String status) {
    return switch (status) {
      'Hazırlanıyor' => (
          icon: Icons.soup_kitchen_outlined,
          color: MarketPalette.orangeInk,
          background: MarketPalette.orangeSoft,
        ),
      'Yolda' => (
          icon: Icons.delivery_dining_rounded,
          color: MarketPalette.blue,
          background: MarketPalette.blueSoft,
        ),
      'Teslim Edildi' => (
          icon: Icons.check_circle_rounded,
          color: MarketPalette.greenDark,
          background: MarketPalette.greenSoft,
        ),
      'İptal Edildi' => (
          icon: Icons.cancel_outlined,
          color: MarketPalette.red,
          background: MarketPalette.redSoft,
        ),
      _ => (
          icon: Icons.receipt_long_outlined,
          color: MarketPalette.muted,
          background: MarketPalette.surfaceMuted,
        ),
    };
  }

  String _shortId(String id) {
    if (id.isEmpty) return '—';
    return id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();
  }

  Future<void> _showCancelDialog(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.cancel_outlined,
          size: 52,
          background: MarketPalette.redSoft,
          foreground: MarketPalette.red,
        ),
        title: const Text('Sipariş iptal edilsin mi?', textAlign: TextAlign.center),
        content: const Text(
          'Siparişin iptal edilecek. Bu işlem geri alınamaz.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MarketPalette.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed == true) _cancelOrder(orderId);
  }

  String _formatDate(DateTime date) {
    final turkeyDate = date.toUtc().add(const Duration(hours: 3));
    return '${turkeyDate.day.toString().padLeft(2, '0')}.${turkeyDate.month.toString().padLeft(2, '0')}.${turkeyDate.year} ${turkeyDate.hour.toString().padLeft(2, '0')}:${turkeyDate.minute.toString().padLeft(2, '0')}';
  }
}

/// Alındı → Hazırlanıyor → Yolda → Teslim edildi
class _StatusSteps extends StatelessWidget {
  final String status;

  const _StatusSteps({required this.status});

  static const _steps = ['Alındı', 'Hazırlanıyor', 'Yolda', 'Teslim'];

  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      'Hazırlanıyor' => 1,
      'Yolda' => 2,
      'Teslim Edildi' => 3,
      _ => 0,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : i <= current
                                ? MarketPalette.green
                                : MarketPalette.line,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: i <= current ? MarketPalette.green : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i <= current ? MarketPalette.green : MarketPalette.lineStrong,
                          width: 2,
                        ),
                      ),
                      child: i < current || (i == current && current == 3)
                          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                          : i == current
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _steps.length - 1
                            ? Colors.transparent
                            : i < current
                                ? MarketPalette.green
                                : MarketPalette.line,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i],
                  textAlign: TextAlign.center,
                  style: MarketText.caption(
                    color: i <= current ? MarketPalette.ink : MarketPalette.subtle,
                    size: 12,
                    weight: i == current ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
