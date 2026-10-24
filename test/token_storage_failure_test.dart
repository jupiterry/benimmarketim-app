// Bozuk token deposu (Android otomatik yedeği şifreli kaydı geri getirip
// Keystore anahtarını getirmediğinde): okumalar PlatformException fırlatır.
// Uygulama askıda kalmamalı; istekler oturumsuz gitmeli.

import 'dart:async';
import 'dart:convert';

import 'package:benimmarketim_app/services/api_service.dart';
import 'package:benimmarketim_app/services/token_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Depo davranışı: 'broken' → okuma PlatformException, 'hang' → okuma hiç
/// bitmez, 'ok' → [_values] okunur.
String _mode = 'ok';
bool _deleteFails = false;
final Map<String, String> _values = {};
final List<String> _deleted = [];

void _mockStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    final key = (call.arguments as Map?)?['key'] as String?;
    switch (call.method) {
      case 'read':
        if (_mode == 'broken') {
          throw PlatformException(
              code: 'Exception encountered', message: 'BAD_DECRYPT');
        }
        if (_mode == 'hang') return Completer<String?>().future;
        return _values[key];
      case 'delete':
        if (_deleteFails) throw PlatformException(code: 'delete failed');
        _deleted.add(key!);
        _values.remove(key);
        return null;
      case 'write':
        _values[key!] = (call.arguments as Map)['value'] as String;
        return null;
    }
    return null;
  });
}

/// Ağa gitmeden 200 döner; gelen Authorization başlığını kaydeder.
class _Adapter implements HttpClientAdapter {
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    authHeaders.add(options.headers['Authorization'] as String?);
    return ResponseBody.fromString(
      jsonEncode({'zones': [], 'freeDeliveryEverywhere': false}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _mode = 'ok';
    _deleteFails = false;
    _values.clear();
    _deleted.clear();
    TokenManager.readTimeout = const Duration(milliseconds: 200);
    _mockStorage();
  });

  test('bozuk kayıt: okuma null döner ve token kayıtları silinir', () async {
    _mode = 'broken';
    expect(await TokenManager.getAccessToken(), isNull);
    expect(_deleted,
        containsAll(['access_token', 'refresh_token', 'token_saved_date']));
    expect(await TokenManager.getRefreshToken(), isNull);
    expect(await TokenManager.hasToken(), isFalse);
    expect(await TokenManager.getTokenSavedDate(), isNull);
  });

  test('depo yanıt vermezse zaman aşımında null döner, kayıt silinmez',
      () async {
    _mode = 'hang';
    expect(await TokenManager.getAccessToken(), isNull);
    expect(_deleted, isEmpty);
  });

  test('silme de başarısızsa hata fırlatılmaz', () async {
    _mode = 'broken';
    _deleteFails = true;
    expect(await TokenManager.getAccessToken(), isNull);
    await TokenManager.clearAllTokens();
  });

  test('sağlam depoda token okunur', () async {
    _values['access_token'] = 'abc';
    expect(await TokenManager.getAccessToken(), 'abc');
    expect(await TokenManager.hasToken(), isTrue);
  });

  group('istekler askıda kalmaz', () {
    for (final mode in ['broken', 'hang']) {
      test('depo: $mode → istek oturumsuz tamamlanır', () async {
        _mode = mode;
        final adapter = _Adapter();
        ApiService.debugUseHttpAdapter(adapter);
        final result = await ApiService()
            .getDeliveryZones()
            .timeout(const Duration(seconds: 3));
        expect(result.zones, isEmpty);
        expect(adapter.authHeaders, [null]);
      });
    }

    test('sağlam depoda token başlığa eklenir', () async {
      _values['access_token'] = 'abc';
      final adapter = _Adapter();
      ApiService.debugUseHttpAdapter(adapter);
      await ApiService().getDeliveryZones();
      expect(adapter.authHeaders, ['Bearer abc']);
    });
  });
}
