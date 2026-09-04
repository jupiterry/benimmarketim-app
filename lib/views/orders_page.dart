import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/order.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../services/theme_service.dart';
import 'widgets/market_palette.dart';
import 'package:go_router/go_router.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

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

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
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

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş iptal edildi'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
        _loadOrders(); // Listeyi yenile
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş iptal edilemedi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hazırlanıyor':
        return Colors.orange;
      case 'Yolda':
        return Colors.blue;
      case 'Teslim Edildi':
        return AppColors.successGreen;
      case 'İptal Edildi':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _startOrderSupport(Order order) async {
    // Sipariş saatleri kontrolü
    final settingsViewModel = context.read<SettingsViewModel>();
    if (!settingsViewModel.isWithinOrderHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Canlı destek sadece sipariş saatlerinde aktiftir.\n${settingsViewModel.orderHoursMessage}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.successGreen),
          ),
        ),
      ),
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
            '💰 Tutar: ₺${order.totalAmount.toStringAsFixed(2)}\n'
            '📊 Durum: ${order.status}';

        await chatViewModel.sendMessage(orderMessage);

        // Chat sayfasına git
        if (!mounted) return;
        context.push('/chat/${chat.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Destek başlatılamadı', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Loading kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildModernOrdersPage();
  }

  Widget _buildModernOrdersPage() {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: RefreshIndicator(
        color: MarketPalette.green,
        onRefresh: _loadOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildModernHeader()),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: MarketPalette.green),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _modernState(
                  Icons.cloud_off_rounded,
                  'Siparişler yüklenemedi',
                  'Bağlantını kontrol edip yeniden deneyebilirsin.',
                  'Tekrar dene',
                  _loadOrders,
                ),
              )
            else if (_orders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _modernState(
                  Icons.receipt_long_outlined,
                  'Henüz siparişin yok',
                  'İlk siparişini verdiğinde tüm süreci buradan takip edebilirsin.',
                  'Ürünleri keşfet',
                  () => context.go('/home'),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _buildOverview()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
                sliver: SliverList.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) =>
                      _buildModernOrderCard(_orders[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarketPalette.greenDeep, MarketPalette.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Row(
            children: [
              _modernHeaderButton(
                  Icons.arrow_back_rounded, () => context.pop()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Siparişlerim',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Tüm siparişlerin tek yerde',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _modernHeaderButton(Icons.refresh_rounded, _loadOrders),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernHeaderButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final active = _orders
        .where((order) =>
            order.status == 'Hazırlanıyor' || order.status == 'Yolda')
        .length;
    final delivered =
        _orders.where((order) => order.status == 'Teslim Edildi').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        children: [
          _overviewItem('Toplam', _orders.length, Icons.receipt_long_rounded,
              MarketPalette.green),
          const SizedBox(width: 9),
          _overviewItem('Aktif', active, Icons.local_shipping_outlined,
              MarketPalette.orange),
          const SizedBox(width: 9),
          _overviewItem('Teslim', delivered, Icons.check_circle_outline_rounded,
              const Color(0xFF4A76D1)),
        ],
      ),
    );
  }

  Widget _overviewItem(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MarketPalette.line),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: GoogleFonts.manrope(
                    color: MarketPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label,
                    style: GoogleFonts.inter(
                        color: MarketPalette.muted, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOrderCard(Order order) {
    final color = _getStatusColor(order.status);
    final products = order.products.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MarketPalette.line),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .04),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_modernStatusIcon(order.status),
                      color: color, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sipariş #' + _modernShortId(order.id),
                        style: GoogleFonts.manrope(
                          color: MarketPalette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(_formatDate(order.createdAt),
                          style: GoogleFonts.inter(
                              color: MarketPalette.muted, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(order.status,
                      style: GoogleFonts.inter(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: MarketPalette.line),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                ...products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        children: [
                          _modernProductImage(product.image),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: MarketPalette.ink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                Text(product.quantity.toString() + ' adet',
                                    style: GoogleFonts.inter(
                                        color: MarketPalette.muted,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                          Text(
                            '₺' +
                                (product.price * product.quantity)
                                    .toStringAsFixed(2),
                            style: GoogleFonts.manrope(
                                color: MarketPalette.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )),
                if (order.products.length > products.length)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+' +
                          (order.products.length - products.length).toString() +
                          ' ürün daha',
                      style: GoogleFonts.inter(
                          color: MarketPalette.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 8),
                _modernStatusTrack(order.status),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
            decoration: const BoxDecoration(
              color: MarketPalette.canvas,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                _modernAction(Icons.support_agent_rounded, 'Destek',
                    const Color(0xFF3976C5), () => _startOrderSupport(order)),
                if (order.status == 'Hazırlanıyor') ...[
                  const SizedBox(width: 7),
                  _modernAction(Icons.close_rounded, 'İptal', MarketPalette.red,
                      () => _showCancelDialog(order.id)),
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Toplam',
                        style: GoogleFonts.inter(
                            color: MarketPalette.muted, fontSize: 9)),
                    Text('₺' + order.totalAmount.toStringAsFixed(2),
                        style: GoogleFonts.manrope(
                            color: MarketPalette.greenDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernProductImage(String? image) {
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MarketPalette.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: image == null || image.isEmpty
          ? const Icon(Icons.shopping_bag_outlined,
              color: MarketPalette.muted, size: 19)
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shopping_bag_outlined,
                color: MarketPalette.muted,
                size: 19,
              ),
            ),
    );
  }

  Widget _modernStatusTrack(String status) {
    if (status == 'İptal Edildi') {
      return Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: MarketPalette.red),
          const SizedBox(width: 6),
          Text('Bu sipariş iptal edildi.',
              style: GoogleFonts.inter(
                  color: MarketPalette.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      );
    }
    final value = switch (status) {
      'Teslim Edildi' => 1.0,
      'Yolda' => .72,
      'Hazırlanıyor' => .36,
      _ => .15,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: MarketPalette.line,
        color: _getStatusColor(status),
      ),
    );
  }

  Widget _modernAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernState(IconData icon, String title, String description,
      String button, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: const BoxDecoration(
              color: MarketPalette.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: MarketPalette.green),
          ),
          const SizedBox(height: 22),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: MarketPalette.muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 23),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: MarketPalette.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(button,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  IconData _modernStatusIcon(String status) {
    return switch (status) {
      'Hazırlanıyor' => Icons.soup_kitchen_outlined,
      'Yolda' => Icons.delivery_dining_rounded,
      'Teslim Edildi' => Icons.check_circle_rounded,
      'İptal Edildi' => Icons.cancel_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  String _modernShortId(String id) {
    if (id.isEmpty) return '—';
    return id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();
  }

  void _showCancelDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Siparişi İptal Et',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Bu siparişi iptal etmek istediğinizden emin misiniz?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              _cancelOrder(orderId);
            },
            child: Text(
              'İptal Et',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final turkeyDate = date.toUtc().add(const Duration(hours: 3));
    return '${turkeyDate.day.toString().padLeft(2, '0')}.${turkeyDate.month.toString().padLeft(2, '0')}.${turkeyDate.year} ${turkeyDate.hour.toString().padLeft(2, '0')}:${turkeyDate.minute.toString().padLeft(2, '0')}';
  }
}
