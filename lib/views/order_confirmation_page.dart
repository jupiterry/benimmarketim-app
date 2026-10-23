import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../viewmodels/delivery_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/bank_transfer_card.dart';
import 'widgets/first_order_rating.dart';
import 'widgets/market_ui.dart';
import 'widgets/order_delivery_parts.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String? orderId;
  final PaymentMethod? paymentMethod;

  /// Ödenecek / havale edilecek tutar (`?total=` sorgu parametresi).
  final double? amount;

  /// Teslimat noktasının adı (`?point=` sorgu parametresi).
  final String? deliveryPointName;

  /// Siparişin ayrıntısını (adres, teslimat ücreti, teyit) getirir. Verilmezse
  /// kullanıcının siparişlerinden [orderId] ile bulunur. Testler sahte verir.
  final Future<Order?> Function(String orderId)? orderLoader;

  const OrderConfirmationPage({
    super.key,
    this.orderId,
    this.paymentMethod,
    this.amount,
    this.deliveryPointName,
    this.orderLoader,
  });

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _arrival;

  /// Sunucudaki sipariş (adres, ücret, teyit). Gelene kadar ya da
  /// alınamazsa sayfa yalnızca rota bilgileriyle (tutar, nokta) çalışır.
  Order? _order;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _arrival = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final id = widget.orderId ?? '';
    if (id.isEmpty) return;
    try {
      final loader = widget.orderLoader ?? _findOrder;
      final order = await loader(id);
      if (!mounted || order == null) return;
      setState(() => _order = order);
      // Tahmini teslimat süresi bölge listesinden gelir
      context.read<DeliveryViewModel?>()?.loadZones();
    } catch (e) {
      AppLogger.debug('Sipariş onayı: sipariş ayrıntısı alınamadı: $e');
    }
  }

  static Future<Order?> _findOrder(String id) async {
    final orders = await ApiService().getUserOrders();
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa giriş animasyonu atlanır.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _shortOrderId {
    final id = widget.orderId ?? '';
    if (id.isEmpty) return '';
    return id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();
  }

  void _goHome() => context.go('/home');

  void _trackOrder() => context.go(
        '/home',
        extra: {'initialTabIndex': 2, 'openOrders': true},
      );

  void _copyOrderNumber() {
    Clipboard.setData(ClipboardData(text: _shortOrderId));
    HapticFeedback.lightImpact();
    showMarketSnack(context, 'Sipariş numarası kopyalandı',
        icon: Icons.copy_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final bankTransfer = widget.paymentMethod == PaymentMethod.bankTransfer;
    // Sipariş verildikten sonra boşalan ödeme ekranına geri dönülmez; geri
    // tuşu / hareketi "Alışverişe devam et" gibi ana sayfaya götürür.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: MarketPalette.canvas,
        body: SingleChildScrollView(
          physics: const MarketScrollPhysics(),
          child: FadeTransition(
            opacity: _controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    MarketSpace.gutterOf(context),
                    16,
                    MarketSpace.gutterOf(context),
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Havale/EFT'de sıradaki iş ödeme olduğu için hesap
                      // bilgileri (IBAN, tutar, açıklama) en üstte durur.
                      if (bankTransfer) ...[
                        Consumer<SettingsViewModel>(
                          builder: (context, settings, _) => BankTransferCard(
                            settings: settings,
                            orderNumber:
                                _shortOrderId.isEmpty ? null : _shortOrderId,
                            amount: widget.amount,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildOrderCard(showAmount: !bankTransfer),
                      if (_order != null &&
                          OrderDeliveryNotes.hasAny(_order!)) ...[
                        const SizedBox(height: 14),
                        OrderDeliveryNotes(order: _order!),
                      ],
                      const SizedBox(height: 14),
                      const MarketNotice(
                        icon: Icons.notifications_active_outlined,
                        text:
                            'Sipariş durumundaki değişiklikleri sana bildireceğiz.',
                      ),
                      // İlk siparişten sonra (daha önce puan verilmediyse)
                      // tek seferlik puan kartı; aksi halde boş kalır.
                      const SizedBox(height: 14),
                      const FirstOrderRatingCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: MarketBottomBar(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _trackOrder,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(MarketSize.button),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Siparişimi takip et'),
              ),
              TextButton(
                onPressed: _goHome,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(MarketSize.control),
                ),
                child: const Text('Alışverişe devam et'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Durum çubuğunun yeşilini sürdüren başlık: onay rozeti ve kısa mesaj.
  Widget _buildHero() {
    final topInset = MediaQuery.paddingOf(context).top;
    // Kısa ekranda rozet küçülür; ödeme bilgileri daha yukarıda kalır.
    final short = MediaQuery.sizeOf(context).height < 700;
    return Container(
      decoration: const BoxDecoration(
        gradient: MarketPalette.headerGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(MarketRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 4, 12, 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ScaleTransition(
                    scale: _arrival,
                    child: _SuccessBadge(size: short ? 64 : 88),
                  ),
                ),
                SizedBox(height: short ? 10 : 14),
                Semantics(
                  header: true,
                  child: Text(
                    'Siparişin bizde!',
                    textAlign: TextAlign.center,
                    style: MarketText.display(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Siparişin alındı. Durumunu Siparişlerim\'den takip edebilirsin.',
                  textAlign: TextAlign.center,
                  style: MarketText.body(
                    color: Colors.white.withValues(alpha: .74),
                    size: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: _goHome,
              tooltip: 'Ana sayfaya dön',
              iconSize: 24,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .12),
                minimumSize:
                    const Size(MarketSize.tapTarget, MarketSize.tapTarget),
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }

  String get _amountLabel {
    switch (widget.paymentMethod) {
      case PaymentMethod.cash:
      case PaymentMethod.card:
        return 'Kapıda ödeyeceğin tutar';
      case PaymentMethod.bankTransfer:
        return 'Havale edilecek tutar';
      case null:
        return 'Tutar';
    }
  }

  /// [showAmount] false ise tutar satırı gösterilmez (havale kartında var).
  Widget _buildOrderCard({bool showAmount = true}) {
    final order = _order;
    // Sunucudaki tutar esas; sipariş gelene kadar rotadaki tutar gösterilir
    final amount = showAmount ? (order?.totalAmount ?? widget.amount) : null;
    final point = widget.deliveryPointName;
    final payment = widget.paymentMethod ?? order?.paymentMethod;
    final place = order == null ? null : OrderPlace.of(order);
    final eta = order == null
        ? null
        : context
            .watch<DeliveryViewModel?>()
            ?.zoneById(orderZoneId(order))
            ?.etaText
            .trim();
    final showFee = order != null && orderShowsDeliveryFee(order);
    final details = <Widget>[
      if (place != null && order!.isAddressDelivery)
        _AddressBlock(place: place)
      else if (place != null)
        _DetailRow(
          icon: Icons.apartment_rounded,
          label: 'Teslimat noktası',
          value: place.title,
        )
      else if (point != null && point.isNotEmpty)
        _DetailRow(
          icon: Icons.place_outlined,
          label: 'Teslimat',
          value: point,
        ),
      if (eta != null && eta.isNotEmpty)
        _DetailRow(
          icon: Icons.schedule_rounded,
          label: 'Tahmini teslimat',
          value: eta,
        ),
      if (payment != null)
        _DetailRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Ödeme',
          value: payment.label,
        ),
      // Ürünler − kupon + teslimat = ödenecek tutar
      if (order != null && (showFee || order.hasDiscount)) ...[
        _DetailRow(
          icon: Icons.shopping_basket_outlined,
          label: 'Ürünler',
          value: formatTl(orderProductsBeforeCoupon(order)),
        ),
        if (order.hasDiscount)
          _DetailRow(
            icon: Icons.local_activity_outlined,
            label: order.couponCode == null
                ? 'Kupon indirimi'
                : 'Kupon ${order.couponCode}',
            value: '−${formatTl(order.couponDiscount)}',
            valueColor: MarketPalette.green,
          ),
        if (showFee)
          _DetailRow(
            icon: Icons.delivery_dining_outlined,
            label: 'Teslimat',
            value: orderDeliveryFeeText(order),
            valueColor: order.deliveryFee <= 0 ? MarketPalette.green : null,
          ),
      ],
      if (amount != null && amount > 0)
        _DetailRow(
          icon: Icons.payments_outlined,
          label: _amountLabel,
          value: formatTl(amount),
          emphasized: true,
        ),
    ];

    return MarketCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MarketIconTile(icon: Icons.receipt_long_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sipariş numarası',
                        style: MarketText.caption(size: 12)),
                    const SizedBox(height: 2),
                    Text(
                      _shortOrderId.isEmpty ? '—' : '#$_shortOrderId',
                      style: MarketText.heading(size: 18),
                    ),
                  ],
                ),
              ),
              if (_shortOrderId.isNotEmpty)
                IconButton(
                  onPressed: _copyOrderNumber,
                  tooltip: 'Sipariş numarasını kopyala',
                  color: MarketPalette.greenDark,
                  iconSize: 20,
                  icon: const Icon(Icons.copy_rounded),
                ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, endIndent: 6),
            const SizedBox(height: 4),
            // Sipariş ayrıntısı gelince satırlar yumuşakça eklenir
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: details,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: _OrderProgress(),
          ),
        ],
      ),
    );
  }
}

/// Lime onay rozeti ve iki küçük süs noktası.
class _SuccessBadge extends StatelessWidget {
  final double size;

  const _SuccessBadge({this.size = 88});

  @override
  Widget build(BuildContext context) {
    final dot = size >= 80 ? 30.0 : 24.0;
    return SizedBox(
      width: size + 36,
      height: size + 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: MarketPalette.lime,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .16),
                width: 6,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: Icon(Icons.check_rounded,
                color: MarketPalette.greenDeep, size: size / 2),
          ),
          Positioned(
            right: 6,
            top: 2,
            child: _SuccessDot(
              size: dot,
              color: MarketPalette.orange,
              icon: Icons.auto_awesome_rounded,
            ),
          ),
          Positioned(
            left: 8,
            bottom: 4,
            child: _SuccessDot(
              size: dot,
              color: Colors.white,
              icon: Icons.favorite_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDot extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;

  const _SuccessDot({
    required this.size,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: size / 2, color: MarketPalette.greenDeep),
      ),
    );
  }
}

/// Adresli siparişte tam teslimat adresi: bölge, sokak/bina özeti, tarif.
class _AddressBlock extends StatelessWidget {
  final OrderPlace place;

  const _AddressBlock({required this.place});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 6, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.location_on_outlined,
                  size: 18, color: MarketPalette.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teslimat adresi',
                      style:
                          MarketText.body(color: MarketPalette.muted, size: 13)),
                  const SizedBox(height: 2),
                  Text(place.title, style: MarketText.label(size: 14)),
                  if (place.detail != null) ...[
                    const SizedBox(height: 1),
                    Text(place.detail!,
                        style: MarketText.body(
                            color: MarketPalette.inkSoft, size: 13)),
                  ],
                  if (place.directions != null) ...[
                    const SizedBox(height: 2),
                    Text(place.directions!, style: MarketText.caption()),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 6, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Icon(icon, size: 18, color: MarketPalette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style:
                        MarketText.body(color: MarketPalette.muted, size: 13)),
              ),
              const SizedBox(width: 12),
              // Değer sağa yaslanır; çok uzunsa satırın %60'ında kırılır.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * .6),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: emphasized
                      ? MarketText.price(
                          color: MarketPalette.greenDark, size: 18)
                      : MarketText.label(size: 13, color: valueColor ?? MarketPalette.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress();

  @override
  Widget build(BuildContext context) {
    const labels = ['Alındı', 'Hazırlanıyor', 'Yolda'];
    return Semantics(
      label: 'Sipariş durumu: Alındı. Sıradaki adımlar: Hazırlanıyor, Yolda.',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length * 2 - 1, (index) {
            if (index.isOdd) {
              return const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: Divider(
                      height: 2, color: MarketPalette.line, thickness: 2),
                ),
              );
            }
            final step = index ~/ 2;
            final active = step == 0;
            return Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: active ? MarketPalette.green : MarketPalette.canvas,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            active ? MarketPalette.green : MarketPalette.line),
                  ),
                  child: Icon(active ? Icons.check_rounded : Icons.circle,
                      color: active ? Colors.white : MarketPalette.lineStrong,
                      size: active ? 16 : 8),
                ),
                const SizedBox(height: 6),
                Text(labels[step],
                    style: MarketText.label(
                        color: active
                            ? MarketPalette.greenDark
                            : MarketPalette.muted,
                        size: 12)),
              ],
            );
          }),
        ),
      ),
    );
  }
}
