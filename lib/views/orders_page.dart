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
import 'widgets/bill_split_sheet.dart';
import 'widgets/feedback_parts.dart';
import 'widgets/market_ui.dart';
import '../services/image_url.dart';

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

  Future<void> _cancelOrder(String orderId, {String? reason, String? note}) async {
    try {
      final apiService = ApiService();
      final success = await apiService.cancelOrder(orderId, reason: reason, note: note);
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
    final total = order.products.length;
    final progress = ValueNotifier<String>('Ürünler sepete ekleniyor… (0/$total)');

    var added = 0;
    final skipped = <String>[];
    try {
      await runWithMarketProgress<void>(
        context,
        message: progress.value,
        liveMessage: progress,
        task: () async {
          for (var i = 0; i < total; i++) {
            final item = order.products[i];
            progress.value = 'Ürünler sepete ekleniyor… (${i + 1}/$total)';
            final product = await _currentProduct(api, item);
            if (product == null || product.isOutOfStock || product.isHidden) {
              skipped.add(item.name);
              continue;
            }
            // Adet tek seferde yazılır; tek tek eklemek yerel kayıtta adedi 1 bırakıyordu
            cart.addQuantity(product, item.quantity);
            added++;
          }
        },
      );
    } finally {
      // Bekleme kartının kapanış animasyonu bitince bırakılır
      Future<void>.delayed(const Duration(milliseconds: 400), progress.dispose);
    }

    if (!mounted) return;
    if (added == 0) {
      showMarketSnack(
        context,
        'Bu siparişteki ürünler şu an satışta değil.',
        error: true,
      );
      return;
    }
    final String message;
    if (skipped.isEmpty) {
      message = '$added ürün sepete eklendi';
    } else if (skipped.length <= 2) {
      // Az sayıda ürün eksikse adıyla söylenir
      final names = skipped.map(productDisplayName).join(' ve ');
      message = '$added ürün sepete eklendi • $names şu an stokta yok';
    } else {
      message = '$added ürün sepete eklendi, ${skipped.length} ürün stokta yok';
    }
    showMarketSnack(context, message);
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
      String hhmm(int h, int m) =>
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      final hours =
          '${hhmm(settingsViewModel.orderStartHour, settingsViewModel.orderStartMinute)} – '
          '${hhmm(settingsViewModel.orderEndHour, settingsViewModel.orderEndMinute)}';
      showMarketSnack(
        context,
        'Canlı destek $hours arasında açık. O saatlerde tekrar dene.',
        icon: Icons.schedule_rounded,
        error: true,
      );
      return;
    }

    final chatViewModel = context.read<ChatViewModel>();
    try {
      final chat = await runWithMarketProgress(
        context,
        message: 'Destek görüşmesi açılıyor…',
        task: () async {
          final chat = await chatViewModel.startChat(orderId: order.id);
          if (chat != null) {
            // Sipariş bilgisi içeren otomatik mesaj gönder
            final orderMessage =
                '📦 Sipariş #${order.id.substring(0, 8)} hakkında destek istiyorum.\n'
                '📅 Tarih: ${_formatDate(order.createdAt)}\n'
                '💰 Tutar: ${formatTl(order.totalAmount)}\n'
                '📊 Durum: ${order.status}';
            await chatViewModel.sendMessage(orderMessage);
          }
          return chat;
        },
      );

      if (!mounted) return;
      if (chat != null) {
        // Chat sayfasına git
        context.push('/chat/${chat.id}');
      } else {
        showMarketSnack(context, 'Destek başlatılamadı. Tekrar dene.', error: true);
      }
    } catch (e) {
      AppLogger.debug('Destek başlatma hatası: $e');
      if (mounted) {
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
    final gutter = MarketSpace.gutterOf(context);
    final sessionExpired = _error?.contains('Oturum') ?? false;

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: MarketScrollPhysics()),
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
                child: sessionExpired
                    ? MarketEmptyState(
                        icon: Icons.lock_clock_outlined,
                        title: 'Oturumunun süresi doldu',
                        message: 'Siparişlerini görmek için tekrar giriş yap.',
                        actionLabel: 'Giriş yap',
                        actionIcon: Icons.login_rounded,
                        onAction: () async {
                          await context.push('/login');
                          if (mounted) _loadOrders();
                        },
                      )
                    : MarketEmptyState.error(
                        title: 'Siparişler yüklenemedi',
                        onRetry: _loadOrders,
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
              SliverToBoxAdapter(child: _buildFilters(gutter)),
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
                  padding: EdgeInsets.fromLTRB(
                      gutter, 6, gutter, 32 + MediaQuery.paddingOf(context).bottom),
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

  Widget _buildFilters(double gutter) {
    const labels = {
      _Filter.all: 'Tümü',
      _Filter.active: 'Aktif',
      _Filter.delivered: 'Teslim edildi',
      _Filter.cancelled: 'İptal',
    };
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
        children: [
          for (final entry in labels.entries) ...[
            MarketChip(
              label: '${entry.value} (${_count(entry.key)})',
              selected: _filter == entry.key,
              onTap: () => setState(() => _filter = entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final style = _statusStyle(order.status);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final pad = narrow ? 12.0 : 16.0;
    final expanded = _expanded.contains(order.id);
    final active = _isActive(order.status);
    final cancelled = order.status == 'İptal Edildi';
    final delivered = order.status == 'Teslim Edildi';
    final products = expanded ? order.products : order.products.take(3).toList();
    final hidden = order.products.length - products.length;
    final lineCount = order.products.length;
    final compact = narrow || MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final title = Text(
      'Sipariş #${_shortId(order.id)}',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: MarketText.heading(size: 16),
    );
    // Ürün sayısı satır sayısıdır ("+1 ürün" ile tutarlı); adetler satırlarda
    final meta = Text(
      '${formatTrDateTime(order.createdAt)} • $lineCount ürün',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MarketText.caption(),
    );
    final pill = MarketPill(
      label: _statusLabel(order.status),
      background: style.background,
      foreground: style.color,
    );
    final details = <(String, String)>[
      if (order.deliveryPointName.isNotEmpty) ('Teslimat', order.deliveryPointName),
      if (order.paymentMethod != null) ('Ödeme', order.paymentMethod!.label),
      if (order.note.trim().isNotEmpty) ('Not', order.note.trim()),
    ];
    final canToggle = order.products.length > 3 || details.isNotEmpty;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    void toggle() => setState(() {
          expanded ? _expanded.remove(order.id) : _expanded.add(order.id);
        });

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 14),
          child: compact
              // Dar ekranda / büyük yazıda: simge yok, durum hapı tarihle aynı satırda
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        pill,
                        const SizedBox(width: 8),
                        Expanded(child: meta),
                      ],
                    ),
                  ],
                )
              : Row(
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
                        children: [title, const SizedBox(height: 2), meta],
                      ),
                    ),
                    const SizedBox(width: 8),
                    pill,
                  ],
                ),
        ),
        // Teslim edilen ve iptal edilen siparişlerde adımlar gösterilmez
        if (active)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
            child: _StatusSteps(status: order.status),
          ),
        const Divider(height: 1),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 14, pad, canToggle ? 0 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                productDisplayName(product.name),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: MarketText.label(size: 13, weight: FontWeight.w600),
                              ),
                              const SizedBox(height: 1),
                              Text('${product.quantity} adet × ${formatTl(product.price)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MarketText.caption()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTl(product.price * product.quantity),
                          maxLines: 1,
                          softWrap: false,
                          style: MarketText.label(size: 13),
                        ),
                      ],
                    ),
                  ),
                if (expanded && details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                    decoration: BoxDecoration(
                      color: MarketPalette.surfaceMuted,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                    child: Column(
                      children: [
                        for (final (label, value) in details) _detailRow(label, value),
                      ],
                    ),
                  ),
                ],
                if (canToggle)
                  Semantics(
                    button: true,
                    expanded: expanded,
                    child: InkWell(
                      onTap: toggle,
                      borderRadius: BorderRadius.circular(MarketRadius.xs),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: MarketSize.control),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                expanded
                                    ? 'Detayları gizle'
                                    : hidden > 0
                                        ? '+$hidden ürün ve sipariş detayları'
                                        : 'Sipariş detayları',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MarketText.label(color: MarketPalette.green, size: 13),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: MarketPalette.green,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 14),
          decoration: const BoxDecoration(
            color: MarketPalette.canvas,
            border: Border(top: BorderSide(color: MarketPalette.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (order.hasDiscount) ...[
                _sumRow('Ara toplam', formatTl(order.subtotalOrDerived)),
                _sumRow(
                  order.couponCode == null ? 'Kupon indirimi' : 'Kupon ${order.couponCode}',
                  '−${formatTl(order.couponDiscount)}',
                  valueColor: MarketPalette.green,
                ),
                const SizedBox(height: 2),
              ],
              Row(
                children: [
                  Text('Toplam', style: MarketText.label(size: 13, color: MarketPalette.muted)),
                  const Spacer(),
                  Text(
                    formatTl(order.totalAmount),
                    style: MarketText.price(color: MarketPalette.greenDark, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _action(Icons.support_agent_rounded, 'Destek', MarketPalette.blue,
                      MarketPalette.blueSoft, () => _startOrderSupport(order)),
                  if (order.status == 'Hazırlanıyor')
                    _action(Icons.close_rounded, 'İptal et', MarketPalette.red,
                        MarketPalette.redSoft, () => _showCancelDialog(order.id)),
                  if (delivered || cancelled)
                    _action(Icons.replay_rounded, 'Tekrar sipariş ver', MarketPalette.greenDark,
                        MarketPalette.greenSoft, () => _reorder(order)),
                  if (!cancelled)
                    _action(Icons.call_split_rounded, 'Hesabı böl', MarketPalette.green,
                        MarketPalette.greenSoft,
                        () => showBillSplitSheet(context, total: order.totalAmount)),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return MarketCard(
      padding: EdgeInsets.zero,
      borderColor: active ? MarketPalette.greenLine : MarketPalette.line,
      child: active
          ? Stack(
              children: [
                content,
                // Süren siparişin solunda ince yeşil vurgu
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: MarketPalette.green),
                ),
              ],
            )
          : content,
    );
  }

  Widget _sumRow(String label, String value, {Color valueColor = MarketPalette.inkSoft}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MarketText.caption(),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: MarketText.caption(color: valueColor, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: MarketText.caption()),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MarketText.label(size: 13, weight: FontWeight.w600),
            ),
          ),
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
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        border: Border.all(color: MarketPalette.line),
      ),
      child: image == null || image.isEmpty
          ? const Icon(Icons.shopping_bag_outlined, color: MarketPalette.subtle, size: 19)
          : Image.network(
              optimizedImageUrl(image, width: MarketImageSize.thumb),
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
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MarketRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MarketSize.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.label(color: color, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isActive(String status) =>
      status != 'Teslim Edildi' && status != 'İptal Edildi';

  /// Hapta gösterilen etiket (cümle düzeni); karşılaştırmalar ham durumla yapılır.
  static String _statusLabel(String status) => switch (status) {
        'Teslim Edildi' => 'Teslim edildi',
        'İptal Edildi' => 'İptal edildi',
        _ => status,
      };

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

  /// İptal onayı: müşteri nedenini seçmek zorunda (fiyat, teslimat süresi, ...).
  /// Neden yönetici panelinde sipariş detayında ve memnuniyet raporunda görünür.
  Future<void> _showCancelDialog(String orderId) async {
    final result = await showMarketSheet<({String reason, String note})>(
      context,
      builder: (_) => const _CancelReasonSheet(),
    );
    if (result != null) _cancelOrder(orderId, reason: result.reason, note: result.note);
  }

  /// Destek mesajındaki tarih (yönetici paneline giden metin; biçimi korunur).
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

    return Semantics(
      label: 'Sipariş durumu: ${_steps[current]}, 4 adımdan ${current + 1}.',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _steps.length; i++)
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
                    // Dar sütunda kelime bölünmez; gerekirse yazı biraz küçülür
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _steps[i],
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: MarketText.caption(
                            color: i <= current ? MarketPalette.ink : MarketPalette.subtle,
                            size: 12,
                            weight: i == current ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  // Sunucudaki CANCEL_REASONS ile aynı kimlikler (backend/lib/feedbackOptions.js)
  static const _reasons = [
    FeedbackOption('gec', 'Teslimat çok uzun sürecek'),
    FeedbackOption('fikir', 'Fikrimi değiştirdim'),
    FeedbackOption('yanlis_siparis', 'Yanlış/eksik sipariş verdim'),
    FeedbackOption('fiyat', 'Fiyat yüksek geldi'),
    FeedbackOption('baska_yer', 'Başka yerden aldım'),
    FeedbackOption('diger', 'Diğer'),
  ];

  final TextEditingController _note = TextEditingController();
  String? _reason;
  bool _missing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarketSheetScaffold(
      header: const MarketSheetHeader(
        title: 'Sipariş iptal edilsin mi?',
        subtitle: 'Bu işlem geri alınamaz. Neden vazgeçtiğini seçer misin?',
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MarketSpace.sm,
            children: [
              for (final reason in _reasons)
                MarketChip(
                  label: reason.label,
                  tone: MarketChipTone.danger,
                  selected: _reason == reason.id,
                  onTap: () => setState(() {
                    _reason = reason.id;
                    _missing = false;
                  }),
                ),
            ],
          ),
          if (_reason == 'diger') ...[
            const SizedBox(height: MarketSpace.md),
            TextField(
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Kısaca yazar mısın? (isteğe bağlı)',
                counterText: '',
              ),
            ),
          ],
          if (_missing) ...[
            const SizedBox(height: MarketSpace.sm),
            Semantics(
              liveRegion: true,
              child: Text('Lütfen bir neden seç.', style: MarketText.label(color: MarketPalette.red)),
            ),
          ],
        ],
      ),
      footer: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MarketPalette.red,
          minimumSize: const Size.fromHeight(MarketSize.button),
        ),
        onPressed: () {
          if (_reason == null) {
            setState(() => _missing = true);
            return;
          }
          Navigator.of(context).pop((reason: _reason!, note: _note.text.trim()));
        },
        child: const Text('Siparişi iptal et'),
      ),
    );
  }
}
