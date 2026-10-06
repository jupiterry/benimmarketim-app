import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/cart_fill.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import 'market_ui.dart';

/// Ana sayfa aşağı çekilip yenilendiğinde artırılır; kısayollar yeniden yüklenir.
final ValueNotifier<int> homeQuickCartsRefresh = ValueNotifier<int>(0);

/// Ana sayfadaki hızlı sepet kısayolları: son siparişi tekrarlama ve favori
/// sepetler. Giriş yapılmamışsa yer kaplamaz.
class HomeQuickCarts extends StatefulWidget {
  const HomeQuickCarts({super.key});

  @override
  State<HomeQuickCarts> createState() => _HomeQuickCartsState();
}

class _HomeQuickCartsState extends State<HomeQuickCarts> {
  Order? _lastOrder;
  String? _loadedForUser;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    homeQuickCartsRefresh.addListener(_reload);
  }

  @override
  void dispose() {
    homeQuickCartsRefresh.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Giriş durumu değişince (ör. açılışta profil yüklenince) yeniden yüklenir
    // didChangeDependencies içinde context.watch hata ayıklama modunda
    // izin verilmediği için Provider.of kullanılır.
    final auth = Provider.of<AuthViewModel>(context);
    final userId = auth.isLoggedIn ? auth.user?.id : null;
    if (userId == _loadedForUser) return;
    _loadedForUser = userId;
    if (userId == null) {
      _lastOrder = null;
    } else {
      _load(userId);
    }
  }

  void _reload() {
    final userId = _loadedForUser;
    if (userId != null) _load(userId);
  }

  Future<void> _load(String userId) async {
    Order? latest;
    try {
      final orders = await ApiService().getUserOrders();
      for (final order in orders) {
        if (order.status == 'İptal Edildi' || order.products.isEmpty) continue;
        if (latest == null || order.createdAt.isAfter(latest.createdAt)) {
          latest = order;
        }
      }
    } catch (_) {
      // Siparişler alınamazsa kısayol gösterilmez; ana sayfa etkilenmez
      return;
    }
    // Yükleme sürerken hesap değiştiyse eski sonucu gösterme
    if (!mounted || _loadedForUser != userId) return;
    setState(() => _lastOrder = latest);
  }

  Future<void> _repeatLastOrder() async {
    final order = _lastOrder;
    if (order == null || _adding) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
      ),
      builder: (_) => _RepeatOrderSheet(order: order),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _adding = true);
    final result = await addItemsToCart(
      context.read<CartViewModel>(),
      [
        for (final item in order.products)
          CartFillItem(
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (result.added == 0) {
      showMarketSnack(
        context,
        'Bu siparişteki ürünler şu an satışta değil.',
        error: true,
        aboveNavigation: true,
      );
      return;
    }
    showMarketSnack(
      context,
      cartFillMessage(result),
      icon: Icons.shopping_bag_rounded,
      aboveNavigation: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedForUser == null) return const SizedBox.shrink();
    final order = _lastOrder;
    final unitCount = order == null
        ? 0
        : order.products.fold<int>(0, (sum, item) => sum + item.quantity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MarketSpace.xl, MarketSpace.md, MarketSpace.xl, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order != null) ...[
              Expanded(
                child: _QuickTile(
                  icon: Icons.replay_rounded,
                  title: 'Son siparişimi tekrarla',
                  subtitle:
                      '$unitCount ürün · ${formatTlShort(order.totalAmount)}',
                  busy: _adding,
                  onTap: _repeatLastOrder,
                ),
              ),
              const SizedBox(width: MarketSpace.md),
            ],
            Expanded(
              child: _QuickTile(
                icon: Icons.bookmarks_outlined,
                title: 'Favori sepetlerim',
                subtitle: 'Kayıtlı listelerini sepete ekle',
                onTap: () => context.push('/saved-carts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return MarketCard(
      padding: const EdgeInsets.all(14),
      onTap: busy ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 38,
              height: 38,
              child: Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: MarketPalette.green),
              ),
            )
          else
            MarketIconTile(icon: icon, size: 38),
          const SizedBox(height: 10),
          Text(
            busy ? 'Sepete ekleniyor…' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MarketText.label(size: 13),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MarketText.caption(size: 12),
          ),
        ],
      ),
    );
  }
}

/// Son siparişin içeriğini gösterip sepete eklemeden önce onay alır.
class _RepeatOrderSheet extends StatelessWidget {
  final Order order;

  const _RepeatOrderSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final maxListHeight = MediaQuery.sizeOf(context).height * .42;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MarketSpace.xl, MarketSpace.xl, MarketSpace.xl, MarketSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MarketIconTile(icon: Icons.replay_rounded),
                const SizedBox(width: MarketSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Son siparişini tekrarla',
                          style: MarketText.heading()),
                      const SizedBox(height: 2),
                      Text(
                        '${order.products.length} çeşit ürün · o günkü tutar ${formatTl(order.totalAmount)}',
                        style: MarketText.caption(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MarketSpace.lg),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: order.products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = order.products[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.quantity}×',
                            style:
                                MarketText.label(color: MarketPalette.inkSoft)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.name,
                              style: MarketText.body(size: 13)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: MarketSpace.md),
            Text(
              'Ürünler güncel fiyatlarıyla eklenir. Stokta olmayanlar atlanır.',
              textAlign: TextAlign.center,
              style: MarketText.caption(size: 12),
            ),
            const SizedBox(height: MarketSpace.md),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Sepete ekle'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      ),
    );
  }
}
