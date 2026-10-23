import 'dart:convert';

import 'package:benimmarketim_app/models/cart_item.dart';
import 'package:benimmarketim_app/models/product.dart';
import 'package:benimmarketim_app/services/meta_app_events_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('flutter.oddbit.id/facebook_app_events');

Product _product(String id, double price) => Product(
      id: id,
      name: 'Ürün $id',
      description: '',
      price: price,
      originalPrice: price,
      actualPrice: price,
      image: '',
      category: '',
      categoryId: '',
      isDiscounted: false,
      isOutOfStock: false,
      isFeatured: false,
      isHidden: false,
      order: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _FakeTracking extends TrackingAuthorization {
  _FakeTracking(this.current, {this.answer = TrackingStatus.authorized});

  TrackingStatus current;
  final TrackingStatus answer;
  int requests = 0;

  @override
  Future<TrackingStatus> status() async => current;

  @override
  Future<TrackingStatus> request() async {
    requests++;
    if (current == TrackingStatus.notDetermined) current = answer;
    return current;
  }

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  MetaAppEventsService service() =>
      MetaAppEventsService(platformSupported: true);

  List<String> names() => calls.map((c) => c.method).toList();

  test('izin verilmeden hiçbir olay gönderilmez', () async {
    SharedPreferences.setMockInitialValues({});
    final meta = service();
    await meta.init();
    await meta.logAddToCart(_product('p1', 10));
    await meta.logPurchase(
      orderId: 'o1',
      items: [CartItem(product: _product('p1', 10))],
      amount: 10,
    );
    expect(meta.consent, MetaTrackingConsent.unknown);
    expect(calls, isEmpty);
  });

  test('izin verilince SDK bir kez etkinleşir', () async {
    SharedPreferences.setMockInitialValues({});
    final meta = service();
    await meta.setConsent(true);
    await meta.setConsent(true);
    expect(names(), [
      'initializeSdk',
      'setAdvertiserIdCollectionEnabled',
      'setAutoLogAppEventsEnabled',
      'activateApp',
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MetaAppEventsService.consentKey), 'granted');
  });

  test('sonraki açılışta activateApp elle çağrılmaz (çift açılış yok)',
      () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = service();
    await meta.init();
    expect(names(), contains('initializeSdk'));
    expect(names(), isNot(contains('activateApp')));
  });

  test('yeni olaylar izin yokken gönderilmez', () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'denied'});
    final meta = service();
    await meta.init();
    await meta.logViewContent(_product('p1', 10));
    await meta.logSearch('süt', resultCount: 3);
    await meta.logAddToWishlist(_product('p1', 10));
    await meta.logInitiateCheckout(
        items: [CartItem(product: _product('p1', 10))], amount: 10);
    await meta.logAddPaymentInfo('cash');
    await meta.logCompleteRegistration();
    await meta.logLogin();
    await meta.logContact();
    await meta.logRate(rating: 5);
    await meta.logShare(contentType: 'product', contentId: 'p1');
    await meta.logPushOpen({'route': '/orders'});
    expect(calls, isEmpty);
  });

  test('izinle standart Meta olay adları gönderilir', () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = service();
    await meta.init();
    calls.clear();

    await meta.logViewContent(_product('p1', 10));
    await meta.logSearch('süt', resultCount: 0);
    await meta.logAddToWishlist(_product('p1', 10));
    await meta.logInitiateCheckout(
        items: [CartItem(product: _product('p1', 10), quantity: 2)],
        amount: 20);
    await meta.logAddPaymentInfo('card');
    await meta.logCompleteRegistration();
    await meta.logContact();
    await meta.logRate(rating: 4);

    final events = [
      for (final c in calls)
        Map<String, dynamic>.from(c.arguments as Map)['name'],
    ];
    expect(events, [
      'fb_mobile_content_view',
      'fb_mobile_search',
      'fb_mobile_add_to_wishlist',
      'fb_mobile_initiated_checkout',
      'fb_mobile_add_payment_info',
      'fb_mobile_complete_registration',
      'Contact',
      'fb_mobile_rate',
    ]);
    final search = Map<String, dynamic>.from(
        (calls[1].arguments as Map)['parameters'] as Map);
    expect(search['fb_search_string'], 'süt');
    expect(search['fb_success'], '0');
    final checkout = Map<String, dynamic>.from(calls[3].arguments as Map);
    expect(checkout['_valueToSum'], 20.0);
    expect(
        Map<String, dynamic>.from(checkout['parameters'] as Map)['fb_num_items'],
        2);
  });

  test('AddToCart tutar, adet ve para birimiyle gönderilir', () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = service();
    await meta.init();
    calls.clear();
    await meta.logAddToCart(_product('p1', 12.5), quantity: 3);

    expect(names(), ['logEvent']);
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['name'], 'fb_mobile_add_to_cart');
    expect(args['_valueToSum'], 37.5);
    final params = Map<String, dynamic>.from(args['parameters'] as Map);
    expect(params['fb_currency'], 'TRY');
    expect(params['fb_content_id'], 'p1');
    expect(params['fb_num_items'], 3);
  });

  test('aynı sipariş için Purchase yalnızca bir kez gönderilir', () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = service();
    await meta.init();
    calls.clear();
    final items = [
      CartItem(product: _product('p1', 10), quantity: 2),
      CartItem(product: _product('p2', 5)),
    ];

    await Future.wait([
      meta.logPurchase(orderId: 'o1', items: items, amount: 25),
      meta.logPurchase(orderId: 'o1', items: items, amount: 25),
    ]);
    await meta.logPurchase(orderId: 'o1', items: items, amount: 25);

    expect(names(), ['logPurchase']);
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['amount'], 25.0);
    expect(args['currency'], 'TRY');
    final params = Map<String, dynamic>.from(args['parameters'] as Map);
    expect(params['fb_order_id'], 'o1');
    expect(params['fb_num_items'], 3);
    expect(jsonDecode(params['fb_content_id'] as String), ['p1', 'p2']);
  });

  test('izin geri alınınca ölçüm kapanır ve olay gönderilmez', () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = service();
    await meta.init();
    calls.clear();

    await meta.setConsent(false);
    expect(names(),
        ['setAutoLogAppEventsEnabled', 'setAdvertiserIdCollectionEnabled']);
    expect(calls.every((c) => c.arguments == false), isTrue);

    calls.clear();
    await meta.logAddToCart(_product('p1', 10));
    expect(calls, isEmpty);
  });

  test('desteklenmeyen platformda hiçbir çağrı yapılmaz',
      () async {
    SharedPreferences.setMockInitialValues(
        {MetaAppEventsService.consentKey: 'granted'});
    final meta = MetaAppEventsService(platformSupported: false);
    await meta.init();
    await meta.setConsent(true);
    await meta.logAddToCart(_product('p1', 10));
    expect(calls, isEmpty);
  });

  group('iOS', () {
    MetaAppEventsService ios(_FakeTracking tracking) => MetaAppEventsService(
          platform: MetaPlatform.ios,
          tracking: tracking,
        );

    test('izin verilmeden SDK hiç başlatılmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final tracking = _FakeTracking(TrackingStatus.notDetermined);
      final meta = ios(tracking);
      await meta.init();
      await meta.logAddToCart(_product('p1', 10));
      expect(meta.consent, MetaTrackingConsent.unknown);
      expect(tracking.requests, 0);
      expect(calls, isEmpty);
    });

    test('onay + iPhone izni: SDK bir kez başlar, açılış bir kez bildirilir',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tracking = _FakeTracking(TrackingStatus.notDetermined);
      final meta = ios(tracking);
      expect(await meta.setConsent(true), isTrue);
      expect(await meta.setConsent(true), isTrue);
      expect(tracking.requests, 1);
      expect(names(), [
        'initializeSdk',
        'setAutoLogAppEventsEnabled',
        'setAdvertiserIdCollectionEnabled',
        'activateApp',
      ]);
      // iOS'ta otomatik kayıt kapalı kalır (açılış elle bildirilir)
      expect(calls[1].arguments, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MetaAppEventsService.consentKey), 'granted');
    });

    test('iPhone izin vermezse hiçbir şey gönderilmez ve karar kaydedilmez',
        () async {
      SharedPreferences.setMockInitialValues({});
      final tracking = _FakeTracking(
        TrackingStatus.notDetermined,
        answer: TrackingStatus.denied,
      );
      final meta = ios(tracking);
      expect(await meta.setConsent(true), isFalse);
      await meta.logAddToCart(_product('p1', 10));
      expect(meta.consent, MetaTrackingConsent.denied);
      expect(calls, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MetaAppEventsService.consentKey), isNull);
    });

    test('sonraki açılışta izinler varsa ölçüm başlar', () async {
      SharedPreferences.setMockInitialValues(
          {MetaAppEventsService.consentKey: 'granted'});
      final meta = ios(_FakeTracking(TrackingStatus.authorized));
      await meta.init();
      calls.clear();
      await meta.logAddToCart(_product('p1', 10));
      expect(names(), ['logEvent']);
    });

    test('izin iPhone Ayarlar\'dan kapatıldıysa olay gönderilmez', () async {
      SharedPreferences.setMockInitialValues(
          {MetaAppEventsService.consentKey: 'granted'});
      final meta = ios(_FakeTracking(TrackingStatus.denied));
      await meta.init();
      await meta.logAddToCart(_product('p1', 10));
      expect(meta.consent, MetaTrackingConsent.denied);
      expect(calls, isEmpty);
    });

    test('uygulama içinden kapatılınca iPhone izni olsa da ölçüm yok',
        () async {
      SharedPreferences.setMockInitialValues(
          {MetaAppEventsService.consentKey: 'denied'});
      final meta = ios(_FakeTracking(TrackingStatus.authorized));
      await meta.init();
      await meta.logAddToCart(_product('p1', 10));
      expect(calls, isEmpty);
    });

    test('SDK başlamadan izin geri alınırsa SDK çağrılmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final meta = ios(_FakeTracking(TrackingStatus.notDetermined));
      await meta.setConsent(false);
      expect(calls, isEmpty);
    });
  });
}
