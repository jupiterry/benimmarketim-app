// Sipariş / profil widget testleri için sahte sunucu ve eklenti taklitleri.
// Ortak font/tema yardımcıları test_utils.dart'tadır.

import 'dart:convert';

import 'package:benimmarketim_app/models/delivery.dart';
import 'package:benimmarketim_app/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart'
    show databaseFactory, databaseFactorySqflitePlugin;

/// 'GET /orders-analytics/user-orders' gibi anahtarlarla JSON döndüren sahte
/// sunucu. Tanımsız istekler 503 alır (sunucuya ulaşılamadı).
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, Object? Function(RequestOptions options)> routes;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path.replaceFirst(RegExp(r'^/api'), '');
    final handler = routes['${options.method} $path'];
    if (handler == null) {
      return ResponseBody.fromString('{}', 503, headers: _json);
    }
    return ResponseBody.fromString(jsonEncode(handler(options)), 200,
        headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

void _mock(String channel, Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(channel), handler);
}

/// Ekranların dokunduğu eklentiler: token yok, boş veritabanı, sürüm bilgisi.
void installOrdersPlatformMocks() {
  databaseFactory = databaseFactorySqflitePlugin;
  _mock('plugins.flutter.io/path_provider', (_) async => '/tmp');
  _mock('plugins.it_nomads.com/flutter_secure_storage', (_) async => null);
  _mock('dev.fluttercommunity.plus/package_info', (_) async => {
        'appName': 'Benim Marketim',
        'packageName': 'com.jupi.benimapp.benimmarketim_app',
        'version': '7.1.0',
        'buildNumber': '51',
      });
  _mock('com.tekartik.sqflite', (call) async {
    switch (call.method) {
      case 'getDatabasesPath':
        return '/tmp';
      case 'openDatabase':
        return 1;
      case 'query':
        return <String, Object?>{'columns': <String>[], 'rows': <List>[]};
      case 'insert':
      case 'update':
        return 0;
      default:
        return null;
    }
  });
}

/// DeliveryViewModel için sahte API: erişim ve bölgeler sabit, adres yok.
class FakeDeliveryApi extends ApiService {
  FakeDeliveryApi({
    this.canOrderToAddress = false,
    this.zones = const [],
    this.freeDeliveryEverywhere = false,
    this.zonesFail = false,
  });

  bool canOrderToAddress;
  List<DeliveryZone> zones;
  bool freeDeliveryEverywhere;
  bool zonesFail;
  int zoneCalls = 0;

  @override
  Future<DeliveryAccess> getDeliveryAccess() async => DeliveryAccess(
        addressOrdering: canOrderToAddress ? 'public' : 'off',
        canOrderToAddress: canOrderToAddress,
      );

  @override
  Future<DeliveryZonesResult> getDeliveryZones() async {
    zoneCalls++;
    if (zonesFail) throw const ApiException('Teslimat bölgeleri alınamadı.');
    return DeliveryZonesResult(
      zones: zones,
      freeDeliveryEverywhere: freeDeliveryEverywhere,
    );
  }

  @override
  Future<({List<DeliveryAddress> addresses, int max})> getAddresses() async =>
      (addresses: const <DeliveryAddress>[], max: 5);
}
