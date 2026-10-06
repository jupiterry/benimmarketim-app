import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import 'widgets/category_presentation.dart';
import 'widgets/market_palette.dart';
import 'widgets/market_product_card.dart';
import '../services/app_logger.dart';
import 'widgets/market_ui.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  List<Product> _similarProducts = [];
  bool _isLoadingSimilar = true;

  @override
  void initState() {
    super.initState();
    _loadSimilarProducts();
  }

  Future<void> _loadSimilarProducts() async {
    try {
      final products = await ApiService().getSimilarProducts(widget.product.id);
      if (!mounted) return;
      setState(() {
        _similarProducts = products
            .where(
              (product) => product.id != widget.product.id && !product.isHidden,
            )
            .take(10)
            .toList();
      });
    } catch (error) {
      if (kDebugMode) {
        AppLogger.debug('Benzer ürünler yüklenirken hata: $error');
      }
      _loadSimilarProductsFallback();
    } finally {
      if (mounted) {
        setState(() => _isLoadingSimilar = false);
      }
    }
  }

  void _loadSimilarProductsFallback() {
    final homeViewModel = context.read<HomePageViewModel>();
    final similar = homeViewModel.products
        .where((product) {
          return product.category == widget.product.category &&
              product.id != widget.product.id &&
              !product.isHidden;
        })
        .take(10)
        .toList();

    if (mounted) {
      setState(() => _similarProducts = similar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildImageStage()),
          SliverToBoxAdapter(child: _buildProductInformation()),
          SliverToBoxAdapter(child: _buildAssuranceStrip()),
          if (_isLoadingSimilar || _similarProducts.isNotEmpty)
            SliverToBoxAdapter(child: _buildSimilarProducts()),
          const SliverPadding(padding: EdgeInsets.only(bottom: 118)),
        ],
      ),
      bottomNavigationBar: _buildPurchaseBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: _RoundActionButton(
          icon: Icons.arrow_back_rounded,
          semanticLabel: 'Geri dön',
          onTap: () => context.pop(),
        ),
      ),
      title: Text(
        'Ürün Detayı',
        style: MarketText.heading(size: 16),
      ),
      actions: [
        Consumer<FavoritesViewModel>(
          builder: (context, favorites, _) {
            final isFavorite = favorites.isFavorite(widget.product.id);
            return _RoundActionButton(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: isFavorite ? MarketPalette.red : MarketPalette.ink,
              semanticLabel:
                  isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onTap: () => _toggleFavorite(favorites),
            );
          },
        ),
        const SizedBox(width: 18),
      ],
    );
  }

  Widget _buildImageStage() {
    return Container(
      height: 420,
      padding: EdgeInsets.fromLTRB(
        26,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
        26,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MarketPalette.greenSoft,
            MarketPalette.surface,
            MarketPalette.limeSoft,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(MarketRadius.xl)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -30,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MarketPalette.green.withValues(alpha: .045),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 320,
                maxHeight: 290,
              ),
              child: widget.product.image.isNotEmpty
                  ? Hero(
                      tag: 'product_image_${widget.product.id}',
                      child: Image.network(
                        widget.product.image,
                        fit: BoxFit.contain,
                        cacheWidth: 850,
                        errorBuilder: (_, __, ___) =>
                            const _LargeImageFallback(),
                      ),
                    )
                  : const _LargeImageFallback(),
            ),
          ),
          if (widget.product.isDiscounted &&
              widget.product.discountPercentage > 0)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MarketPalette.red,
                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: MarketPalette.red.withValues(alpha: .22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '%${widget.product.discountPercentage.toInt()} indirim',
                  style: MarketText.label(color: Colors.white, size: 12, weight: FontWeight.w800),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: widget.product.isOutOfStock
                ? const MarketPill(
                    label: 'Stokta yok',
                    icon: Icons.cancel_rounded,
                    background: MarketPalette.redSoft,
                    foreground: MarketPalette.red,
                  )
                : const MarketPill(
                    label: 'Stokta',
                    icon: Icons.check_circle_rounded,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInformation() {
    final description = widget.product.description.trim();
    final category = categoryDisplayName(widget.product.category);
    final emoji = categoryEmoji(widget.product.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketPill(label: '$emoji  $category'),
          const SizedBox(height: 14),
          Text(
            widget.product.name,
            style: MarketText.display(),
          ),
          const SizedBox(height: 17),
          _buildPrice(),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 25),
            Container(height: 1, color: MarketPalette.line),
            const SizedBox(height: 22),
            Row(
              children: [
                const MarketIconTile(
                  icon: Icons.notes_rounded,
                  size: 34,
                  background: MarketPalette.orangeSoft,
                  foreground: MarketPalette.orangeInk,
                ),
                const SizedBox(width: 10),
                Text(
                  'Ürün hakkında',
                  style: MarketText.heading(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: MarketText.body(color: MarketPalette.muted, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrice() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Text(
          '${formatTl(widget.product.actualPrice)}',
          style: MarketText.price(color: MarketPalette.greenDark, size: 28),
        ),
        if (widget.product.price > widget.product.actualPrice)
          Text(
            '${formatTl(widget.product.price)}',
            style: MarketText.body(color: MarketPalette.muted, size: 16, weight: FontWeight.w600).copyWith(decoration: TextDecoration.lineThrough, decorationColor: MarketPalette.muted),
          ),
        if (widget.product.price > widget.product.actualPrice)
          MarketPill(
            label: '${formatTl((widget.product.price - widget.product.actualPrice))} kazanç',
            background: MarketPalette.redSoft,
            foreground: MarketPalette.red,
          ),
      ],
    );
  }

  Widget _buildAssuranceStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: MarketPalette.line),
          borderRadius: BorderRadius.circular(MarketRadius.lg),
        ),
        child: const Row(
          children: [
            Expanded(
              child: _AssuranceItem(
                icon: Icons.verified_user_rounded,
                title: 'Güvenli',
                subtitle: 'Sipariş',
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _AssuranceItem(
                icon: Icons.inventory_2_rounded,
                title: 'Güncel',
                subtitle: 'Stok bilgisi',
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _AssuranceItem(
                icon: Icons.support_agent_rounded,
                title: 'Kolay',
                subtitle: 'Destek',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarProducts() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MarketSectionTitle(
              title: 'Benzer ürünler',
              trailing: _similarProducts.isEmpty
                  ? null
                  : MarketPill(label: '${_similarProducts.length} ürün'),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingSimilar)
            const _SimilarProductsSkeleton()
          else
            SizedBox(
              height: 304,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _similarProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 13),
                itemBuilder: (context, index) => SizedBox(
                  width: 176,
                  child: MarketProductCard(
                    product: _similarProducts[index],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurchaseBar() {
    return Consumer<CartViewModel>(
      builder: (context, cart, _) {
        final total = widget.product.actualPrice * _quantity;
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.paddingOf(context).bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: MarketPalette.line),
            ),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.ink.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              _DetailQuantitySelector(
                quantity: _quantity,
                onMinus:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                onPlus: () => setState(() => _quantity++),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.product.isOutOfStock
                      ? null
                      : () => _addToCart(cart),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: MarketText.label(size: 14, weight: FontWeight.w800),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.product.isOutOfStock) ...[
                        const Icon(Icons.remove_shopping_cart_rounded, size: 20),
                        const SizedBox(width: 9),
                      ],
                      Flexible(
                        child: Text(
                          widget.product.isOutOfStock
                              ? 'Stokta yok'
                              : 'Sepete ekle • ${formatTl(total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addToCart(CartViewModel cart) {
    for (var index = 0; index < _quantity; index++) {
      cart.addToCart(widget.product);
    }

    showMarketSnack(
      context,
      '$_quantity adet ${widget.product.name} sepete eklendi',
      aboveNavigation: true,
    );
  }

  void _toggleFavorite(FavoritesViewModel favorites) {
    final auth = context.read<AuthViewModel>();
    if (!auth.isLoggedIn) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Favorilerini sakla'),
          content: const Text(
            'Favorilere ürün eklemek için hesabına giriş yapmalısın.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Şimdi değil'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/login');
              },
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      );
      return;
    }
    favorites.toggleFavorite(widget.product);
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color iconColor;

  const _RoundActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor = MarketPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white.withValues(alpha: .94),
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: iconColor, size: 23),
          ),
        ),
      ),
    );
  }
}

class _DetailQuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  const _DetailQuantitySelector({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: MarketPalette.canvas,
        border: Border.all(color: MarketPalette.line),
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetailQuantityButton(
            icon: Icons.remove_rounded,
            tooltip: 'Azalt',
            onTap: onMinus,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: MarketText.heading(size: 16),
            ),
          ),
          _DetailQuantityButton(
            icon: Icons.add_rounded,
            tooltip: 'Artır',
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _DetailQuantityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _DetailQuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: SizedBox(
          width: 40,
          height: 58,
          child: Icon(
            icon,
            color: onTap == null
                ? MarketPalette.muted.withValues(alpha: .35)
                : MarketPalette.greenDark,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _AssuranceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AssuranceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: MarketPalette.green, size: 21),
        const SizedBox(height: 6),
        Text(
          title,
          style: MarketText.label(size: 12, weight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MarketText.caption(size: 11),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: MarketPalette.line,
    );
  }
}

class _LargeImageFallback extends StatelessWidget {
  const _LargeImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: MarketPalette.subtle,
        size: 72,
      ),
    );
  }
}

class _SimilarProductsSkeleton extends StatelessWidget {
  const _SimilarProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 304,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (_, __) => Container(
          width: 176,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            border: Border.all(color: MarketPalette.line),
          ),
        ),
      ),
    );
  }
}
