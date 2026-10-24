import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../models/cart_item.dart';
import '../models/delivery.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';

/// Adrese teslimat durumu: erişim (`/delivery/me`), bölgeler, kayıtlı
/// adresler, ödemede seçilen teslimat yeri ve teslimat ücreti teklifi.
///
/// Erişim kapalıysa (ya da sorgu hata verdiyse) [canOrderToAddress] false
/// döner ve uygulama bugünkü yurt akışını gösterir.
class DeliveryViewModel extends ChangeNotifier {
  DeliveryViewModel({
    ApiService? api,
    this.quoteDebounce = const Duration(milliseconds: 400),
    bool listenLifecycle = true,
  }) : _api = api ?? ApiService() {
    if (listenLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: _onResume);
    }
  }

  final ApiService _api;
  final Duration quoteDebounce;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  // -------------------------------------------------------------------------
  // Erişim
  // -------------------------------------------------------------------------

  DeliveryAccess _access = DeliveryAccess.disabled;
  bool _loggedIn = false;
  Future<void>? _accessInFlight;

  DeliveryAccess get access => _access;

  /// Adres akışı açık mı? false ise yurt akışı gösterilir.
  bool get canOrderToAddress => _loggedIn && _access.canOrderToAddress;

  /// Oturum açıldı/kapandı. Açılınca erişim ve adresler yenilenir;
  /// kapanınca kullanıcıya ait her şey temizlenir.
  void onAuthChanged(bool loggedIn) {
    if (loggedIn == _loggedIn) return;
    _loggedIn = loggedIn;
    if (!loggedIn) {
      _access = DeliveryAccess.disabled;
      _addresses = const [];
      _addressesLoaded = false;
      _addressesError = null;
      _selectedAddressId = null;
      _selectedDormZoneId = null;
      _clearQuote();
      _notify();
      return;
    }
    // Sağlayıcı güncellemesi build sırasında gelir; bildirim sonraya kalır.
    scheduleMicrotask(() {
      if (_disposed) return;
      refreshAccess();
    });
  }

  /// `/delivery/me` sorgusu. Hata → güvenli taraf (yurt akışı).
  Future<void> refreshAccess() {
    if (!_loggedIn) {
      _setAccess(DeliveryAccess.disabled);
      return Future.value();
    }
    return _accessInFlight ??= _loadAccess().whenComplete(() {
      _accessInFlight = null;
    });
  }

  Future<void> _loadAccess() async {
    DeliveryAccess next;
    try {
      next = await _api.getDeliveryAccess();
    } catch (e) {
      AppLogger.debug('Teslimat erişimi alınamadı: $e');
      next = DeliveryAccess.disabled;
    }
    if (_disposed) return;
    _setAccess(next);
    if (canOrderToAddress) {
      unawaited(loadZones());
      if (!_addressesLoaded) unawaited(loadAddresses());
    }
  }

  void _setAccess(DeliveryAccess next) {
    if (next == _access) return;
    _access = next;
    if (!next.canOrderToAddress) _clearQuote();
    _notify();
  }

  /// Sipariş sunucuda ADDRESS_ORDERING_DISABLED ile reddedildi: anahtar
  /// kapanmış. Hemen yurt akışına dön ve durumu sunucudan doğrula.
  Future<void> handleAddressOrderingDisabled() {
    _setAccess(DeliveryAccess.disabled);
    return refreshAccess();
  }

  void _onResume() {
    if (!_loggedIn) return;
    unawaited(refreshAccess());
    if (canOrderToAddress) unawaited(loadZones(force: true));
  }

  // -------------------------------------------------------------------------
  // Bölgeler
  // -------------------------------------------------------------------------

  DeliveryZonesResult? _zonesResult;
  bool _zonesLoading = false;
  String? _zonesError;
  Future<void>? _zonesInFlight;

  List<DeliveryZone> get zones => _zonesResult?.zones ?? const [];
  bool get zonesLoaded => _zonesResult != null;
  bool get zonesLoading => _zonesLoading;
  String? get zonesError => _zonesError;
  bool get freeDeliveryEverywhere =>
      _zonesResult?.freeDeliveryEverywhere ?? false;

  /// Açık bölge (kapalı/listede olmayan için null)
  DeliveryZone? zoneById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final zone in zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  List<DeliveryZone> get dormZones =>
      zones.where((z) => z.type == DeliveryZoneType.yurt).toList();

  /// Adres girilebilen bölgeler (Devrek). Boşsa adrese teslimat yapılan
  /// açık bölge yok (panelde kapalı).
  List<DeliveryZone> get addressZones =>
      zones.where((z) => z.type != DeliveryZoneType.yurt).toList();

  /// Adres seçilmemişken sepette gösterilecek en düşük ödenecek ücret
  double? get cheapestFee {
    if (zones.isEmpty) return null;
    var best = double.infinity;
    for (final zone in zones) {
      final fee = zone.isFree ? 0.0 : zone.deliveryFee;
      if (fee < best) best = fee;
    }
    return best.isFinite ? best : null;
  }

  Future<void> loadZones({bool force = false}) {
    if (!force && _zonesResult != null) return Future.value();
    return _zonesInFlight ??= _loadZones().whenComplete(() {
      _zonesInFlight = null;
    });
  }

  Future<void> _loadZones() async {
    _zonesLoading = true;
    _zonesError = null;
    _notify();
    try {
      _zonesResult = await _api.getDeliveryZones();
    } catch (e) {
      _zonesError = e.toString();
    } finally {
      _zonesLoading = false;
      _notify();
    }
  }

  // -------------------------------------------------------------------------
  // Teslimat alanı (haritadaki sınır)
  // -------------------------------------------------------------------------

  static const _areaMaxAge = Duration(minutes: 5);
  final Map<String, ({DeliveryArea? area, DateTime at})> _areas = {};
  final Map<String, Future<DeliveryArea?>> _areasInFlight = {};

  /// Bölgenin sınırı (5 dk önbellekli). Sınır yüklü değilse ya da
  /// alınamazsa null: iğne yine zorunlu ama uygulama sınırı denetlemez,
  /// kesin denetimi sunucu yapar.
  Future<DeliveryArea?> loadArea(String zoneId) {
    final cached = _areas[zoneId];
    if (cached != null && DateTime.now().difference(cached.at) < _areaMaxAge) {
      return Future.value(cached.area);
    }
    return _areasInFlight[zoneId] ??= _loadArea(zoneId).whenComplete(() {
      _areasInFlight.remove(zoneId);
    });
  }

  Future<DeliveryArea?> _loadArea(String zoneId) async {
    try {
      final area = await _api.getDeliveryZoneArea(zoneId);
      _areas[zoneId] = (area: area, at: DateTime.now());
      return area;
    } catch (e) {
      AppLogger.debug('Teslimat alanı alınamadı: $e');
      return _areas[zoneId]?.area;
    }
  }

  // -------------------------------------------------------------------------
  // Kayıtlı adresler
  // -------------------------------------------------------------------------

  List<DeliveryAddress> _addresses = const [];
  int _maxAddresses = 5;
  bool _addressesLoaded = false;
  bool _addressesLoading = false;
  String? _addressesError;
  Future<void>? _addressesInFlight;

  List<DeliveryAddress> get addresses => _addresses;
  int get maxAddresses => _maxAddresses;
  bool get addressesLoaded => _addressesLoaded;
  bool get addressesLoading => _addressesLoading;
  String? get addressesError => _addressesError;
  bool get canAddAddress => _addresses.length < _maxAddresses;

  DeliveryAddress? get defaultAddress {
    for (final address in _addresses) {
      if (address.isDefault) return address;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  DeliveryAddress? addressById(String? id) {
    if (id == null) return null;
    for (final address in _addresses) {
      if (address.id == id) return address;
    }
    return null;
  }

  Future<void> loadAddresses() {
    if (!_loggedIn) return Future.value();
    return _addressesInFlight ??= _loadAddresses().whenComplete(() {
      _addressesInFlight = null;
    });
  }

  Future<void> _loadAddresses() async {
    _addressesLoading = true;
    _addressesError = null;
    _notify();
    try {
      final result = await _api.getAddresses();
      _setAddresses(result.addresses);
      _maxAddresses = result.max;
      _addressesLoaded = true;
    } catch (e) {
      _addressesError = e.toString();
    } finally {
      _addressesLoading = false;
      _notify();
    }
  }

  void _setAddresses(List<DeliveryAddress> next) {
    _addresses = List.unmodifiable(next);
    _addressesLoaded = true;
    // Seçili adres silindiyse varsayılana dönülür
    if (_selectedAddressId != null && addressById(_selectedAddressId) == null) {
      _selectedAddressId = null;
    }
  }

  /// Yeni adres; hata olursa [ApiException] fırlatır (form gösterir).
  Future<DeliveryAddress> createAddress({
    required String label,
    required String zoneId,
    required AddressFields fields,
    bool? isDefault,
  }) async {
    final result = await _api.createAddress(
      label: label,
      zoneId: zoneId,
      fields: fields,
      isDefault: isDefault,
    );
    _setAddresses(result.addresses);
    _notify();
    return result.address;
  }

  Future<DeliveryAddress> updateAddress(
      String id, Map<String, dynamic> changes) async {
    final result = await _api.updateAddress(id, changes);
    _setAddresses(result.addresses);
    _invalidateQuoteIfZoneChanged();
    _notify();
    return result.address;
  }

  Future<void> deleteAddress(String id) async {
    final next = await _api.deleteAddress(id);
    _setAddresses(next);
    _invalidateQuoteIfZoneChanged();
    _notify();
  }

  Future<void> setDefaultAddress(String id) async {
    final result = await _api.setDefaultAddress(id);
    _setAddresses(result.addresses);
    _notify();
  }

  // -------------------------------------------------------------------------
  // Ödemede seçilen teslimat yeri: kayıtlı adres ya da yurt (bölge olarak)
  // -------------------------------------------------------------------------

  String? _selectedAddressId;
  String? _selectedDormZoneId;

  /// Seçili kayıtlı adres; açıkça seçilmediyse varsayılan adres.
  DeliveryAddress? get selectedAddress {
    if (_selectedDormZoneId != null) return null;
    return addressById(_selectedAddressId) ?? defaultAddress;
  }

  /// Yurt seçildiyse yurdun bölgesi
  DeliveryZone? get selectedDormZone => zoneById(_selectedDormZoneId);
  String? get selectedDormZoneId => _selectedDormZoneId;

  /// Seçimin teslimat bölgesi kimliği (yoksa null)
  String? get selectedZoneId =>
      _selectedDormZoneId ?? selectedAddress?.zoneId;

  /// Seçimin açık bölgesi (kapalıysa null)
  DeliveryZone? get selectedZone => zoneById(selectedZoneId);

  /// Seçim sipariş vermeye uygun mu (bölge açık)
  bool get selectionUsable {
    final dorm = _selectedDormZoneId;
    if (dorm != null) return zoneById(dorm) != null;
    final address = selectedAddress;
    if (address == null || !address.zoneEnabled) return false;
    // Bölgeler yüklenmediyse adresin kendi bilgisine güvenilir
    return !zonesLoaded || zoneById(address.zoneId) != null;
  }

  void selectAddress(String id) {
    if (_selectedAddressId == id && _selectedDormZoneId == null) return;
    _selectedAddressId = id;
    _selectedDormZoneId = null;
    _invalidateQuoteIfZoneChanged();
    _notify();
  }

  void selectDorm(String zoneId) {
    if (_selectedDormZoneId == zoneId) return;
    _selectedDormZoneId = zoneId;
    _invalidateQuoteIfZoneChanged();
    _notify();
  }

  // -------------------------------------------------------------------------
  // Teslimat ücreti teklifi
  // -------------------------------------------------------------------------

  DeliveryQuote? _quote;
  bool _quoteLoading = false;
  ApiException? _quoteError;
  String? _quoteKey; // en son istenen (bölge + sepet)
  String? _quoteResultKey; // _quote'un ait olduğu anahtar
  Timer? _quoteTimer;
  bool _quoteInFlight = false;
  List<Map<String, dynamic>> _pendingProducts = const [];
  String? _pendingZoneId;

  /// Seçili bölge ve güncel sepet için teklif (eski sonuç gösterilmez)
  DeliveryQuote? get quote =>
      _quoteResultKey != null && _quoteResultKey == _quoteKey ? _quote : null;
  bool get quoteLoading => _quoteLoading;

  /// Son teklif hatası (ör. ZONE_CLOSED); kullanıcıya `message` gösterilir
  ApiException? get quoteError => _quoteError;

  /// Seçili bölge ve sepet için teklif ister. Sık çağrılabilir: istekler
  /// [quoteDebounce] kadar bekletilir ve aynı anda yalnızca bir istek gider.
  void requestQuote(List<CartItem> items, {String? zoneId}) {
    final zone = zoneId ?? selectedZoneId;
    if (!canOrderToAddress || zone == null || items.isEmpty) {
      if (_quoteKey != null || _quote != null || _quoteError != null) {
        _clearQuote();
        _notify();
      }
      return;
    }
    final products = [
      for (final item in items)
        {'product': item.product.id, 'quantity': item.quantity},
    ];
    final key = '$zone|${products.map((p) => '${p['product']}x${p['quantity']}').join(',')}';
    if (key == _quoteKey && (_quote != null || _quoteLoading)) return;
    _quoteKey = key;
    _pendingZoneId = zone;
    _pendingProducts = products;
    _quoteError = null;
    if (!_quoteLoading) {
      _quoteLoading = true;
      _notify();
    }
    _quoteTimer?.cancel();
    _quoteTimer = Timer(quoteDebounce, _fireQuote);
  }

  Future<void> _fireQuote() async {
    if (_quoteInFlight || _disposed) return; // bitince yeniden denenir
    final key = _quoteKey;
    final zone = _pendingZoneId;
    if (key == null || zone == null) return;
    _quoteInFlight = true;
    try {
      final result = await _api.getDeliveryQuote(
        zoneId: zone,
        products: _pendingProducts,
      );
      if (_disposed) return;
      if (key == _quoteKey) {
        _quote = result;
        _quoteResultKey = key;
        _quoteError = null;
      }
    } on ApiException catch (e) {
      if (_disposed) return;
      if (key == _quoteKey) {
        _quote = null;
        _quoteResultKey = null;
        _quoteError = e;
        if (e.code == 'ADDRESS_ORDERING_DISABLED') {
          unawaited(handleAddressOrderingDisabled());
        }
      }
    } catch (e) {
      if (_disposed) return;
      if (key == _quoteKey) {
        _quote = null;
        _quoteResultKey = null;
        _quoteError = const ApiException('Teslimat ücreti hesaplanamadı.');
      }
    } finally {
      _quoteInFlight = false;
    }
    if (_disposed) return;
    if (key != _quoteKey && _quoteKey != null) {
      // İstek sürerken sepet ya da adres değişti: en günceli sor
      unawaited(_fireQuote());
      return;
    }
    _quoteLoading = false;
    _notify();
  }

  void _invalidateQuoteIfZoneChanged() {
    final zone = selectedZoneId;
    if (_quoteKey != null && !_quoteKey!.startsWith('$zone|')) {
      _clearQuote();
    }
  }

  void _clearQuote() {
    _quoteTimer?.cancel();
    _quoteTimer = null;
    _quote = null;
    _quoteKey = null;
    _quoteResultKey = null;
    _quoteError = null;
    _quoteLoading = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _quoteTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
