import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/delivery.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import 'market_ui.dart';

/// Adres haritası (OpenStreetMap). Kullanıcı haritayı kaydırıp ortadaki
/// iğneyi kapısının üstüne getirir; seçilen nokta adresle birlikte
/// `location: {lat, lng}` olarak kaydedilir. Teslimat alanı (Devrek sınırı)
/// yüklüyse haritada çizilir ve dışındaki nokta seçilemez.
abstract final class AddressMap {
  /// Devrek ilçe merkezi
  static const LatLng devrekCenter = LatLng(41.2194, 31.9558);

  /// Devrek'i kapsayan alan. Harita merkezi bu alanın dışına çıkamaz.
  static final LatLngBounds devrekBounds = LatLngBounds(
    const LatLng(41.03, 31.72),
    const LatLng(41.40, 32.18),
  );

  static const double townZoom = 13;
  static const double streetZoom = 17;

  /// OSM karo adresi. Trafik büyürse ücretli bir sağlayıcıya (ör. MapTiler)
  /// geçmek için yalnızca bu satır değişir.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackage = 'com.jupi.benimapp.benimmarketim_app';

  /// Testlerde ağdan karo indirilmez.
  @visibleForTesting
  static bool debugShowTiles = true;

  static LatLng toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);
  static GeoPoint toGeoPoint(LatLng point) =>
      GeoPoint(point.latitude, point.longitude);

  static bool isInDevrek(GeoPoint point) =>
      devrekBounds.contains(toLatLng(point));

  static LatLngBounds boundsOf(DeliveryArea area) {
    final (sw, ne) = area.bounds;
    return LatLngBounds(toLatLng(sw), toLatLng(ne));
  }

  /// Arama kutusu: Devrek alanı ve (varsa) teslimat alanının birleşimi
  static (GeoPoint, GeoPoint) searchBox(DeliveryArea? area) {
    final bounds = LatLngBounds(devrekBounds.southWest, devrekBounds.northEast);
    if (area != null) bounds.extendBounds(boundsOf(area));
    return (toGeoPoint(bounds.southWest), toGeoPoint(bounds.northEast));
  }
}

/// Tam ekran konum seçici. Seçilen noktayı döndürür; vazgeçilirse null.
/// [area]: teslimat alanı (yüklenirken iğne onaylanamaz; null gelirse sınır
/// denetimi yapılmaz, kesin denetimi sunucu yapar).
Future<GeoPoint?> showAddressMapPicker(
  BuildContext context, {
  GeoPoint? initial,
  LocationService locationService = const LocationService(),
  GeocodingService? geocoding,
  Future<DeliveryArea?>? area,
}) {
  return Navigator.of(context).push<GeoPoint>(
    MaterialPageRoute(
      builder: (_) => AddressMapPickerPage(
        initial: initial,
        locationService: locationService,
        geocoding: geocoding,
        area: area,
      ),
    ),
  );
}

List<Widget> _tileLayers() => [
      if (AddressMap.debugShowTiles)
        TileLayer(
          urlTemplate: AddressMap.tileUrl,
          userAgentPackageName: AddressMap.userAgentPackage,
          maxNativeZoom: 19,
        ),
    ];

/// Teslimat alanının dışı hafifçe karartılır, sınır yeşil çizilir.
Widget _areaLayer(DeliveryArea area) {
  // Alanı çok aşan bir çerçeve; alanın dış sınırları bu çerçevede delik
  const outer = [
    LatLng(36, 26),
    LatLng(36, 38),
    LatLng(44, 38),
    LatLng(44, 26),
  ];
  return PolygonLayer(
    polygons: [
      Polygon(
        points: outer,
        holePointsList: [
          for (final rings in area.polygons)
            rings.first.map(AddressMap.toLatLng).toList(),
        ],
        color: MarketPalette.greenDeep.withValues(alpha: .16),
        borderColor: MarketPalette.green,
        borderStrokeWidth: 3,
      ),
    ],
  );
}

/// OSM lisansının istediği kaynak gösterimi
class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(MarketRadius.xs),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text('© OpenStreetMap katkıcıları',
              style:
                  MarketText.caption(size: 11, color: MarketPalette.inkSoft)),
        ),
      );
}

/// Haritanın ortasındaki iğne (ucu tam merkezi gösterir)
class _CenterPin extends StatelessWidget {
  final bool lifted;

  /// İğne teslimat alanının dışında: gri
  final bool outside;

  const _CenterPin({this.lifted = false, this.outside = false});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Center(
        child: AnimatedSlide(
          // İğnenin ucu merkezde dursun: simgenin yarısı kadar yukarı
          offset: Offset(0, lifted ? -.68 : -.5),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
          child: Icon(Icons.location_on_rounded,
              size: 52,
              color: outside ? MarketPalette.subtle : MarketPalette.red,
              shadows: const [
                Shadow(
                    color: Color(0x55000000),
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ]),
        ),
      ),
    );
  }
}

/// Konum izni / servis sonucu (bulunamadıysa)
enum _MapNote { denied, deniedForever, serviceOff, failed }

class AddressMapPickerPage extends StatefulWidget {
  final GeoPoint? initial;
  final LocationService locationService;

  /// İğnenin altındaki mahalle/sokak adını bulur ve adres aramasını yapar
  /// (null: ikisi de gösterilmez)
  final GeocodingService? geocoding;

  /// Teslimat alanı (Devrek sınırı)
  final Future<DeliveryArea?>? area;

  const AddressMapPickerPage({
    super.key,
    this.initial,
    this.locationService = const LocationService(),
    this.geocoding,
    this.area,
  });

  @override
  State<AddressMapPickerPage> createState() => _AddressMapPickerPageState();
}

class _AddressMapPickerPageState extends State<AddressMapPickerPage> {
  final MapController _map = MapController();
  late LatLng _center;
  LatLng? _myLocation;
  bool _locating = false;
  bool _dragging = false;
  bool _mapReady = false;
  _MapNote? _note;

  /// Kamera kullanıcıya göre ayarlandı (konumuna gidildi, kaydırdı ya da
  /// arama sonucu seçti): alan yüklenince harita artık oynatılmaz.
  bool _cameraSettled = false;

  // Teslimat alanı
  DeliveryArea? _area;
  bool _areaLoading = false;
  bool _outside = false;

  // İğnenin altındaki yer adı (iğne durunca sorulur)
  PlaceInfo? _place;
  bool _placeLoading = false;
  Timer? _placeTimer;
  int _placeSeq = 0;

  // Adres arama
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  bool _searching = false;
  List<PlaceSearchResult>? _results;
  bool _searchFailed = false;
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _center = initial != null
        ? AddressMap.toLatLng(initial)
        : AddressMap.devrekCenter;
    _cameraSettled = initial != null;
    final area = widget.area;
    if (area != null) {
      _areaLoading = true;
      unawaited(area.then(_onArea, onError: (_) => _onArea(null)));
    }
    // Yeni adreste harita açılır açılmaz kullanıcının konumu gösterilir.
    if (initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_goToMyLocation(auto: true));
      });
    } else {
      _schedulePlaceLookup();
    }
  }

  @override
  void dispose() {
    _placeTimer?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onArea(DeliveryArea? area) {
    if (!mounted) return;
    setState(() {
      _area = area;
      _areaLoading = false;
      _outside = _isOutside(_center);
    });
    // Konum yoksa harita tüm teslimat alanını gösterecek şekilde açılır
    if (area != null && !_cameraSettled && _mapReady) {
      _map.fitCamera(CameraFit.bounds(
        bounds: AddressMap.boundsOf(area),
        padding: const EdgeInsets.all(28),
      ));
      _center = _map.camera.center;
    }
  }

  bool _isOutside(LatLng point) =>
      _area != null && !_area!.contains(AddressMap.toGeoPoint(point));

  /// Harita durdu (kullanıcı ya da kod taşıdı): alan denetimi ve yer adı.
  void _afterMove() {
    final outside = _isOutside(_center);
    if (outside != _outside || _dragging) {
      setState(() {
        _outside = outside;
        _dragging = false;
      });
    }
    _schedulePlaceLookup();
  }

  void _moveTo(LatLng point, double zoom) {
    _center = point;
    _cameraSettled = true;
    if (_mapReady) _map.move(point, zoom);
    _afterMove();
  }

  /// İğne durduktan kısa süre sonra yer adını sorar; Nominatim kuralı
  /// (saniyede en fazla bir istek) için bekleme süresi 800 ms.
  void _schedulePlaceLookup() {
    final geocoding = widget.geocoding;
    if (geocoding == null) return;
    _placeTimer?.cancel();
    if (!_placeLoading) setState(() => _placeLoading = true);
    final seq = ++_placeSeq;
    _placeTimer = Timer(const Duration(milliseconds: 800), () async {
      final place = await geocoding.reverse(AddressMap.toGeoPoint(_center));
      if (!mounted || seq != _placeSeq) return;
      setState(() {
        _place = place;
        _placeLoading = false;
      });
    });
  }

  /// [auto]: harita açılırken kendiliğinden; kullanıcı bu arada haritayı
  /// kaydırdıysa konumuna zıplatılmaz.
  Future<void> _goToMyLocation({bool auto = false}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _note = null;
    });
    final result = await widget.locationService.currentPoint();
    if (!mounted) return;
    setState(() {
      _locating = false;
      switch (result.outcome) {
        case LocationOutcome.found:
          _myLocation = AddressMap.toLatLng(result.point!);
        case LocationOutcome.denied:
          _note = _MapNote.denied;
        case LocationOutcome.deniedForever:
          _note = _MapNote.deniedForever;
        case LocationOutcome.serviceOff:
          _note = _MapNote.serviceOff;
        case LocationOutcome.failed:
          _note = _MapNote.failed;
      }
    });
    final point = result.point;
    if (result.outcome != LocationOutcome.found || point == null) return;
    // Devrek dışındaysa harita Devrek'te kalır (not gösterilir)
    if (!AddressMap.isInDevrek(point)) return;
    if (auto && _cameraSettled) return;
    _moveTo(AddressMap.toLatLng(point), AddressMap.streetZoom);
  }

  bool get _myLocationOutside =>
      _myLocation != null &&
      !AddressMap.isInDevrek(AddressMap.toGeoPoint(_myLocation!));

  bool get _canConfirm => !_areaLoading && !_outside && !_dragging;

  void _confirm() => Navigator.of(context).pop(AddressMap.toGeoPoint(_center));

  // -------------------------------------------------------------------------
  // Arama
  // -------------------------------------------------------------------------

  Future<void> _search() async {
    final geocoding = widget.geocoding;
    final text = _query.text.trim();
    if (geocoding == null || text.isEmpty) return;
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    final (sw, ne) = AddressMap.searchBox(_area);
    List<PlaceSearchResult>? results;
    var failed = false;
    try {
      results = await geocoding.search(text, southWest: sw, northEast: ne);
    } on GeocodingException {
      failed = true;
    }
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _searching = false;
      _searchFailed = failed;
      _results = results ?? const [];
    });
  }

  void _clearSearch() {
    _searchSeq++;
    _query.clear();
    setState(() {
      _results = null;
      _searching = false;
      _searchFailed = false;
    });
  }

  void _pickResult(PlaceSearchResult result) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _results = null);
    _moveTo(AddressMap.toLatLng(result.point), AddressMap.streetZoom);
  }

  void _closeResults() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_results != null || _searchFailed) {
      setState(() {
        _results = null;
        _searchFailed = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Görünüm
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final initialZoom =
        widget.initial != null ? AddressMap.streetZoom : AddressMap.townZoom;
    final topInset = MediaQuery.paddingOf(context).top;
    final area = _area;

    return Scaffold(
      backgroundColor: MarketPalette.surfaceMuted,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Teslimat konumu haritası. İğneyi kapına getirmek için '
                  'haritayı kaydır.',
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: initialZoom,
                  minZoom: 11,
                  maxZoom: 19,
                  backgroundColor: MarketPalette.surfaceMuted,
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: AddressMap.devrekBounds,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, __) => _closeResults(),
                  onMapReady: () {
                    _mapReady = true;
                    // Konum ya da alan harita hazır olmadan geldiyse şimdi
                    if (_cameraSettled && _center != _map.camera.center) {
                      _map.move(_center, AddressMap.streetZoom);
                    } else if (!_cameraSettled && _area != null) {
                      _onArea(_area);
                    }
                  },
                  onPositionChanged: (camera, hasGesture) {
                    _center = camera.center;
                    if (hasGesture) {
                      _cameraSettled = true;
                      if (!_dragging) setState(() => _dragging = true);
                    }
                  },
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd ||
                        event is MapEventFlingAnimationEnd ||
                        event is MapEventDoubleTapZoomEnd ||
                        event is MapEventScrollWheelZoom) {
                      _afterMove();
                    }
                  },
                ),
                children: [
                  ..._tileLayers(),
                  if (area != null) _areaLayer(area),
                  if (_myLocation != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _myLocation!,
                        radius: 9,
                        color: MarketPalette.blue,
                        borderColor: Colors.white,
                        borderStrokeWidth: 3,
                      ),
                    ]),
                ],
              ),
            ),
          ),
          _CenterPin(lifted: _dragging, outside: _outside && !_dragging),
          // Üst: geri düğmesi ve adres arama
          Positioned(
            top: topInset + 10,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _RoundMapButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Geri',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: widget.geocoding == null
                          ? _buildTitlePill()
                          : _buildSearchField(),
                    ),
                  ],
                ),
                if (_results != null || _searchFailed) ...[
                  const SizedBox(height: 8),
                  _buildResults(),
                ],
              ],
            ),
          ),
          // Sağ alt: konumuma git
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _RoundMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Konumuma git',
                  busy: _locating,
                  onPressed: _goToMyLocation,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: SafeArea(top: false, child: _OsmAttribution()),
          ),
        ],
      ),
      bottomNavigationBar: MarketBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('İğneyi kapına getir', style: MarketText.heading(size: 16)),
            const SizedBox(height: 4),
            if (widget.geocoding != null) ...[
              _PlaceLine(place: _place, loading: _placeLoading),
              const SizedBox(height: 4),
            ],
            Text(
              area != null
                  ? 'Yeşil çizgi teslimat alanımız. Haritayı kaydırarak iğneyi '
                      'binanın üstüne getir.'
                  : 'Haritayı kaydırarak iğneyi binanın üstüne getir. Mahalle '
                      've sokak bilgisi sonraki adımda otomatik dolar.',
              style: MarketText.caption(size: 13),
            ),
            if (_outside && !_dragging) ...[
              const SizedBox(height: 10),
              const MarketNotice(
                icon: Icons.wrong_location_outlined,
                text: 'Bu nokta teslimat alanımızın dışında. İğneyi yeşil '
                    'çizginin içine getir.',
                background: MarketPalette.redSoft,
                foreground: MarketPalette.red,
              ),
            ] else if (_note != null || _myLocationOutside) ...[
              const SizedBox(height: 10),
              _buildNote(),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _canConfirm ? _confirm : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.button),
              ),
              icon: _areaLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_areaLoading
                  ? 'Teslimat alanı yükleniyor…'
                  : 'Bu konumu kullan'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _floatingBox => BoxDecoration(
        color: MarketPalette.surface,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildTitlePill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _floatingBox.copyWith(
            borderRadius: BorderRadius.circular(MarketRadius.pill)),
        child: Text(
          'Teslimat konumunu seç',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MarketText.heading(size: 15),
        ),
      );

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: _floatingBox,
      child: TextField(
        controller: _query,
        focusNode: _queryFocus,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _search(),
        onChanged: (_) => setState(() {}),
        style: MarketText.body(size: 15),
        decoration: InputDecoration(
          hintText: 'Sokak, cadde ya da yer ara',
          filled: true,
          fillColor: MarketPalette.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MarketRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MarketRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MarketRadius.md),
            borderSide:
                const BorderSide(color: MarketPalette.green, width: 1.5),
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: MarketPalette.muted),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: MarketPalette.green),
                  ),
                )
              : _query.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Aramayı temizle',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clearSearch,
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildResults() {
    final results = _results ?? const <PlaceSearchResult>[];
    final Widget body;
    if (_searchFailed) {
      body = _SearchMessage(
        icon: Icons.wifi_off_rounded,
        text: 'Arama yapılamadı. Bağlantını kontrol et ya da iğneyi haritada '
            'kendin konumlandır.',
        action: 'Tekrar dene',
        onAction: _search,
      );
    } else if (results.isEmpty) {
      body = _SearchMessage(
        icon: Icons.search_off_rounded,
        text: '"${_query.text.trim()}" için Devrek\'te sonuç bulamadık. '
            'Haritayı kaydırarak işaretleyebilirsin.',
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 52, color: MarketPalette.line),
        itemBuilder: (context, index) {
          final result = results[index];
          return ListTile(
            onTap: () => _pickResult(result),
            leading: const Icon(Icons.place_outlined,
                color: MarketPalette.greenDark),
            minLeadingWidth: 24,
            title: Text(result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MarketText.label(size: 14)),
            subtitle: result.subtitle.isEmpty
                ? null
                : Text(result.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.caption()),
          );
        },
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: _floatingBox,
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: body),
    );
  }

  Widget _buildNote() {
    if (_myLocationOutside) {
      return const MarketNotice.info(
        icon: Icons.travel_explore_rounded,
        text: 'Şu an Devrek dışında görünüyorsun. Teslimat adresini arayarak '
            'ya da haritada işaretle.',
      );
    }
    final service = widget.locationService;
    final (text, action, onAction) = switch (_note!) {
      _MapNote.denied => (
          'Konum izni verilmedi. Sorun değil, adresini ara ya da iğneyi haritada kendin kapına getir.',
          null,
          null,
        ),
      _MapNote.deniedForever => (
          'Konum izni kapalı. Ayarlardan açabilir ya da iğneyi haritada kendin konumlandırabilirsin.',
          'Ayarları aç',
          service.openAppSettings,
        ),
      _MapNote.serviceOff => (
          'Telefonunun konum servisi kapalı. Açabilir ya da iğneyi haritada kendin konumlandırabilirsin.',
          'Konum ayarlarını aç',
          service.openLocationSettings,
        ),
      _MapNote.failed => (
          'Konumun alınamadı. Adresini ara ya da iğneyi haritada kendin kapına getir.',
          null,
          null,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketNotice.info(icon: Icons.location_disabled_outlined, text: text),
        if (action != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(action),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size(0, MarketSize.control),
            ),
          ),
      ],
    );
  }
}

/// Arama sonucu yok / hata satırı
class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _SearchMessage({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MarketPalette.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: MarketText.caption(size: 13))),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Alt çubukta iğnenin altındaki mahalle · sokak satırı
class _PlaceLine extends StatelessWidget {
  final PlaceInfo? place;
  final bool loading;

  const _PlaceLine({required this.place, required this.loading});

  @override
  Widget build(BuildContext context) {
    final text = place == null
        ? (loading ? 'Adres bulunuyor…' : 'Adres bilgisi bulunamadı')
        : place!.summary;
    return Row(
      children: [
        Icon(
          place == null ? Icons.place_outlined : Icons.place_rounded,
          size: 16,
          color: place == null ? MarketPalette.muted : MarketPalette.greenDark,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MarketText.label(
              size: 13,
              color:
                  place == null ? MarketPalette.muted : MarketPalette.greenDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool busy;

  const _RoundMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MarketPalette.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: MarketPalette.greenDeep.withValues(alpha: .3),
      child: IconButton(
        tooltip: tooltip,
        onPressed: busy ? null : onPressed,
        constraints: const BoxConstraints.tightFor(
            width: MarketSize.tapTarget, height: MarketSize.tapTarget),
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: MarketPalette.green),
              )
            : Icon(icon, color: MarketPalette.greenDark),
      ),
    );
  }
}

/// Formdaki küçük, dokunulmaz harita önizlemesi.
class AddressMapPreview extends StatelessWidget {
  final GeoPoint point;
  final double height;

  const AddressMapPreview({super.key, required this.point, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MarketRadius.md),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: FlutterMap(
                  // Nokta değişince önizleme yeniden kurulur
                  key: ValueKey('${point.lat},${point.lng}'),
                  options: MapOptions(
                    initialCenter: AddressMap.toLatLng(point),
                    initialZoom: AddressMap.streetZoom - 1,
                    backgroundColor: MarketPalette.surfaceMuted,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: _tileLayers(),
                ),
              ),
            ),
            const _CenterPin(),
            const Positioned(left: 6, bottom: 6, child: _OsmAttribution()),
          ],
        ),
      ),
    );
  }
}
