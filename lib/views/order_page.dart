import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/review_service.dart';
import '../models/order.dart';
import 'widgets/market_palette.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String _selectedDeliveryPoint = '';
  bool _feedbackSatisfied = false; // Bu oturumda geri bildirim verildi mi

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool?> _showFeedbackDialog(BuildContext context) async {
    int rating = 5;
    String message = '';
    bool submitting = false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              margin: EdgeInsets.only(bottom: bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Column(
                      children: [
                        // Header with emoji
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.successGreen.withOpacity(0.15),
                                Colors.amber.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Text('🎉', style: TextStyle(fontSize: 40)),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Merhaba!',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk siparişinizi nasıl buldunuz?\nBize puanınızı verin!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Star Rating with Emojis
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              final starIndex = index + 1;
                              final filled = starIndex <= rating;
                              return GestureDetector(
                                onTap: () => setState(() => rating = starIndex),
                                child: AnimatedScale(
                                  scale: filled ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    filled ? '⭐' : '☆',
                                    style:
                                        TextStyle(fontSize: filled ? 36 : 32),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // Rating label
                        const SizedBox(height: 12),
                        Text(
                          _getRatingLabel(rating),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getRatingColor(rating),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Message Input
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: TextField(
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Düşüncelerinizi paylaşın (opsiyonel)',
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey[400], fontSize: 14),
                              prefixIcon: Icon(Icons.mode_comment_outlined,
                                  color: Colors.grey[400], size: 22),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            maxLines: 3,
                            minLines: 1,
                            onChanged: (v) => message = v,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setState(() => submitting = true);
                                    try {
                                      final api = ApiService();
                                      await api.createFeedback(
                                        rating: rating,
                                        ratings: {'overall': rating},
                                        title: 'Genel Değerlendirme',
                                        message: message,
                                        category: 'Genel',
                                      );
                                      if (context.mounted) context.pop(true);
                                    } catch (_) {
                                      if (context.mounted) context.pop(false);
                                    } finally {
                                      if (context.mounted)
                                        setState(() => submitting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: submitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Gönder ve Devam Et',
                                          style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Skip Button
                        TextButton(
                          onPressed: () => context.pop(false),
                          child: Text('Daha Sonra',
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return '😞 Berbat';
      case 2:
        return '😕 Kötü';
      case 3:
        return '😐 Orta';
      case 4:
        return '😊 İyi';
      case 5:
        return '🤩 Mükemmel!';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return AppColors.successGreen;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createOrder() async {
    print('==============================================');
    print('🛒 ORDER CREATION STARTED');
    print('==============================================');

    // Giriş kontrolü - eğer giriş yapmamışsa login sayfasına yönlendir
    final authViewModel = context.read<AuthViewModel>();
    print('📝 Auth check: isLoggedIn = ${authViewModel.isLoggedIn}');

    if (!authViewModel.isLoggedIn) {
      print('⚠️ User not logged in, redirecting to login page');
      final result = await context.push<bool>('/login');

      // Login sayfasından döndüyse ve giriş yapıldıysa devam et
      if (result != true && !authViewModel.isLoggedIn) {
        print('❌ User did not login, order creation cancelled');
        return; // Giriş yapılmadı, sipariş verme işlemini durdur
      }
    }

    print('✅ User is logged in, proceeding with order creation');

    print('📋 Validating form...');
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    print('✅ Form validation passed');

    print('📍 Checking delivery point selection...');
    if (_selectedDeliveryPoint.isEmpty) {
      print('❌ No delivery point selected');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off,
                  color: AppColors.errorRed,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Teslimat Noktası',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Lütfen siparişinizin teslim edileceği noktayı seçin.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.successGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Tamam',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsViewModel = context.read<SettingsViewModel>();

      // Sipariş saatleri kontrolü
      print('⏰ Checking order hours...');
      if (!settingsViewModel.isWithinOrderHours) {
        print('❌ Outside of order hours');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: AppColors.warningOrange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Sipariş Saatleri',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              settingsViewModel.orderHoursMessage,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.successGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Tamam',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      print('✅ Within order hours');

      // Tüm teslimat noktaları kapalı mı kontrolü
      print('🏢 Checking delivery points availability...');
      if (!settingsViewModel.girlsDormEnabled &&
          !settingsViewModel.boysDormEnabled) {
        print('❌ All delivery points are closed');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    color: AppColors.errorRed,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Teslimat Kapalı',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Şu anda tüm teslimat noktaları kapalıdır. Lütfen daha sonra tekrar deneyin.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.successGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Tamam',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      print('✅ At least one delivery point is open');

      final cartViewModel = context.read<CartViewModel>();

      if (cartViewModel.items.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.warningOrange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Sepet Boş',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Sepetinizde ürün bulunmamaktadır. Sipariş vermek için önce sepetinize ürün ekleyin.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.successGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Tamam',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Minimum sipariş tutarı kontrolü (API'den gelen değer)
      final minimumOrderAmount = settingsViewModel.minimumOrderAmount;
      if (cartViewModel.totalPrice < minimumOrderAmount) {
        final eksikTutar = minimumOrderAmount - cartViewModel.totalPrice;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Minimum sipariş tutarı ${minimumOrderAmount.toStringAsFixed(0)}₺\'dir. Sepetinize ${eksikTutar.toStringAsFixed(2)}₺ daha ürün eklemelisiniz.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.warningOrange,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final couponIsValid = await cartViewModel
          .validateCouponForDeliveryPoint(_selectedDeliveryPoint);
      if (!couponIsValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cartViewModel.couponError ??
                    'Kupon seçilen teslimat noktasında kullanılamıyor.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Sipariş oluştur - Web projesindeki API formatına uygun
      final orderRequest = CreateOrderRequest(
        products: cartViewModel.items
            .map(
              (item) => {
                'product': item
                    .product.id, // Web projesinde 'product' field'ı bekleniyor
                'quantity': item.quantity,
                'price': item.product.actualPrice, // İndirimli fiyatı kullan
              },
            )
            .toList(),
        totalAmount: cartViewModel.finalPrice, // İndirimli fiyatı kullan
        city: 'Zonguldak', // Web projesinde zorunlu
        phone: _phoneController.text,
        deliveryPoint: _selectedDeliveryPoint, // 'girlsDorm' veya 'boysDorm'
        deliveryPointName: _selectedDeliveryPoint == 'girlsDorm'
            ? settingsViewModel.girlsDormName
            : settingsViewModel.boysDormName,
        note: _notesController.text,
        couponCode: cartViewModel.appliedCouponCode, // Kupon kodu
        discountAmount: cartViewModel.discountAmount, // İndirim miktarı
        device: {
          'platform': Platform.isIOS
              ? 'ios'
              : (Platform.isAndroid ? 'android' : 'unknown'),
          'model': '', // Gerekirse device_info paketi ile alınabilir
          'appVersion': '3.0.0', // Gerekirse package_info_plus ile alınabilir
        },
      );

      // Debug: Request data'yı yazdır
      print('=== ORDER REQUEST DEBUG ===');
      print('Request Data: ${orderRequest.toJson()}');
      print('Products Count: ${orderRequest.products.length}');
      print('Total Amount: ${orderRequest.totalAmount}');
      print('City: ${orderRequest.city}');
      print('Phone: ${orderRequest.phone}');
      print('Delivery Point: ${orderRequest.deliveryPoint}');
      print('Delivery Point Name: ${orderRequest.deliveryPointName}');
      print('Note: ${orderRequest.note}');
      print('=== COUPON DEBUG ===');
      print('Applied Coupon Code: ${cartViewModel.appliedCouponCode}');
      print('Discount Amount: ${cartViewModel.discountAmount}');
      print('Total Price (before discount): ${cartViewModel.totalPrice}');
      print('Final Price (after discount): ${cartViewModel.finalPrice}');
      print('Request Coupon Code: ${orderRequest.couponCode}');
      print('Request Discount Amount: ${orderRequest.discountAmount}');
      print('===================');

      final apiService = ApiService();

      // İlk sipariş geri bildirim guard'ı (oturum içi hafıza ile)
      final auth = context.read<AuthViewModel>();
      final currentUserId = auth.user?.id ?? '';
      if (currentUserId.isNotEmpty && !_feedbackSatisfied) {
        final hasFeedback = await apiService.hasUserGivenFeedback(
          currentUserId,
        );
        if (!hasFeedback) {
          final ok = await _showFeedbackDialog(context);
          if (ok == true) {
            _feedbackSatisfied = true; // tekrar sorma
          } else {
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else {
          _feedbackSatisfied = true;
        }
      }

      final order = await apiService.createOrder(orderRequest);

      // Başarılı sipariş
      // Başarılı sipariş - SnackBar kaldırıldı

      // In-app review - sipariş tamamlandığında değerlendirme iste (koşullar sağlanıyorsa)
      await ReviewService.instance.onOrderCompleted();

      // Sepeti temizle
      cartViewModel.clearCart();

      // Sipariş onay sayfasına yönlendir
      print('=== NAVIGATING TO ORDER CONFIRMATION ===');
      print('Order ID: ${order.id}');
      print('Navigation path: /order-confirmation/${order.id}');

      if (mounted) {
        context.go('/order-confirmation/${order.id}');
      }
    } catch (e) {
      String errorMessage = 'Sipariş oluşturulurken hata oluştu.';
      String detailedError = '';

      if (e is DioException) {
        if (e.response != null) {
          print('Order Error Response Data: ${e.response?.data}');

          // Backend'den gelen hata mesajını almaya çalış
          if (e.response?.data is Map) {
            final data = e.response?.data as Map;
            if (data.containsKey('message')) {
              detailedError = data['message'].toString();
            } else if (data.containsKey('error')) {
              detailedError = data['error'].toString();
            }
          }
        }
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Sipariş Hatası',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage, style: GoogleFonts.poppins()),
                if (detailedError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      detailedError,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Tamam',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartViewModel>(
      builder: (context, cart, child) {
        if (cart.items.isEmpty) return _buildEmptyOrderPage();

        return Scaffold(
          backgroundColor: MarketPalette.canvas,
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildCheckoutHeader(cart)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 132),
                  sliver: SliverList.list(
                    children: [
                      _buildModernOrderSummary(cart),
                      const SizedBox(height: 16),
                      _buildModernDeliverySection(),
                      const SizedBox(height: 16),
                      _buildModernNotes(),
                      const SizedBox(height: 16),
                      _buildSecureInfo(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildCheckoutBar(cart),
        );
      },
    );
  }

  Widget _buildEmptyOrderPage() {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _roundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop(),
                ),
              ),
              const Spacer(),
              Container(
                width: 142,
                height: 142,
                decoration: const BoxDecoration(
                  color: MarketPalette.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 62,
                  color: MarketPalette.green,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Sepetin şu an boş',
                style: GoogleFonts.manrope(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: MarketPalette.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Siparişini oluşturmak için birkaç ürün seçmen yeterli.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: MarketPalette.muted,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Ürünleri keşfet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MarketPalette.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutHeader(CartViewModel cart) {
    final itemCount = cart.items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MarketPalette.greenDeep, MarketPalette.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                    dark: true,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: Text(
                      '$itemCount ürün',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SON ADIM',
                          style: GoogleFonts.inter(
                            color: MarketPalette.lime,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Siparişini tamamla',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Teslimat bilgilerini kontrol et, hazırsan gönder.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(.72),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: MarketPalette.lime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: MarketPalette.greenDeep,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernOrderSummary(CartViewModel cart) {
    return _checkoutCard(
      child: Column(
        children: [
          _sectionTitle(
            icon: Icons.shopping_bag_rounded,
            title: 'Sepet özeti',
            trailing: '${cart.items.length} çeşit',
          ),
          const SizedBox(height: 18),
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: GoogleFonts.inter(
                        color: MarketPalette.greenDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: MarketPalette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '₺${item.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      color: MarketPalette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: MarketPalette.line, height: 18),
          _priceLine('Ara toplam', cart.totalPrice),
          if (cart.discountAmount > 0) ...[
            const SizedBox(height: 9),
            _priceLine(
              'Kupon indirimi (${cart.appliedCouponCode ?? ''})',
              -cart.discountAmount,
              highlight: true,
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Text(
                'Ödenecek tutar',
                style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '₺${cart.finalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  color: MarketPalette.green,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernDeliverySection() {
    return Consumer<SettingsViewModel>(
      builder: (context, settings, child) {
        return _checkoutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                icon: Icons.location_on_rounded,
                title: 'Teslimat noktası',
                trailing: 'Zonguldak',
              ),
              const SizedBox(height: 8),
              Text(
                'Siparişini nereden teslim almak istediğini seç.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MarketPalette.muted,
                ),
              ),
              const SizedBox(height: 16),
              if (settings.girlsDormEnabled)
                _buildModernDeliveryOption(
                  id: 'girlsDorm',
                  title: settings.girlsDormName,
                  subtitle: 'Kız öğrenci yurdu teslimat noktası',
                ),
              if (settings.girlsDormEnabled && settings.boysDormEnabled)
                const SizedBox(height: 10),
              if (settings.boysDormEnabled)
                _buildModernDeliveryOption(
                  id: 'boysDorm',
                  title: settings.boysDormName,
                  subtitle: 'Erkek öğrenci yurdu teslimat noktası',
                ),
              if (!settings.girlsDormEnabled && !settings.boysDormEnabled)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: MarketPalette.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Şu anda aktif teslimat noktası bulunmuyor.',
                          style: GoogleFonts.inter(
                            color: MarketPalette.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              _modernTextField(
                controller: _phoneController,
                label: 'Telefon numarası',
                hint: '5XX XXX XX XX',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (phone.isEmpty) return 'Telefon numarası gerekli';
                  if (phone.length < 10) return 'Geçerli bir numara giriniz';
                  return null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernDeliveryOption({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedDeliveryPoint == id;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title teslimat noktasını seç',
      child: InkWell(
        onTap: () => setState(() => _selectedDeliveryPoint = id),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? MarketPalette.greenSoft : MarketPalette.canvas,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? MarketPalette.green : MarketPalette.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? MarketPalette.green : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: selected ? Colors.white : MarketPalette.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: MarketPalette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: MarketPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  color: selected ? MarketPalette.green : MarketPalette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNotes() {
    return _checkoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.edit_note_rounded,
            title: 'Sipariş notu',
            trailing: 'İsteğe bağlı',
          ),
          const SizedBox(height: 14),
          _modernTextField(
            controller: _notesController,
            label: 'Notun',
            hint: 'Örn. Kapıya geldiğinizde arayabilirsiniz.',
            icon: Icons.chat_bubble_outline_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSecureInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded,
              color: MarketPalette.greenDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sipariş bilgilerin yalnızca teslimat için kullanılır.',
              style: GoogleFonts.inter(
                color: MarketPalette.greenDark,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(CartViewModel cart) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: MarketPalette.line)),
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withOpacity(.08),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toplam',
                  style: GoogleFonts.inter(
                    color: MarketPalette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₺${cart.finalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    color: MarketPalette.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _createOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: MarketPalette.green,
                    disabledBackgroundColor: MarketPalette.greenSoft,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: MarketPalette.green,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Siparişi tamamla',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkoutCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MarketPalette.line),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withOpacity(.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MarketPalette.greenSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: MarketPalette.green, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              color: MarketPalette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          trailing,
          style: GoogleFonts.inter(
            color: MarketPalette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _priceLine(String label, double value, {bool highlight = false}) {
    final prefix = value < 0 ? '-₺' : '₺';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: highlight ? MarketPalette.green : MarketPalette.muted,
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$prefix${value.abs().toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            color: highlight ? MarketPalette.green : MarketPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        color: MarketPalette.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 54 : 0),
          child: Icon(icon, color: MarketPalette.green, size: 21),
        ),
        labelStyle: GoogleFonts.inter(color: MarketPalette.muted),
        hintStyle: GoogleFonts.inter(
          color: MarketPalette.muted.withOpacity(.7),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: MarketPalette.canvas,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: MarketPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: MarketPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: MarketPalette.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: MarketPalette.red),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool dark = false,
  }) {
    return Material(
      color: dark ? Colors.white.withOpacity(.13) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: dark ? Colors.white : MarketPalette.ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}
