import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../../viewmodels/favorites_viewmodel.dart';
import 'category_presentation.dart';
import 'market_palette.dart';

class MarketProductCard extends StatelessWidget {
  final Product product;

  const MarketProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FavoritesViewModel, CartViewModel>(
      builder: (context, favorites, cart, _) {
        final isFavorite = favorites.isFavorite(product.id);
        final quantity = cart.getProductQuantity(product.id);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/product', extra: product),
            borderRadius: BorderRadius.circular(23),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: MarketPalette.line),
                borderRadius: BorderRadius.circular(23),
                boxShadow: [
                  BoxShadow(
                    color: MarketPalette.ink.withValues(alpha: .045),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8F5),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: product.image.isNotEmpty
                                ? Hero(
                                    tag: 'product_image_${product.id}',
                                    child: Image.network(
                                      product.image,
                                      fit: BoxFit.contain,
                                      cacheWidth: 380,
                                      errorBuilder: (_, __, ___) =>
                                          const _ProductImageFallback(),
                                    ),
                                  )
                                : const _ProductImageFallback(),
                          ),
                        ),
                        if (product.isDiscounted &&
                            product.discountPercentage > 0)
                          Positioned(
                            left: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: MarketPalette.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '%${product.discountPercentage.toInt()}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 14,
                          top: 14,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _toggleFavorite(context, favorites),
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFavorite
                                      ? MarketPalette.red
                                      : MarketPalette.muted,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (product.isOutOfStock)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .80),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: MarketPalette.ink,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'STOKTA YOK',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.category.trim().isNotEmpty)
                          Text(
                            categoryDisplayName(product.category).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: MarketPalette.green,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .55,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: MarketPalette.ink,
                            fontSize: 12,
                            height: 1.22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _ProductPrice(product: product)),
                            const SizedBox(width: 5),
                            if (product.isOutOfStock)
                              const _DisabledAddButton()
                            else if (quantity > 0)
                              _QuantityControl(
                                quantity: quantity,
                                onMinus: () => cart.removeFromCart(product),
                                onPlus: () => cart.addToCart(product),
                              )
                            else
                              _AddButton(
                                onTap: () {
                                  cart.addToCart(product);
                                  _showAddedMessage(context, product.name);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleFavorite(
    BuildContext context,
    FavoritesViewModel favorites,
  ) {
    final auth = context.read<AuthViewModel>();
    if (!auth.isLoggedIn) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Favorilerini sakla',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Favorilere ürün eklemek için hesabına giriş yapmalısın.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.45),
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
              style: FilledButton.styleFrom(
                backgroundColor: MarketPalette.green,
              ),
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      );
      return;
    }
    favorites.toggleFavorite(product);
  }

  void _showAddedMessage(BuildContext context, String productName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$productName sepete eklendi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: MarketPalette.greenDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 102),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }
}

class _ProductPrice extends StatelessWidget {
  final Product product;

  const _ProductPrice({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (product.isDiscounted && product.discountedPrice != null)
          Text(
            '₺${product.price.toStringAsFixed(2)}',
            maxLines: 1,
            style: GoogleFonts.inter(
              color: MarketPalette.muted,
              fontSize: 9,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '₺${product.actualPrice.toStringAsFixed(2)}',
            style: GoogleFonts.manrope(
              color: MarketPalette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MarketPalette.green,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _DisabledAddButton extends StatelessWidget {
  const _DisabledAddButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECE9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.remove_rounded,
        color: MarketPalette.muted,
        size: 20,
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityControl({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 22,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: MarketPalette.greenDark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _QuantityButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 26,
        height: 38,
        child: Icon(icon, color: MarketPalette.greenDark, size: 16),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFFBAC4BD),
        size: 38,
      ),
    );
  }
}
