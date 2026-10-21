import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/meta_app_events_service.dart';
import '../services/notification_service.dart';
import '../services/review_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/home_page_viewmodel.dart';
import '../viewmodels/referral_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/bank_transfer_card.dart';
import 'widgets/community_campaign.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/first_order_rating.dart';
import 'widgets/market_ui.dart';
import '../services/image_url.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

/// Kullanılmamış kupon önerisi. [best]: sunucunun sepete özel önerisi.
typedef _CouponSuggestion = ({String code, String detail, bool best});

enum _CouponChoice { apply, skip }

class _OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _submitting = false; // Çift dokunuşla iki sipariş gitmesin
  bool _orderPlaced = false; // Sipariş kaydedildi, onay ekranına geçiliyor
  String _selectedDeliveryPoint = '';
  bool _deliveryTouched = false; // Kullanıcı yurdu kendisi seçti mi
  String? _rememberedDeliveryPoint; // Son siparişte seçilen yurt
  bool _deliveryFromHistory = false; // Seçim son siparişten mi geldi
  bool _deliveryError = false;
  PaymentMethod? _selectedPaymentMethod; // Zorunlu: nakit, POS ya da havale/EFT
  bool _paymentError = false;
  bool _phoneValid = false;
  final _contactSectionKey = GlobalKey();
  final _paymentSectionKey = GlobalKey();
  bool _couponReminderAnswered = false; // "Kuponsuz devam et" seçildi mi
  bool _campaignAnswered = false; // Topluluk indirimi sorusu yanıtlandı mı
  bool _joiningCampaign = false;
  Map<String, dynamic>? _campaign;
  String _appVersion = '';

  /// Kullanıcı daha önce geri bildirim verdi mi? Sayfa açılırken (beklemeden)
  /// sorulur; sipariş hiçbir zaman bu yanıtı ya da bir puan penceresini
  /// beklemez. Sonuç yalnızca onay ekranındaki ilk sipariş puan kartı içindir.
  Future<bool>? _hasFeedbackFuture;

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
    _phoneValid = _isPhoneValid(profilePhone);
    _phoneController.addListener(_onPhoneChanged);
    _restoreLastOrderPhone(user?.id ?? '', profilePhone);
    _restoreLastDeliveryPoint(user?.id ?? '');
    _startFeedbackCheck(user?.id ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReferralViewModel>().loadCoupons();
      // Bildirim izni (yalnızca bir kez sorulur): sipariş durumu bildirimleri
      // için en anlamlı yer burası.
      unawaited(NotificationService.instance.requestPermissionIfNeeded());
    });
    PackageInfo.fromPlatform().then((info) {
      _appVersion = info.version;
    }).catchError((_) {});
    ApiService().getActiveCouponRequestCampaign().then((campaign) {
      if (mounted) setState(() => _campaign = campaign);
    });
  }

  static String _lastPhoneKey(String userId) => 'last_order_phone_$userId';

  /// Hazır seçim için kullanıcıya özel son yurt. Ortak anahtar
  /// ([lastDeliveryPointPrefsKey]) cihazdaki herkesin son siparişidir; o
  /// yalnızca ana sayfa önerilerinde kullanılır.
  static String _lastPointKey(String userId) => 'last_delivery_point_$userId';

  static bool _isPhoneValid(String value) =>
      value.replaceAll(RegExp(r'\D'), '').length >= 10;

  void _onPhoneChanged() {
    final valid = _isPhoneValid(_phoneController.text);
    if (valid != _phoneValid && mounted) setState(() => _phoneValid = valid);
  }

  void _startFeedbackCheck(String userId) {
    if (_hasFeedbackFuture != null || userId.isEmpty) return;
    // Hata "geri bildirim var" sayılır: emin olmadığımızda kart gösterilmez.
    _hasFeedbackFuture = ApiService()
        .hasUserGivenFeedback(userId)
        .catchError((Object _) => true);
  }

  /// Sipariş başarıyla kaydedildikten sonra çağrılır: kullanıcı hiç geri
  /// bildirim vermediyse onay ekranı ilk sipariş puan kartını gösterir.
  /// En fazla 800 ms beklenir; yanıt gelmezse kart gösterilmez.
  Future<void> _markFirstOrderRating() async {
    final check = _hasFeedbackFuture;
    if (check == null) {
      FirstOrderRating.pending = false;
      return;
    }
    try {
      final hasFeedback = await check.timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => true,
      );
      FirstOrderRating.pending = !hasFeedback;
    } catch (_) {
      FirstOrderRating.pending = false;
    }
  }

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

  /// Bu kullanıcının son siparişinde seçtiği yurt ödeme ekranında hazır
  /// seçili gelir (aynı telefondaki başka hesabın seçimi gelmez).
  Future<void> _restoreLastDeliveryPoint(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lastPointKey(userId)) ?? '';
      if (!mounted || saved.isEmpty) return;
      setState(() => _rememberedDeliveryPoint = saved);
    } catch (e) {
      AppLogger.debug('Son teslimat noktası okunamadı: $e');
    }
  }

  static bool _isDeliveryEnabled(SettingsViewModel settings, String id) =>
      switch (id) {
        'girlsDorm' => settings.girlsDormEnabled,
        'boysDorm' => settings.boysDormEnabled,
        _ => false,
      };

  /// Kullanıcı henüz seçmediyse varsayılan teslimat noktası: son siparişteki
  /// yurt (hâlâ açıksa) ya da açık olan tek yurt.
  void _applyDefaultDelivery(SettingsViewModel settings) {
    if (_deliveryTouched || _selectedDeliveryPoint.isNotEmpty) return;
    final remembered = _rememberedDeliveryPoint;
    String? pick;
    if (remembered != null && _isDeliveryEnabled(settings, remembered)) {
      pick = remembered;
      _deliveryFromHistory = true;
    } else if (settings.girlsDormEnabled != settings.boysDormEnabled) {
      pick = settings.girlsDormEnabled ? 'girlsDorm' : 'boysDorm';
    }
    if (pick == null) return;
    _selectedDeliveryPoint = pick;
    final point = pick;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revalidateCouponFor(point);
    });
  }

  void _selectDelivery(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _deliveryFromHistory =
          _deliveryFromHistory && id == _selectedDeliveryPoint;
      _selectedDeliveryPoint = id;
      _deliveryTouched = true;
      _deliveryError = false;
    });
    _revalidateCouponFor(id);
  }

  /// Teslimat noktasına özel kuponun indirimi nokta seçilince hemen
  /// hesaplanır (siparişte yapılan doğrulamanın aynısı; o yine yapılır).
  /// Önceki doğrulama sürerken başka yurt seçilirse yine sorulur; ekranda
  /// son seçilen noktanın sonucu kalır.
  void _revalidateCouponFor(String deliveryPoint) {
    final cart = context.read<CartViewModel>();
    if (cart.appliedCoupon?['requiresDeliveryPoint'] != true) return;
    unawaited(cart.validateCouponForDeliveryPoint(deliveryPoint));
  }

  Future<void> _rememberDeliveryPoint(
      String userId, String deliveryPoint) async {
    if (deliveryPoint.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastDeliveryPointPrefsKey, deliveryPoint);
      if (userId.isNotEmpty) {
        await prefs.setString(_lastPointKey(userId), deliveryPoint);
      }
    } catch (_) {
      // İsteğe bağlı; sipariş akışını etkilemez
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
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: .1,
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home', extra: <String, dynamic>{'initialTabIndex': 1});
    }
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
        best: true,
      );
    }
    for (final coupon in referral.validCoupons) {
      if (coupon.minimumOrderAmount <= cart.totalPrice) {
        return (code: coupon.code, detail: coupon.discountText, best: false);
      }
    }
    return null;
  }

  Future<_CouponChoice?> _showCouponReminder(_CouponSuggestion coupon) {
    final couponBox = Container(
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
                style: MarketText.code(color: MarketPalette.greenDeep, size: 16)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(coupon.detail,
                textAlign: TextAlign.right,
                style: MarketText.label(color: MarketPalette.greenDark, size: 13)),
          ),
        ],
      ),
    );
    return showMarketSheet<_CouponChoice>(
      context,
      builder: (sheetContext) => MarketPromptSheet(
        icon: Icons.local_activity_rounded,
        title: 'Kullanmadığın bir kuponun var',
        message:
            'Siparişini kuponsuz vermek üzeresin. Kuponu uygularsan bu siparişte tasarruf edersin.',
        primaryLabel: 'Kuponu uygula',
        primaryIcon: Icons.check_rounded,
        onPrimary: () => Navigator.pop(sheetContext, _CouponChoice.apply),
        secondaryLabel: 'Kuponsuz devam et',
        onSecondary: () => Navigator.pop(sheetContext, _CouponChoice.skip),
        child: couponBox,
      ),
    );
  }

  Future<void> _applyCoupon(CartViewModel cart, String code) async {
    final ok = await cart.applyCoupon(code);
    if (!mounted) return;
    if (ok) {
      showMarketSnack(
          context, 'Kupon uygulandı. Yeni tutarı kontrol edip siparişini ver.');
      // Teslimat noktasına özel kuponun indirimi seçili noktaya göre hesaplanır.
      if (_selectedDeliveryPoint.isNotEmpty) {
        _revalidateCouponFor(_selectedDeliveryPoint);
      }
    } else {
      showMarketSnack(context, cart.couponError ?? 'Kupon uygulanamadı',
          error: true);
    }
  }

  /// Sipariş öncesi bir pencere kapatıldıysa sipariş verilmez; kullanıcı
  /// bunu sessizce değil, bir bildirimle öğrenir.
  void _notifyNotPlaced() {
    showMarketSnack(
      context,
      'Siparişin henüz verilmedi. Hazır olduğunda tekrar dokun.',
      icon: Icons.info_outline_rounded,
    );
  }

  Future<void> _showInfoDialog({
    required IconData icon,
    required String title,
    required String message,
    MarketTone tone = MarketTone.brand,
  }) {
    return showMarketDialog<void>(
      context,
      builder: (dialogContext) => CustomDialog(
        title: title,
        message: message,
        icon: icon,
        tone: tone,
        confirmButtonText: 'Tamam',
        cancelButtonText: '',
        showCancelButton: false,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sipariş oluşturma (akış önceki sürümle aynı; yalnızca görünüm ve kupon
  // hatırlatması eklendi)
  // -------------------------------------------------------------------------

  Future<void> _createOrder() async {
    if (_submitting) return;
    _submitting = true;
    try {
      await _placeOrder();
    } finally {
      _submitting = false;
    }
  }

  Future<void> _placeOrder() async {
    AppLogger.debug('🛒 ORDER CREATION STARTED');

    // Giriş kontrolü - eğer giriş yapmamışsa login sayfasına yönlendir
    final authViewModel = context.read<AuthViewModel>();
    if (!authViewModel.isLoggedIn) {
      final result = await context.push<bool>('/login');

      // Login sayfasından döndüyse ve giriş yapıldıysa devam et
      if (result != true && !authViewModel.isLoggedIn) {
        return; // Giriş yapılmadı, sipariş verme işlemini durdur
      }
      _startFeedbackCheck(authViewModel.user?.id ?? '');
    }

    if (!mounted) return;

    if (_selectedDeliveryPoint.isEmpty) {
      setState(() => _deliveryError = true);
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      showMarketSnack(context, 'Lütfen teslimat noktasını seç', error: true);
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollTo(_contactSectionKey);
      showMarketSnack(context, 'Lütfen telefon numaranı kontrol et',
          error: true);
      return;
    }

    if (_selectedPaymentMethod == null) {
      setState(() => _paymentError = true);
      _scrollTo(_paymentSectionKey);
      showMarketSnack(context, 'Lütfen ödeme yöntemini seç', error: true);
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
          tone: MarketTone.danger,
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
          if (choice != _CouponChoice.skip) {
            _notifyNotPlaced(); // Sayfa kapatıldı
            return;
          }
          _couponReminderAnswered = true;
          setState(() => _isLoading = true);
        }
      }

      // Şartı sağlıyor ama topluluk indirimine katılmamışsa bir kez sor
      // (sayfadaki kartla zaten yanıtladıysa sorulmaz).
      if (!_campaignAnswered && CommunityCampaign.canJoin(_campaign)) {
        setState(() => _isLoading = false);
        final join = await CommunityCampaign.askToJoin(context, _campaign!);
        if (!mounted) return;
        if (join == null) {
          _notifyNotPlaced(); // Sayfa kapatıldı
          return;
        }
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
        paymentMethod: _selectedPaymentMethod!,
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

      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      final currentUserId = auth.user?.id ?? '';

      final order = await apiService.createOrder(orderRequest);
      // Sepet aşağıda temizlenince "Sepetin boş" yerine kısa bir geçiş
      // ekranı görünür (onay ekranına geçene kadar).
      _orderPlaced = true;
      final orderTotal =
          order.totalAmount > 0 ? order.totalAmount : orderRequest.totalAmount;

      // Meta Purchase: yalnızca sunucu siparişi kaydettikten sonra, sepet
      // temizlenmeden önceki ürünlerle ve sipariş numarası başına bir kez.
      // Ölçüm hatası sipariş akışını etkilemez.
      unawaited(MetaAppEventsService.instance.logPurchase(
        orderId: order.id,
        items: List.of(cartViewModel.items),
        amount: orderTotal,
      ));

      // Bir sonraki siparişte bu numara hazır gelsin; profil de sunucudaki
      // güncel numarayla yenilenir.
      await _rememberOrderPhone(currentUserId, orderRequest.phone);
      // Ana sayfa önerileri yurda göre istenir (Kız/Erkek KYK)
      await _rememberDeliveryPoint(currentUserId, orderRequest.deliveryPoint);
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

      // İlk sipariş puan kartı (onay ekranında, siparişi engellemeden).
      await _markFirstOrderRating();

      AppLogger.debug('Order ID: ${order.id}');

      if (mounted) {
        // Ödeme yöntemi, tutar ve teslimat noktası onay ekranında gösterilir
        // (havale/EFT ise IBAN ve havale edilecek tutar).
        final payment =
            (order.paymentMethod ?? orderRequest.paymentMethod).key;
        final point = Uri.encodeQueryComponent(orderRequest.deliveryPointName);
        context.go(
          '/order-confirmation/${order.id}?payment=$payment'
          '&total=${orderTotal.toStringAsFixed(2)}&point=$point',
        );
      }
    } catch (e) {
      // Geçiş ekranında takılı kalınmaz (önceki davranış korunur).
      _orderPlaced = false;
      String detailedError = '';

      if (e is ApiException) {
        // Sunucunun anlaşılır mesajı (sipariş saatleri, minimum tutar, kupon)
        detailedError = e.message;
      } else if (e is DioException) {
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
          tone: MarketTone.danger,
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
    final settings = context.watch<SettingsViewModel>();
    return Consumer<CartViewModel>(
      builder: (context, cart, child) {
        if (_orderPlaced) return _buildPlacingPage();
        if (cart.items.isEmpty) return _buildEmptyOrderPage();
        _applyDefaultDelivery(settings);
        final gutter = MarketSpace.gutterOf(context);

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
                    compact: true,
                    onBack: _back,
                    bottom: _CheckoutSteps(itemCount: cart.totalItems),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
                  sliver: SliverList.list(
                    children: [
                      ..._buildAvailabilityNotices(settings),
                      _buildDeliverySection(settings),
                      const SizedBox(height: 14),
                      _buildContactSection(),
                      const SizedBox(height: 14),
                      _buildPaymentSection(settings, cart),
                      const SizedBox(height: 14),
                      _buildNotesSection(),
                      const SizedBox(height: 14),
                      _buildCouponSection(cart),
                      _buildSummarySection(cart),
                      _buildCampaignCard(),
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

  /// Sipariş kaydedildikten sonra onay ekranına geçerken (sepet temizlenmiş,
  /// kuponlar yenileniyor) gösterilen geçiş ekranı.
  Widget _buildPlacingPage() {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: MarketPalette.green),
              ),
              const SizedBox(height: 16),
              Text('Siparişin tamamlanıyor…',
                  style: MarketText.label(size: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrderPage() {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Column(
        children: [
          MarketHeader(
            title: 'Siparişi tamamla',
            compact: true,
            onBack: _back,
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

  /// Mağaza kapalıyken ya da hiç teslimat noktası açık değilken kullanıcı bunu
  /// formu doldurmadan, sayfanın en üstünde görür. Sipariş anındaki
  /// kontroller yine yapılır.
  List<Widget> _buildAvailabilityNotices(SettingsViewModel settings) {
    return [
      if (!settings.isWithinOrderHours)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MarketNotice.warning(
            icon: Icons.schedule_rounded,
            text: 'Şu an sipariş alamıyoruz. ${settings.orderHoursMessage}.',
          ),
        ),
      if (!settings.girlsDormEnabled && !settings.boysDormEnabled)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: MarketNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Şu anda aktif teslimat noktası bulunmuyor. Lütfen daha sonra tekrar dene.',
            background: MarketPalette.redSoft,
            foreground: MarketPalette.red,
          ),
        ),
    ];
  }

  Widget _section({
    required String step,
    IconData? stepIcon,
    bool done = false,
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
              _StepBadge(step: step, icon: stepIcon, done: done),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: MarketText.heading(size: 16)),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(trailing, style: MarketText.caption()),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDeliverySection(SettingsViewModel settings) {
    final options = <Widget>[
      if (settings.girlsDormEnabled)
        _buildDeliveryOption(
          id: 'girlsDorm',
          title: settings.girlsDormName,
          subtitle: 'Kız öğrenci yurdu teslimat noktası',
        ),
      if (settings.boysDormEnabled)
        _buildDeliveryOption(
          id: 'boysDorm',
          title: settings.boysDormName,
          subtitle: 'Erkek öğrenci yurdu teslimat noktası',
        ),
    ];
    return _section(
      step: '1',
      done: _selectedDeliveryPoint.isNotEmpty,
      title: 'Teslimat noktası',
      trailing: 'Zorunlu',
      error: _deliveryError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            options[i],
          ],
          if (options.isEmpty)
            Text(
              'Teslimat noktaları açılınca burada görünecek.',
              style: MarketText.caption(size: 13),
            ),
          if (_deliveryFromHistory && _selectedDeliveryPoint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 16, color: MarketPalette.greenDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Son siparişinde bunu seçmiştin',
                    style: MarketText.caption(
                        color: MarketPalette.greenDark,
                        weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
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
  }

  /// Teslimat ve ödeme seçenekleri için ortak seçilebilir satır.
  Widget _choiceTile({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: AnimatedContainer(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
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
                icon: icon,
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
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
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

  Widget _buildDeliveryOption({
    required String id,
    required String title,
    required String subtitle,
  }) {
    return _choiceTile(
      selected: _selectedDeliveryPoint == id,
      icon: Icons.apartment_rounded,
      title: title,
      subtitle: subtitle,
      semanticsLabel: '$title teslimat noktası',
      onTap: () => _selectDelivery(id),
    );
  }

  Widget _buildContactSection() {
    return KeyedSubtree(
      key: _contactSectionKey,
      child: _section(
        step: '2',
        done: _phoneValid,
        title: 'İletişim',
        trailing: 'Zorunlu',
        child: TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          style: MarketText.label(size: 16, weight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'Telefon numarası',
            hintText: '5XX XXX XX XX',
            helperText: 'Kurye teslimatta bu numaradan ulaşır',
            helperMaxLines: 2,
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
      ),
    );
  }

  // Ödeme yöntemi (zorunlu). Ödeme teslimatta ya da havale/EFT ile alınır;
  // seçim yönetim panelinde sipariş kartında görünür.
  Widget _buildPaymentSection(SettingsViewModel settings, CartViewModel cart) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return KeyedSubtree(
      key: _paymentSectionKey,
      child: _section(
        step: '3',
        done: _selectedPaymentMethod != null,
        title: 'Ödeme yöntemi',
        trailing: 'Zorunlu',
        error: _paymentError,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final method in PaymentMethod.values) ...[
              if (method != PaymentMethod.values.first)
                const SizedBox(height: 10),
              _buildPaymentOption(method),
            ],
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _selectedPaymentMethod == PaymentMethod.bankTransfer
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: BankTransferCard(
                        settings: settings,
                        amount: cart.finalPrice,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_paymentError) ...[
              const SizedBox(height: 10),
              Text(
                'Devam etmek için bir ödeme yöntemi seç.',
                style: MarketText.caption(
                    color: MarketPalette.red, weight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _paymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_rounded;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildPaymentOption(PaymentMethod method) {
    return _choiceTile(
      selected: _selectedPaymentMethod == method,
      icon: _paymentIcon(method),
      title: method.label,
      subtitle: method.description,
      semanticsLabel: '${method.label} ödeme yöntemi',
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedPaymentMethod = method;
          _paymentError = false;
        });
      },
    );
  }

  /// Hızlı not çipi notu ekler ya da (seçiliyse) notu metinden çıkarır.
  void _toggleQuickNote(String note) {
    final current = _notesController.text.trim();
    String next;
    if (current.contains(note)) {
      next = current.replaceAll('. $note', '');
      if (next == current) next = current.replaceAll('$note. ', '');
      if (next == current) next = current.replaceAll(note, '');
      next = next.trim();
    } else {
      next = current.isEmpty ? note : '$current. $note';
    }
    _notesController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Widget _buildNotesSection() {
    return _section(
      step: '4',
      title: 'Sipariş notu',
      trailing: 'İsteğe bağlı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _notesController,
            builder: (context, value, _) => Wrap(
              spacing: 8,
              children: [
                for (final note in _quickNotes)
                  MarketChip(
                    label: note,
                    selected: value.text.contains(note),
                    onTap: () => _toggleQuickNote(note),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
    final validating = cart.isValidatingCoupon;

    if (applied != null) {
      final needsPoint = cart.appliedCoupon?['requiresDeliveryPoint'] == true &&
          cart.discountAmount <= 0;
      // Seçilen noktada geçersizse indirim düşülmez; nedeni altta kırmızıyla.
      final invalid = !validating && cart.couponError != null;
      final String status;
      if (validating) {
        status = 'İndirim hesaplanıyor…';
      } else if (invalid) {
        status = 'İndirim uygulanmadı';
      } else if (needsPoint && _selectedDeliveryPoint.isEmpty) {
        status = 'Teslimat noktasını seçince indirim hesaplanacak';
      } else {
        status = '${formatTl(cart.discountAmount)} indirim uygulandı';
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          decoration: BoxDecoration(
            color: MarketPalette.greenSoft,
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            border: Border.all(color: MarketPalette.greenLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: validating
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: MarketPalette.green),
                          )
                        : invalid
                            ? const Icon(Icons.error_outline_rounded,
                                color: MarketPalette.red)
                            : const Icon(Icons.check_circle_rounded,
                                color: MarketPalette.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applied, style: MarketText.code(size: 14)),
                        Text(
                          status,
                          style: MarketText.caption(
                              color: invalid
                                  ? MarketPalette.inkSoft
                                  : MarketPalette.greenDark),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: validating ? null : cart.removeCoupon,
                    style: TextButton.styleFrom(
                      foregroundColor: MarketPalette.red,
                      minimumSize: const Size(MarketSize.control, MarketSize.control),
                    ),
                    child: const Text('Kaldır'),
                  ),
                ],
              ),
              if (invalid)
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 2, 10, 4),
                  child: Text(
                    cart.couponError!,
                    style: MarketText.caption(
                        color: MarketPalette.red, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final coupon = suggestion!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MarketPalette.limeSoft, MarketPalette.greenSoft],
          ),
          borderRadius: BorderRadius.circular(MarketRadius.lg),
          border: Border.all(color: MarketPalette.limeLine),
        ),
        child: Row(
          children: [
            // Dar ekranda / büyük yazıda simge kutusu kod metnine yer bırakır.
            if (MediaQuery.sizeOf(context).width >= 360 &&
                MediaQuery.textScalerOf(context).scale(10) <= 11.5) ...[
              const MarketIconTile(
                icon: Icons.auto_awesome_rounded,
                size: 40,
                background: MarketPalette.lime,
                foreground: MarketPalette.greenDeep,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.best
                        ? 'Sepetin için en iyi kupon'
                        : 'Kullanılabilir kuponun var',
                    style: MarketText.caption(
                        color: MarketPalette.greenDark,
                        weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(coupon.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.code(
                          color: MarketPalette.greenDeep, size: 13)),
                  Text(coupon.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.caption(color: MarketPalette.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ApplyButton(
              loading: validating,
              onPressed:
                  validating ? null : () => _applyCoupon(cart, coupon.code),
            ),
          ],
        ),
      ),
    );
  }

  /// Topluluk indirimine sayfanın içinden katılma: buradan yanıt veren
  /// kullanıcıya sipariş anında ayrıca pencere açılmaz.
  Widget _buildCampaignCard() {
    final campaign = _campaign;
    if (_campaignAnswered || !CommunityCampaign.canJoin(campaign)) {
      return const SizedBox.shrink();
    }
    final target = (campaign!['targetCount'] ?? 0) as num;
    final current = (campaign['weightedCount'] ?? 0) as num;
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: MarketCard(
        color: MarketPalette.limeSoft,
        borderColor: MarketPalette.limeLine,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MarketIconTile(
                  icon: Icons.groups_rounded,
                  size: 40,
                  background: Colors.white,
                  foreground: MarketPalette.greenDeep,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${CommunityCampaign.percent(campaign)} topluluk indirimine katıl',
                        style: MarketText.heading(
                            color: MarketPalette.greenDeep, size: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Şartı sağlıyorsun. Bu siparişin etkilenmez.',
                        style: MarketText.caption(color: MarketPalette.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(MarketRadius.xs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${current.toInt()} / ${target.toInt()} katkı puanı',
              style: MarketText.caption(
                  color: MarketPalette.greenDark, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _joiningCampaign ? null : _joinCampaignInline,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(MarketSize.control),
                      backgroundColor: MarketPalette.greenDeep,
                    ),
                    child: _joiningCampaign
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Katıl'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _joiningCampaign
                        ? null
                        : () => setState(() => _campaignAnswered = true),
                    style: TextButton.styleFrom(
                      foregroundColor: MarketPalette.inkSoft,
                      minimumSize: const Size.fromHeight(MarketSize.control),
                    ),
                    child: const Text('Şimdi değil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinCampaignInline() async {
    setState(() => _joiningCampaign = true);
    final updated = await CommunityCampaign.join(context);
    if (!mounted) return;
    setState(() {
      _joiningCampaign = false;
      // Başarısızsa kart açık kalır; kullanıcı tekrar deneyebilir.
      if (updated != null) {
        _campaign = updated;
        _campaignAnswered = true;
      }
    });
  }

  Widget _buildSummarySection(CartViewModel cart) {
    final productSavings = cart.items.fold<double>(0, (sum, item) {
      final diff = item.product.price - item.product.actualPrice;
      return diff > 0 ? sum + diff * item.quantity : sum;
    });

    return _section(
      step: '',
      stepIcon: Icons.receipt_long_rounded,
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
                      color: MarketPalette.surface,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                      border: Border.all(color: MarketPalette.line),
                    ),
                    child: item.product.image.isEmpty
                        ? const Icon(Icons.inventory_2_outlined,
                            color: MarketPalette.subtle, size: 20)
                        : Image.network(
                            optimizedImageUrl(
                              item.product.image,
                              width: MarketImageSize.thumb,
                            ),
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
                          productDisplayName(item.product.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MarketText.label(
                              size: 13, weight: FontWeight.w600),
                        ),
                        Text(
                          '${item.quantity} × ${formatTl(item.product.actualPrice)}',
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

    return MarketBottomBar(
      child: MarketTotalAction(
        label: 'Ödenecek',
        amount: cart.finalPrice,
        savings: savings,
        actionLabel: 'Siparişi ver',
        onPressed: _createOrder,
        loading: _isLoading,
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

/// Bölüm numarası; bölüm tamamlanınca lime zemin üzerinde ✓ olur.
class _StepBadge extends StatelessWidget {
  final String step;
  final IconData? icon;
  final bool done;

  const _StepBadge({required this.step, this.icon, this.done = false});

  @override
  Widget build(BuildContext context) {
    final Widget badge;
    if (done) {
      badge = Container(
        key: const ValueKey('done'),
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: MarketPalette.lime,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            size: 16, color: MarketPalette.greenDeep),
      );
    } else {
      badge = Container(
        key: const ValueKey('todo'),
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: MarketPalette.greenDeep,
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(icon, size: 14, color: Colors.white)
            : Text(step, style: MarketText.label(color: Colors.white, size: 12)),
      );
    }
    return Semantics(
      label: done ? 'Tamamlandı' : null,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: badge,
        ),
      ),
    );
  }
}

/// Kupon "Uygula" düğmesi: doğrulanırken beyaz dönen gösterge.
class _ApplyButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const _ApplyButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, MarketSize.control),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        disabledBackgroundColor: loading ? MarketPalette.green : null,
        disabledForegroundColor: loading ? Colors.white : null,
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text('Uygula'),
    );
  }
}

/// Sepet ✓ → 2 Teslimat → 3 Onay
class _CheckoutSteps extends StatelessWidget {
  final int itemCount;

  const _CheckoutSteps({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    Widget step(String number, String label,
        {required bool done, required bool active}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
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
                : Text(
                    number,
                    style: MarketText.label(
                      color: active
                          ? MarketPalette.greenDeep
                          : Colors.white.withValues(alpha: .6),
                      size: 11,
                      weight: FontWeight.w800,
                    ),
                  ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: MarketText.label(
                color: Colors.white.withValues(alpha: done || active ? 1 : .6),
                size: 12,
                weight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
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

    return Semantics(
      label: 'Adım 2 / 3: Teslimat. Sepette $itemCount ürün.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dar ekranda / büyük yazıda yalnızca etkin adımın adı yazılır.
            final compact = constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(10) > 11.5;
            return Row(
              children: [
                step('1', compact ? '' : 'Sepet', done: true, active: false),
                connector(),
                step('2', 'Teslimat', done: false, active: true),
                connector(),
                step('3', compact ? '' : 'Onay', done: false, active: false),
              ],
            );
          },
        ),
      ),
    );
  }
}
