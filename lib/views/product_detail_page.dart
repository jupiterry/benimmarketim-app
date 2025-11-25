import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/firebase_analytics_service.dart';
import 'package:go_router/go_router.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  List<Product> _similarProducts = [];

  @override
  void initState() {
    super.initState();
    _loadSimilarProducts();

    // Analytics: View item event
    FirebaseAnalyticsService().logViewItem(
      itemId: widget.product.id,
      itemName: widget.product.name,
      itemCategory: widget.product.category,
      price: widget.product.actualPrice,
    );
  }

  Future<void> _loadSimilarProducts() async {
    try {
      // API'den benzer ürünleri çek
      final apiService = ApiService();
      final products = await apiService.getSimilarProducts(widget.product.id);

      if (mounted) {
        setState(() {
          _similarProducts = products;
        });
      }
    } catch (e) {
      print('Benzer ürünler yüklenirken hata: $e');
      // Hata durumunda fallback olarak client-side filtreleme yapabiliriz
      _loadSimilarProductsFallback();
    }
  }

  void _loadSimilarProductsFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final homeViewModel = context.read<HomePageViewModel>();
        if (homeViewModel.products.isNotEmpty) {
          final similar = homeViewModel.products.where((p) {
            return p.category == widget.product.category &&
                p.id != widget.product.id;
          }).toList();
          similar.shuffle();
          if (mounted) {
            setState(() {
              _similarProducts = similar.take(10).toList();
            });
          }
        }
      } catch (e) {
        print('Fallback benzer ürünler hatası: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ürün Detayı',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<FavoritesViewModel>(
            builder: (context, favoritesViewModel, child) {
              return IconButton(
                icon: Icon(
                  favoritesViewModel.isFavorite(widget.product.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: favoritesViewModel.isFavorite(widget.product.id)
                      ? Colors.red
                      : Colors.black,
                ),
                onPressed: () {
                  final authViewModel = context.read<AuthViewModel>();
                  if (!authViewModel.isLoggedIn) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Giriş Yapın',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        content: Text(
                          'Favorilere eklemek için giriş yapmalısınız.',
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'İptal',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/login');
                            },
                            child: Text(
                              'Giriş Yap',
                              style: GoogleFonts.poppins(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  favoritesViewModel.toggleFavorite(widget.product);
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Ürün resmi
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.white,
              child: widget.product.image.isNotEmpty
                  ? Hero(
                      tag: 'product_image_${widget.product.id}',
                      child: Image.network(
                        widget.product.image,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                            size: 80,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: 80,
                    ),
            ),

            // Ürün bilgileri
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün adı
                  Text(
                    widget.product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fiyat
                  Row(
                    children: [
                      Text(
                        '₺${widget.product.actualPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.green[700],
                        ),
                      ),
                      if (widget.product.isDiscounted) ...[
                        const SizedBox(width: 12),
                        Text(
                          '₺${widget.product.originalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '%${widget.product.discountPercentage.toInt()} İndirim',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Açıklama
                  Text(
                    'Açıklama',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.product.description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Miktar seçimi
                  Row(
                    children: [
                      Text(
                        'Miktar:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _quantity > 1
                                  ? () {
                                      setState(() {
                                        _quantity--;
                                      });
                                    }
                                  : null,
                            ),
                            Container(
                              width: 50,
                              alignment: Alignment.center,
                              child: Text(
                                _quantity.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  _quantity++;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sepete ekle butonu
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: Consumer<CartViewModel>(
                builder: (context, cartViewModel, child) {
                  return ElevatedButton(
                    onPressed: widget.product.isOutOfStock
                        ? null
                        : () {
                            for (int i = 0; i < _quantity; i++) {
                              cartViewModel.addToCart(widget.product);
                            }
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${widget.product.name} sepete eklendi',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.successGreen,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.all(16),
                                elevation: 4,
                              ),
                            );
                            context.pop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.product.isOutOfStock
                          ? 'Stokta Yok'
                          : 'Sepete Ekle (₺${(widget.product.actualPrice * _quantity).toStringAsFixed(2)})',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Benzer Ürünler
            if (_similarProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Benzer Ürünler',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _similarProducts.length,
                  itemBuilder: (context, index) {
                    final product = _similarProducts[index];
                    return Consumer<CartViewModel>(
                      builder: (context, cartViewModel, child) {
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.all(4),
                          child: GestureDetector(
                            onTap: () {
                              // Ürün detayına git (replace yerine push ki geri gelebilsin)
                              context.push('/product', extra: product);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          child: product.image.isNotEmpty
                                              ? Image.network(
                                                  product.image,
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Container(
                                                    color: Colors.grey[100],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '₺${product.actualPrice.toStringAsFixed(2)}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Sepete Ekle Butonu
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: product.isOutOfStock
                                          ? null
                                          : () {
                                              cartViewModel.addToCart(product);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${product.name} sepete eklendi',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      AppColors.successGreen,
                                                  duration: const Duration(
                                                      seconds: 1),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  margin:
                                                      const EdgeInsets.all(16),
                                                ),
                                              );
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: product.isOutOfStock
                                              ? Colors.grey[300]
                                              : AppColors.successGreen,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: product.isOutOfStock
                                                  ? Colors.transparent
                                                  : AppColors.successGreen
                                                      .withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          product.isOutOfStock
                                              ? Icons
                                                  .remove_shopping_cart_outlined
                                              : Icons.add_shopping_cart,
                                          color: product.isOutOfStock
                                              ? Colors.grey[500]
                                              : Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
