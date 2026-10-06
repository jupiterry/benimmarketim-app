import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/cart_fill.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import 'widgets/market_ui.dart';
import 'widgets/save_cart_dialog.dart';

/// Favori sepetler: müşterinin ad vererek kaydettiği ürün listeleri. Her
/// liste tek dokunuşla, güncel fiyat ve stokla sepete eklenir.
class SavedCartsPage extends StatefulWidget {
  const SavedCartsPage({super.key});

  @override
  State<SavedCartsPage> createState() => _SavedCartsPageState();
}

class _SavedCartsPageState extends State<SavedCartsPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _carts = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!context.read<AuthViewModel>().isLoggedIn) {
      setState(() {
        _loading = false;
        _error = null;
        _carts = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getSavedCarts();
    if (!mounted) return;
    final carts = result['carts'];
    setState(() {
      _loading = false;
      if (result['success'] == true && carts is List) {
        _carts = carts
            .whereType<Map>()
            .map((cart) => Map<String, dynamic>.from(cart))
            .toList();
      } else {
        _error = (result['message'] ?? 'Favori sepetlerin yüklenemedi.')
            .toString();
      }
    });
  }

  List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> cart) {
    final items = cart['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _quantityOf(Map<String, dynamic> item) {
    final quantity = item['quantity'];
    return quantity is num && quantity >= 1 ? quantity.toInt() : 1;
  }

  Future<void> _addToCart(Map<String, dynamic> cart) async {
    final id = (cart['id'] ?? '').toString();
    if (_busyId != null) return;
    final items = _itemsOf(cart)
        .where((item) => item['available'] == true)
        .toList();
    if (items.isEmpty) {
      showMarketSnack(context, 'Bu sepetteki ürünler şu an satışta değil.',
          error: true);
      return;
    }

    setState(() => _busyId = id);
    final result = await addItemsToCart(
      context.read<CartViewModel>(),
      [
        for (final item in items)
          CartFillItem(
            productId: (item['productId'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
            quantity: _quantityOf(item),
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _busyId = null);
    if (result.added == 0) {
      showMarketSnack(context, 'Bu sepetteki ürünler şu an satışta değil.',
          error: true);
      return;
    }
    showMarketSnack(context, cartFillMessage(result),
        icon: Icons.shopping_bag_rounded);
  }

  Future<void> _delete(Map<String, dynamic> cart) async {
    final id = (cart['id'] ?? '').toString();
    final name = (cart['name'] ?? '').toString();
    if (id.isEmpty || _busyId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.delete_outline_rounded,
          size: 52,
          background: MarketPalette.redSoft,
          foreground: MarketPalette.red,
        ),
        title: const Text('Favori sepet silinsin mi?',
            textAlign: TextAlign.center),
        content: Text(
          '“$name” kayıtlı listelerinden kaldırılacak. Sepetindeki ürünler etkilenmez.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: MarketPalette.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = id);
    final result = await _api.deleteSavedCart(id);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (result['success'] == true) {
        _carts = _carts.where((item) => item['id'] != cart['id']).toList();
      }
    });
    if (result['success'] == true) {
      showMarketSnack(context, 'Favori sepet silindi');
    } else {
      showMarketSnack(
        context,
        (result['message'] ?? 'Sepet silinemedi. Lütfen tekrar dene.')
            .toString(),
        error: true,
      );
    }
  }

  Future<void> _saveCurrentCart() async {
    final cart = context.read<CartViewModel>();
    final saved = await showSaveCartDialog(
      context,
      items: [
        for (final item in cart.items)
          {
            'productId': item.product.id,
            'quantity': item.quantity > 20 ? 20 : item.quantity,
          },
      ],
    );
    if (saved && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthViewModel>().isLoggedIn;
    final cartHasItems =
        context.select<CartViewModel, bool>((cart) => !cart.isEmpty);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: MarketScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: MarketHeader(
                title: 'Favori sepetlerim',
                subtitle: _loading
                    ? 'Listelerin yükleniyor'
                    : _carts.isEmpty
                        ? 'Sık aldıklarını kaydet, tek dokunuşla ekle'
                        : '${_carts.length} kayıtlı liste',
                icon: Icons.bookmarks_rounded,
                compact: true,
              ),
            ),
            if (!loggedIn)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MarketEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Giriş yapmalısın',
                  message:
                      'Favori sepetlerin hesabına kaydedilir. Görmek için giriş yap.',
                  actionLabel: 'Giriş yap',
                  actionIcon: Icons.login_rounded,
                  onAction: () async {
                    await context.push('/login');
                    if (mounted) _load();
                  },
                ),
              )
            else if (_loading)
              const SliverToBoxAdapter(child: MarketListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MarketEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Favori sepetler yüklenemedi',
                  message: _error!,
                  actionLabel: 'Tekrar dene',
                  actionIcon: Icons.refresh_rounded,
                  onAction: _load,
                  tint: MarketPalette.red,
                  tintSoft: MarketPalette.redSoft,
                ),
              )
            else if (_carts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MarketEmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Henüz favori sepetin yok',
                  message: cartHasItems
                      ? 'Şu an sepetinde olan ürünleri bir adla kaydedebilir, sonra tek dokunuşla yeniden ekleyebilirsin.'
                      : 'Sepetini doldur, Sepetim ekranının üstündeki kaydet düğmesine dokun. Listen burada görünür.',
                  actionLabel:
                      cartHasItems ? 'Sepetimi kaydet' : 'Ürünleri keşfet',
                  actionIcon: cartHasItems
                      ? Icons.bookmark_add_outlined
                      : Icons.explore_rounded,
                  onAction: cartHasItems
                      ? _saveCurrentCart
                      : () => context.go('/home'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _carts.length + (cartHasItems ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    if (index == _carts.length) {
                      return OutlinedButton.icon(
                        onPressed: _busyId != null ? null : _saveCurrentCart,
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Şu anki sepetimi de kaydet'),
                      );
                    }
                    return _buildCart(_carts[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCart(Map<String, dynamic> cart) {
    final id = (cart['id'] ?? '').toString();
    final items = _itemsOf(cart);
    final available =
        items.where((item) => item['available'] == true).toList();
    final unavailable = items.length - available.length;
    final total = cart['total'];
    final busy = _busyId == id;
    const previewCount = 4;

    return MarketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MarketIconTile(icon: Icons.bookmark_rounded),
              const SizedBox(width: MarketSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (cart['name'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.heading(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${items.length} çeşit ürün'
                      '${total is num && available.isNotEmpty ? ' · bugünkü tutar ${formatTl(total)}' : ''}',
                      style: MarketText.caption(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _busyId != null ? null : () => _delete(cart),
                tooltip: 'Favori sepeti sil',
                icon: const Icon(Icons.delete_outline_rounded),
                color: MarketPalette.muted,
              ),
            ],
          ),
          const SizedBox(height: MarketSpace.md),
          for (final item in items.take(previewCount))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_quantityOf(item)}×',
                    style: MarketText.label(color: MarketPalette.inkSoft),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (item['name'] ?? '').toString(),
                      style: MarketText.body(
                        size: 13,
                        color: item['available'] == true
                            ? MarketPalette.ink
                            : MarketPalette.subtle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['available'] == true && item['price'] is num
                        ? formatTl((item['price'] as num) * _quantityOf(item))
                        : 'Satışta değil',
                    style: MarketText.label(
                      color: item['available'] == true
                          ? MarketPalette.inkSoft
                          : MarketPalette.subtle,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (items.length > previewCount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                've ${items.length - previewCount} ürün daha',
                style: MarketText.caption(size: 12),
              ),
            ),
          if (unavailable > 0)
            Padding(
              padding: const EdgeInsets.only(top: MarketSpace.md),
              child: MarketNotice.warning(
                icon: Icons.info_outline_rounded,
                text: available.isEmpty
                    ? 'Bu listedeki ürünler şu an satışta değil.'
                    : '$unavailable ürün şu an satışta değil; kalanlar eklenir.',
              ),
            ),
          const SizedBox(height: MarketSpace.md),
          FilledButton.icon(
            onPressed: _busyId != null || available.isEmpty
                ? null
                : () => _addToCart(cart),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(busy ? 'Ekleniyor…' : 'Sepete ekle'),
          ),
        ],
      ),
    );
  }
}
