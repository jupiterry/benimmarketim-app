import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/review_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/referral_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/community_campaign.dart';
import 'widgets/market_ui.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

/// Kullanılmamış kupon önerisi.
typedef _CouponSuggestion = ({String code, String detail});

enum _CouponChoice { apply, skip }

class _OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  String _selectedDeliveryPoint = '';
  bool _deliveryError = false;
  bool _feedbackSatisfied = false; // Bu oturumda geri bildirim verildi mi
  bool _couponReminderAnswered = false; // "Kuponsuz devam et" seçildi mi
  bool _campaignAnswered = false; // Topluluk indirimi sorusu yanıtlandı mı
  Map<String, dynamic>? _campaign;
  String _appVersion = '';

  static const _quickNotes = [
    'Gelince arayın',
    'Kapıda bekliyorum',
    'Poşet istemiyorum',
  ];

  @override
  void initState() {
    super.initState();
    // Önce profildeki (kayıtta girilen) numara gösterilir; kullanıcı daha
    // önce siparişte başka bir numara kullandıysa o numara tercih edilir.
    final user = context.read<AuthViewModel>().user;
    final profilePhone = user?.phone?.trim() ?? '';
    _phoneController.text = profilePhone;
    _restoreLastOrderPhone(user?.id ?? '', profilePhone);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReferralViewModel>().loadCoupons();
    });
    PackageInfo.fromPlatform().then((info) {
      _appVersion = info.version;
    }).catchError((_) {});
    ApiService().getActiveCouponRequestCampaign().then((campaign) {
      if (mounted) setState(() => _campaign = campaign);
    });
  }

  static String _lastPhoneKey(String userId) => 'last_order_phone_$userId';

  Future<void> _restoreLastOrderPhone(String userId, String shown) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lastPhoneKey(userId))?.trim() ?? '';
      // Kullanıcı bu arada yazmaya başladıysa alanına dokunulmaz.
      if (!mounted || saved.isEmpty || _phoneController.text != shown) return;
      _phoneController.text = saved;
    } catch (e) {
      AppLogger.debug('Son sipariş telefonu okunamadı: $e');
    }
  }

  Future<void> _rememberOrderPhone(String userId, String phone) async {
    if (userId.isEmpty || phone.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPhoneKey(userId), phone.trim());
    } catch (e) {
      AppLogger.debug('Son sipariş telefonu kaydedilemedi: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Kupon hatırlatma
  // -------------------------------------------------------------------------

  _CouponSuggestion? _unusedCoupon(
      CartViewModel cart, ReferralViewModel referral) {
    if (cart.appliedCouponCode != null) return null;
    final recommended = cart.recommendedCoupon;
    final recommendedCode = recommended?['code']?.toString();
    if (recommendedCode != null && recommendedCode.isNotEmpty) {
      final discount =
          (recommended?['calculatedDiscount'] as num?)?.toDouble() ?? 0;
      return (
        code: recommendedCode,
        detail: discount > 0
            ? '${formatTl(discount)} indirim'
            : 'Sepetine uygun kupon',
      );
    }
    for (final coupon in referral.validCoupons) {
      if (coupon.minimumOrderAmount <= cart.totalPrice) {
        return (code: coupon.code, detail: coupon.discountText);
      }
    }
    return null;
  }

  Future<_CouponChoice?> _showCouponReminder(_CouponSuggestion coupon) {
    return showModalBottomSheet<_CouponChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketPalette.canvas,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: MarketPalette.lineStrong,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                  ),
                ),
                const Center(
                  child: MarketIconTile(
                    icon: Icons.local_activity_rounded,
                    size: 64,
                    background: MarketPalette.lime,
                    foreground: MarketPalette.greenDeep,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kullanmadığın bir kuponun var',
                  textAlign: TextAlign.center,
                  style: MarketText.title(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Siparişini kuponsuz vermek üzeresin. Kuponu uygularsan bu siparişte tasarruf edersin.',
                  textAlign: TextAlign.center,
                  style: MarketText.body(color: MarketPalette.muted, size: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: MarketPalette.limeSoft,
                    borderRadius: BorderRadius.circular(MarketRadius.md),
                    border: Border.all(color: MarketPalette.limeLine),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          color: MarketPalette.greenDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(coupon.code,
                            style: MarketText.code(
                                color: MarketPalette.greenDeep, size: 16)),
                      ),
                      Text(coupon.detail,
                          style: MarketText.label(
                              color: MarketPalette.greenDark, size: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, _CouponChoice.apply),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Kuponu uygula'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, _CouponChoice.skip),
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.inkSoft,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Kuponsuz devam et'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyCoupon(CartViewModel cart, String code) async {
    final ok = await cart.applyCoupon(code);
    if (!mounted) return;
    if (ok) {
      showMarketSnack(
          context, 'Kupon uygulandı. Yeni tutarı kontrol edip siparişini ver.');
    } else {
      showMarketSnack(context, cart.couponError ?? 'Kupon uygulanamadı',
          error: true);
    }
  }

  // -------------------------------------------------------------------------
  // İlk sipariş geri bildirimi
  // -------------------------------------------------------------------------

  Future<bool?> _showFeedbackDialog(BuildContext context) async {
    int rating = 5;
    String message = '';
    bool submitting = false;
    const labels = ['Berbat', 'Kötü', 'Orta', 'İyi', 'Mükemmel!'];

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
                color: MarketPalette.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: MarketPalette.lineStrong,
                            borderRadius: BorderRadius.circular(MarketRadius.sm),
                          ),
                        ),
                      ),
                      const Center(
                        child: MarketIconTile(
                          icon: Icons.celebration_rounded,
                          size: 64,
                          background: MarketPalette.lime,
                          foreground: MarketPalette.greenDeep,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('İlk siparişin geliyor!',
                          textAlign: TextAlign.center,
                          style: MarketText.title(size: 22)),
                      const SizedBox(height: 6),
                      Text(
                        'Uygulamayı nasıl buldun? Puanın bizi geliştiriyor.',
                        textAlign: TextAlign.center,
                        style: MarketText.body(
                            color: MarketPalette.muted, size: 14),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final filled = index < rating;
                          return IconButton(
                            iconSize: 38,
                            tooltip: labels[index],
                            onPressed: () => setState(() => rating = index + 1),
                            icon: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: filled
                                  ? MarketPalette.orange
                                  : MarketPalette.lineStrong,
                            ),
                          );
                        }),
                      ),
                      Text(
                        labels[rating - 1],
                        textAlign: TextAlign.center,
                        style: MarketText.label(
                            color: MarketPalette.orangeInk, size: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        style: MarketText.body(size: 14),
                        decoration: const InputDecoration(
                          hintText: 'Düşüncelerini paylaş (isteğe bağlı)',
                          prefixIcon: Icon(Icons.mode_comment_outlined),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        onChanged: (v) => message = v,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
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
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54)),
                        child: submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Gönder ve devam et'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.pop(false),
                        style: TextButton.styleFrom(
                            foregroundColor: MarketPalette.muted),
                        child: const Text('Daha sonra'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showInfoDialog({
    required IconData icon,
    required String title,
    required String message,
    Color tint = MarketPalette.orangeInk,
    Color tintSoft = MarketPalette.orangeSoft,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: MarketIconTile(
            icon: icon, size: 54, background: tintSoft, foreground: tint),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sipariş oluşturma (akış önceki sürümle aynı; yalnızca görünüm ve kupon
  // hatırlatması eklendi)
  // -------------------------------------------------------------------------

  Future<void> _createOrder() async {
    AppLogger.debug('🛒 ORDER CREATION STARTED');

    // Giriş kontrolü - eğer giriş yapmamışsa login sayfasına yönlendir
    final authViewModel = context.read<AuthViewModel>();
    if (!authViewModel.isLoggedIn) {
      final result = await context.push<bool>('/login');

      // Login sayfasından döndüyse ve giriş yapıldıysa devam et
      if (result != true && !authViewModel.isLoggedIn) {
        return; // Giriş yapılmadı, sipariş verme işlemini durdur
      }
    }

    if (!mounted) return;

    if (_selectedDeliveryPoint.isEmpty) {
      setState(() => _deliveryError = true);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      showMarketSnack(context, 'Lütfen teslimat noktasını seç', error: true);
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      showMarketSnack(context, 'Lütfen telefon numaranı kontrol et',
          error: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsViewModel = context.read<SettingsViewModel>();

      // Sipariş saatleri kontrolü
      if (!settingsViewModel.isWithinOrderHours) {
        await _showInfoDialog(
          icon: Icons.schedule_rounded,
          title: 'Sipariş saatleri dışındayız',
          message: settingsViewModel.orderHoursMessage,
        );
        return;
      }

      // Tüm teslimat noktaları kapalı mı kontrolü
      if (!settingsViewModel.girlsDormEnabled &&
          !settingsViewModel.boysDormEnabled) {
        await _showInfoDialog(
          icon: Icons.store_mall_directory_outlined,
          title: 'Teslimat şu an kapalı',
          message:
              'Şu anda tüm teslimat noktaları kapalı. Lütfen daha sonra tekrar dene.',
          tint: MarketPalette.red,
          tintSoft: MarketPalette.redSoft,
        );
        return;
      }

      if (!mounted) return;
      final cartViewModel = context.read<CartViewModel>();
      final referralViewModel = context.read<ReferralViewModel>();

      if (cartViewModel.items.isEmpty) {
        await _showInfoDialog(
          icon: Icons.shopping_cart_outlined,
          title: 'Sepetin boş',
          message: 'Sipariş vermek için önce sepetine ürün ekle.',
        );
        return;
      }

      // Minimum sipariş tutarı kontrolü (API'den gelen değer)
      final minimumOrderAmount = settingsViewModel.minimumOrderAmount;
      if (cartViewModel.totalPrice < minimumOrderAmount) {
        final eksikTutar = minimumOrderAmount - cartViewModel.totalPrice;
        showMarketSnack(
          context,
          'Minimum sipariş tutarı ${formatTlShort(minimumOrderAmount)}. Sipariş için ${formatTl(eksikTutar)} daha ürün eklemelisin.',
          error: true,
        );
        return;
      }

      // Kullanılmamış kupon hatırlatması (son çıkıştan önce bir kez)
      if (!_couponReminderAnswered) {
        final suggestion = _unusedCoupon(cartViewModel, referralViewModel);
        if (suggestion != null) {
          setState(() => _isLoading = false);
          final choice = await _showCouponReminder(suggestion);
          if (!mounted) return;
          if (choice == _CouponChoice.apply) {
            await _applyCoupon(cartViewModel, suggestion.code);
            return; // Kullanıcı yeni tutarı görüp tekrar onaylar.
          }
          if (choice != _CouponChoice.skip) return; // Sayfa kapatıldı
          _couponReminderAnswered = true;
          setState(() => _isLoading = true);
        }
      }

      // Şartı sağlıyor ama topluluk indirimine katılmamışsa bir kez sor.
      if (!_campaignAnswered && CommunityCampaign.canJoin(_campaign)) {
        setState(() => _isLoading = false);
        final join = await CommunityCampaign.askToJoin(context, _campaign!);
        if (!mounted) return;
        if (join == null) return; // Sayfa kapatıldı
        _campaignAnswered = true;
        if (join) {
          final updated = await CommunityCampaign.join(context);
          if (updated != null) _campaign = updated;
        }
        if (!mounted) return;
        setState(() => _isLoading = true);
      }

      final couponIsValid = await cartViewModel
          .validateCouponForDeliveryPoint(_selectedDeliveryPoint);
      if (!couponIsValid) {
        if (mounted) {
          showMarketSnack(
            context,
            cartViewModel.couponError ??
                'Kupon seçilen teslimat noktasında kullanılamıyor.',
            error: true,
          );
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
          'appVersion': _appVersion,
        },
      );

      // Kişisel veri (telefon, adres, not) ve kupon kodu loglanmaz.
      AppLogger.debug(
        'Order request: products=${orderRequest.products.length}, '
        'total=${orderRequest.totalAmount}, '
        'discount=${orderRequest.discountAmount}',
      );

      final apiService = ApiService();

      // İlk sipariş geri bildirim guard'ı (oturum içi hafıza ile)
      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      final currentUserId = auth.user?.id ?? '';
      if (currentUserId.isNotEmpty && !_feedbackSatisfied) {
        final hasFeedback = await apiService.hasUserGivenFeedback(
          currentUserId,
        );
        if (!hasFeedback) {
          if (!mounted) return;
          final ok = await _showFeedbackDialog(context);
          if (ok == true) {
            _feedbackSatisfied = true; // tekrar sorma
          } else {
            return;
          }
        } else {
          _feedbackSatisfied = true;
        }
      }

      final order = await apiService.createOrder(orderRequest);

      // Bir sonraki siparişte bu numara hazır gelsin; profil de sunucudaki
      // güncel numarayla yenilenir.
      await _rememberOrderPhone(currentUserId, orderRequest.phone);
      auth.updateProfile();

      // Sepeti temizle
      cartViewModel.clearCart();

      // Kupon, sipariş başarıyla kaydedildiğinde sunucuda atomik olarak
      // tüketilir. Cüzdanı zorla yenilemek eski kuponun ana sayfa/sepet
      // bannerında yeniden görünmesini engeller.
      await referralViewModel.refreshCouponsAfterOrder();

      // Değerlendirme servisi hatası başarılı siparişi başarısız göstermemeli.
      try {
        await ReviewService.instance.onOrderCompleted();
      } catch (e) {
        AppLogger.debug('Order review unavailable: $e');
      }

      AppLogger.debug('Order ID: ${order.id}');

      if (mounted) {
        context.go('/order-confirmation/${order.id}');
      }
    } catch (e) {
      String detailedError = '';

      if (e is DioException) {
        if (e.response != null) {
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

      if (mounted) {
        await _showInfoDialog(
          icon: Icons.error_outline_rounded,
          title: 'Sipariş oluşturulamadı',
          message: detailedError.isNotEmpty
              ? detailedError
              : 'Bir sorun oluştu. Lütfen bağlantını kontrol edip tekrar dene.',
          tint: MarketPalette.red,
          tintSoft: MarketPalette.redSoft,
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

  // -------------------------------------------------------------------------
  // Görünüm
  // -------------------------------------------------------------------------

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
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const MarketScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: MarketHeader(
                    title: 'Siparişi tamamla',
                    subtitle:
                        '${cart.totalItems} ürün • Teslimat bilgilerini seç ve onayla',
                    icon: Icons.receipt_long_rounded,
                    compact: true,
                    bottom: const _CheckoutSteps(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      _buildDeliverySection(),
                      const SizedBox(height: 14),
                      _buildContactSection(),
                      const SizedBox(height: 14),
                      _buildNotesSection(),
                      const SizedBox(height: 14),
                      _buildCouponSection(cart),
                      _buildSummarySection(cart),
                      const SizedBox(height: 14),
                      const MarketNotice(
                        icon: Icons.verified_user_rounded,
                        text:
                            'Sipariş bilgilerin yalnızca teslimat için kullanılır.',
                      ),
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
      body: Column(
        children: [
          const MarketHeader(
            title: 'Siparişi tamamla',
            icon: Icons.receipt_long_rounded,
            compact: true,
          ),
          Expanded(
            child: MarketEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Sepetin şu an boş',
              message: 'Siparişini oluşturmak için birkaç ürün seçmen yeterli.',
              actionLabel: 'Ürünleri keşfet',
              actionIcon: Icons.explore_rounded,
              onAction: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String step,
    required String title,
    String? trailing,
    required Widget child,
    bool error = false,
  }) {
    return MarketCard(
      borderColor: error ? MarketPalette.red : MarketPalette.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MarketPalette.greenDeep,
                  shape: BoxShape.circle,
                ),
                child: Text(step,
                    style: MarketText.label(color: Colors.white, size: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: MarketText.heading(size: 16))),
              if (trailing != null) Text(trailing, style: MarketText.caption()),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Consumer<SettingsViewModel>(
      builder: (context, settings, child) {
        return _section(
          step: '1',
          title: 'Teslimat noktası',
          trailing: 'Zonguldak',
          error: _deliveryError,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settings.girlsDormEnabled)
                _buildDeliveryOption(
                  id: 'girlsDorm',
                  title: settings.girlsDormName,
                  subtitle: 'Kız öğrenci yurdu teslimat noktası',
                ),
              if (settings.girlsDormEnabled && settings.boysDormEnabled)
                const SizedBox(height: 10),
              if (settings.boysDormEnabled)
                _buildDeliveryOption(
                  id: 'boysDorm',
                  title: settings.boysDormName,
                  subtitle: 'Erkek öğrenci yurdu teslimat noktası',
                ),
              if (!settings.girlsDormEnabled && !settings.boysDormEnabled)
                const MarketNotice(
                  icon: Icons.info_outline_rounded,
                  text: 'Şu anda aktif teslimat noktası bulunmuyor.',
                  background: MarketPalette.redSoft,
                  foreground: MarketPalette.red,
                ),
              if (_deliveryError) ...[
                const SizedBox(height: 10),
                Text(
                  'Devam etmek için bir teslimat noktası seç.',
                  style: MarketText.caption(
                      color: MarketPalette.red, weight: FontWeight.w700),
                ),
              ],
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
  }) {
    final selected = _selectedDeliveryPoint == id;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title teslimat noktasını seç',
      child: InkWell(
        onTap: () => setState(() {
          _selectedDeliveryPoint = id;
          _deliveryError = false;
        }),
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? MarketPalette.greenSoft : MarketPalette.canvas,
            borderRadius: BorderRadius.circular(MarketRadius.md),
            border: Border.all(
              color: selected ? MarketPalette.green : MarketPalette.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              MarketIconTile(
                icon: Icons.apartment_rounded,
                size: 44,
                background: selected ? MarketPalette.green : Colors.white,
                foreground: selected ? Colors.white : MarketPalette.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MarketText.label(size: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: MarketText.caption()),
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
                  color: selected ? MarketPalette.green : MarketPalette.subtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return _section(
      step: '2',
      title: 'İletişim',
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        style: MarketText.label(size: 16, weight: FontWeight.w600),
        decoration: const InputDecoration(
          labelText: 'Telefon numarası',
          hintText: '5XX XXX XX XX',
          helperText: 'Kurye teslimatta bu numaradan ulaşır',
          prefixIcon:
              Icon(Icons.phone_iphone_rounded, color: MarketPalette.green),
          fillColor: MarketPalette.canvas,
        ),
        validator: (value) {
          final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
          if (phone.isEmpty) return 'Telefon numarası gerekli';
          if (phone.length < 10) return 'Geçerli bir numara gir';
          return null;
        },
      ),
    );
  }

  Widget _buildNotesSection() {
    return _section(
      step: '3',
      title: 'Sipariş notu',
      trailing: 'İsteğe bağlı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final note in _quickNotes)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded,
                      size: 16, color: MarketPalette.greenDark),
                  label: Text(note),
                  onPressed: () {
                    final current = _notesController.text.trim();
                    if (current.contains(note)) return;
                    _notesController.text =
                        current.isEmpty ? note : '$current. $note';
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            style: MarketText.body(size: 14),
            decoration: const InputDecoration(
              hintText: 'Örn. kapıya gelince arayabilirsiniz',
              fillColor: MarketPalette.canvas,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(CartViewModel cart) {
    final referral = context.watch<ReferralViewModel>();
    final applied = cart.appliedCouponCode;
    final suggestion = _unusedCoupon(cart, referral);
    if (applied == null && suggestion == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: applied != null
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
              decoration: BoxDecoration(
                color: MarketPalette.greenSoft,
                borderRadius: BorderRadius.circular(MarketRadius.lg),
                border: Border.all(color: MarketPalette.greenLine),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: MarketPalette.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applied, style: MarketText.code(size: 14)),
                        Text(
                          '${formatTl(cart.discountAmount)} indirim uygulandı',
                          style: MarketText.caption(
                              color: MarketPalette.greenDark),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: cart.removeCoupon,
                    style: TextButton.styleFrom(
                        foregroundColor: MarketPalette.red),
                    child: const Text('Kaldır'),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MarketPalette.limeSoft, MarketPalette.greenSoft],
                ),
                borderRadius: BorderRadius.circular(MarketRadius.lg),
                border: Border.all(color: MarketPalette.limeLine),
              ),
              child: Row(
                children: [
                  const MarketIconTile(
                    icon: Icons.local_activity_rounded,
                    size: 40,
                    background: MarketPalette.lime,
                    foreground: MarketPalette.greenDeep,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kullanılabilir kuponun var',
                          style: MarketText.caption(
                              color: MarketPalette.greenDark,
                              weight: FontWeight.w700),
                        ),
                        Text(suggestion!.code,
                            style: MarketText.code(
                                color: MarketPalette.greenDeep, size: 13)),
                        Text(suggestion.detail,
                            style: MarketText.caption(
                                color: MarketPalette.inkSoft)),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: cart.isValidatingCoupon
                        ? null
                        : () => _applyCoupon(cart, suggestion.code),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: MarketPalette.greenDeep,
                    ),
                    child: const Text('Uygula'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection(CartViewModel cart) {
    final productSavings = cart.items.fold<double>(0, (sum, item) {
      final diff = item.product.price - item.product.actualPrice;
      return diff > 0 ? sum + diff * item.quantity : sum;
    });

    return _section(
      step: '4',
      title: 'Sipariş özeti',
      trailing: '${cart.items.length} çeşit',
      child: Column(
        children: [
          for (final item in cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: MarketPalette.canvas,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                    child: item.product.image.isEmpty
                        ? const Icon(Icons.inventory_2_outlined,
                            color: MarketPalette.subtle, size: 20)
                        : Image.network(
                            item.product.image,
                            fit: BoxFit.contain,
                            cacheWidth: 120,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              color: MarketPalette.subtle,
                              size: 20,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.label(
                              size: 13, weight: FontWeight.w600),
                        ),
                        Text(
                          '${item.quantity} adet × ${formatTl(item.product.actualPrice)}',
                          style: MarketText.caption(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatTl(item.totalPrice),
                      style: MarketText.label(size: 13)),
                ],
              ),
            ),
          const Divider(height: 18),
          _priceLine(
              'Ürünler (${cart.totalItems})', cart.totalPrice + productSavings),
          if (productSavings > 0)
            _priceLine('Ürün indirimleri', -productSavings, highlight: true),
          if (cart.discountAmount > 0)
            _priceLine(
                'Kupon (${cart.appliedCouponCode ?? ''})', -cart.discountAmount,
                highlight: true),
          _priceLine('Teslimat', null, text: 'Ücretsiz', highlight: true),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                  child: Text('Ödenecek tutar',
                      style: MarketText.heading(size: 16))),
              Text(formatTl(cart.finalPrice),
                  style: MarketText.price(
                      color: MarketPalette.greenDark, size: 22)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(CartViewModel cart) {
    final savings = cart.items.fold<double>(0, (sum, item) {
          final diff = item.product.price - item.product.actualPrice;
          return diff > 0 ? sum + diff * item.quantity : sum;
        }) +
        cart.discountAmount;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: MarketPalette.line)),
          boxShadow: [
            BoxShadow(
              color: MarketPalette.greenDeep.withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ödenecek', style: MarketText.caption()),
                Text(formatTl(cart.finalPrice),
                    style: MarketText.price(size: 22)),
                if (savings > 0)
                  Text(
                    '${formatTl(savings)} kazanç',
                    style: MarketText.caption(
                        color: MarketPalette.green, weight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _createOrder,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Siparişi ver'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceLine(String label, double? value,
      {bool highlight = false, String? text}) {
    final color = highlight ? MarketPalette.green : MarketPalette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style:
                      MarketText.body(color: MarketPalette.muted, size: 13))),
          Text(
            text ?? formatTl(value ?? 0),
            style: MarketText.label(
                color: highlight ? color : MarketPalette.ink, size: 13),
          ),
        ],
      ),
    );
  }
}

/// Sepet ✓ → Teslimat → Onay
class _CheckoutSteps extends StatelessWidget {
  const _CheckoutSteps();

  @override
  Widget build(BuildContext context) {
    Widget step(String label, {required bool done, required bool active}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done
                  ? MarketPalette.lime
                  : active
                      ? Colors.white
                      : Colors.white.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 14, color: MarketPalette.greenDeep)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: MarketText.label(
              color: Colors.white.withValues(alpha: done || active ? 1 : .6),
              size: 12,
              weight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      );
    }

    Widget connector() => Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: .2),
          ),
        );

    return Row(
      children: [
        step('Sepet', done: true, active: false),
        connector(),
        step('Teslimat', done: false, active: true),
        connector(),
        step('Onay', done: false, active: false),
      ],
    );
  }
}
