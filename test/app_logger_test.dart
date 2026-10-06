import 'package:benimmarketim_app/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JWT, Bearer ve token/şifre alanları maskelenir', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abc_DEF-123';
    final out = AppLogger.redactForTest(
      'token=$jwt Authorization: Bearer abc.def '
      '{"password": "gizli123", "refreshToken": "r1"}',
    );
    expect(out, isNot(contains(jwt)));
    expect(out, isNot(contains('abc.def')));
    expect(out, isNot(contains('gizli123')));
    expect(out, isNot(contains('r1')));
  });

  test('Sıradan mesajlar değişmeden kalır', () {
    expect(
      AppLogger.redactForTest('Products Response Status: 200'),
      'Products Response Status: 200',
    );
  });
}
