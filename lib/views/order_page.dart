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
                          child: const Text('🎉', style: TextStyle(fontSize: 40)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                    style: TextStyle(fontSize: filled ? 36 : 32),
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
                              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                              prefixIcon: Icon(Icons.mode_comment_outlined, color: Colors.grey[400], size: 22),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            onPressed: submitting ? null : () async {
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
                                if (context.mounted) setState(() => submitting = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: submitting
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Gönder ve Devam Et', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Skip Button
                        TextButton(
                          onPressed: () => context.pop(false),
                          child: Text('Daha Sonra', style: GoogleFonts.poppins(color: Colors.grey[500], fontWeight: FontWeight.w500)),
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
      case 1: return '😞 Berbat';
      case 2: return '😕 Kötü';
      case 3: return '😐 Orta';
      case 4: return '😊 İyi';
      case 5: return '🤩 Mükemmel!';
      default: return '';
    }
  }
  
  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.lightGreen;
      case 5: return AppColors.successGreen;
      default: return Colors.grey;
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

      // Sipariş oluştur - Web projesindeki API formatına uygun
      final orderRequest = CreateOrderRequest(
        products: cartViewModel.items
            .map(
              (item) => {
                'product': item
                    .product
                    .id, // Web projesinde 'product' field'ı bekleniyor
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
            ? 'Kız KYK Yurdu'
            : 'Erkek KYK Yurdu',
        note: _notesController.text,
        couponCode: cartViewModel.appliedCouponCode, // Kupon kodu
        discountAmount: cartViewModel.discountAmount, // İndirim miktarı
        device: {
          'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown'),
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Sipariş Oluştur',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      body: Consumer<CartViewModel>(
        builder: (context, cartViewModel, child) {
          if (cartViewModel.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sepetiniz boş!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sipariş vermek için önce ürün ekleyin.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sipariş Özeti
                  _buildOrderSummary(cartViewModel),
                  const SizedBox(height: 24),

                  // Teslimat Noktası Seçimi
                  _buildDeliveryPointSelection(),
                  const SizedBox(height: 24),

                  // Sipariş Notu
                  _buildOrderNotes(),
                  const SizedBox(height: 32),

                  // Sipariş Oluştur Butonu
                  _buildOrderButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderSummary(CartViewModel cartViewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sipariş Özeti',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...cartViewModel.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '₺${item.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          // Ara Toplam
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ara Toplam',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '₺${cartViewModel.totalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          // Kupon İndirimi (varsa)
          if (cartViewModel.discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.discount, size: 16, color: AppColors.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Kupon (${cartViewModel.appliedCouponCode ?? ""})',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '-₺${cartViewModel.discountAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 8),
          // Toplam Tutar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplam Tutar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '₺${cartViewModel.finalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPointSelection() {
    return Consumer<SettingsViewModel>(
      builder: (context, settingsViewModel, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teslimat Noktası',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              if (settingsViewModel.girlsDormEnabled) ...[
                _buildDeliveryOption(
                  id: 'girlsDorm',
                  title: settingsViewModel.girlsDormName,
                  subtitle: 'Kız öğrenci yurdu teslimat noktası',
                  icon: Icons.apartment_rounded,
                ),
                const SizedBox(height: 12),
              ],

              if (settingsViewModel.boysDormEnabled) ...[
                _buildDeliveryOption(
                  id: 'boysDorm',
                  title: settingsViewModel.boysDormName,
                  subtitle: 'Erkek öğrenci yurdu teslimat noktası',
                  icon: Icons.apartment_rounded,
                ),
              ],

              if (!settingsViewModel.girlsDormEnabled &&
                  !settingsViewModel.boysDormEnabled)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aktif teslimat noktası bulunmuyor.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  hintText: '5XX XXX XX XX',
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.phone_iphone_rounded,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.successGreen,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Telefon numarası gerekli';
                  if (value.length < 10) return 'Geçerli bir numara giriniz';
                  return null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedDeliveryPoint == id;
    return InkWell(
      onTap: () => setState(() => _selectedDeliveryPoint = id),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.successGreen.withOpacity(0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.successGreen : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.successGreen.withOpacity(0.1)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.successGreen : Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.successGreen
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.successGreen,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderNotes() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sipariş Notu',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Siparişinizle ilgili eklemek istedikleriniz...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.successGreen,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.successGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Siparişi Tamamla',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
