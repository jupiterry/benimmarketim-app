import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:benimmarketim_app/models/coupon.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/viewmodels/referral_viewmodel.dart';

class CouponApi extends ApiService {
  final requests = <Completer<List<Coupon>>>[];
  @override
  Future<List<Coupon>> getUserCoupons() {
    final request = Completer<List<Coupon>>();
    requests.add(request);
    return request.future;
  }
}

Coupon coupon([Map<String, dynamic> fields = const {}]) => Coupon.fromJson({
  'code': 'WELCOME',
  'expirationDate': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  ...fields,
});

void main() {
  test('Exhausted personal and global coupons are not available', () {
    expect(coupon().isValid, isTrue);
    expect(coupon({'remainingUses': 0}).isValid, isFalse);
    expect(coupon({'remainingGlobalUses': 0}).isValid, isFalse);
    expect(coupon({'isUsed': true}).isValid, isFalse);
  });

  test('Post-order refresh wins over an older in-flight wallet request', () async {
    final api = CouponApi();
    final model = ReferralViewModel(apiService: api);
    final oldLoad = model.loadCoupons();
    final refresh = model.refreshCouponsAfterOrder();
    expect(api.requests, hasLength(2));
    api.requests[1].complete([]);
    await refresh;
    api.requests[0].complete([coupon()]);
    await oldLoad;
    expect(model.validCoupons, isEmpty);
    model.dispose();
  });

  test('Order removes cached coupons even if refresh fails', () async {
    final api = CouponApi();
    final model = ReferralViewModel(apiService: api);
    final initial = model.loadCoupons();
    api.requests[0].complete([coupon()]);
    await initial;
    final refresh = model.refreshCouponsAfterOrder();
    expect(model.validCoupons, isEmpty);
    api.requests[1].completeError(Exception('offline'));
    await refresh;
    expect(model.validCoupons, isEmpty);
    expect(model.couponsLoaded, isFalse);
    model.dispose();
  });

  test('Logout ignores a previous account wallet response', () async {
    final api = CouponApi();
    final model = ReferralViewModel(apiService: api);
    final load = model.loadCoupons();
    model.clear();
    api.requests.single.complete([coupon()]);
    await load;
    expect(model.validCoupons, isEmpty);
    expect(model.couponsLoaded, isFalse);
    model.dispose();
  });
}
