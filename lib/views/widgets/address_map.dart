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
/// `location: {lat, lng}` olarak kaydedilir.
abstract final class AddressMap {
  /// Devrek ilçe merkezi
  static const LatLng devrekCenter = LatLng(41.2194, 31.9558);

  /// Devrek ilçesini (mahalleler ve köyler) kapsayan alan. Harita merkezi bu
  /// alanın dışına çıkamaz; iğne her zaman teslimat bölgesinde kalır.
  static final LatLngBounds devrekBounds = LatLngBounds(
    const LatLng(41.03, 31.72),
    const LatLng(41.40, 32.18),
  );

  static const double townZoom = 13;
  static const double streetZoom = 17;

  /// OSM karo adresi. Trafik büyürse ücretli bir sağlayıcıya (ör. MapTiler)
  /// geçmek için yalnızca bu satır değişir.
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackage = 'com.jupi.benimapp.benimmarketim_app';

  /// Testlerde ağdan karo indirilmez.
  @visibleForTesting
  static bool debugShowTiles = true;

  static LatLng toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);
  static GeoPoint toGeoPoint(LatLng point) =>
      GeoPoint(point.latitude, point.longitude);

  static bool isInDevrek(GeoPoint point) =>
      devrekBounds.contains(toLatLng(point));
}

/// Tam ekran konum seçici. Seçilen noktayı döndürür; vazgeçilirse null.
Future<GeoPoint?> showAddressMapPicker(
  BuildContext context, {
  GeoPoint? initial,
  LocationService locationService = const LocationService(),
  GeocodingService? geocoding,
}) {
  return Navigator.of(context).push<GeoPoint>(
    MaterialPageRoute(
      builder: (_) => AddressMapPickerPage(
        initial: initial,
        locationService: locationService,
        geocoding: geocoding,
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
              style: MarketText.caption(size: 11, color: MarketPalette.inkSoft)),
        ),
      );
}

/// Haritanın ortasındaki iğne (ucu tam merkezi gösterir)
class _CenterPin extends StatelessWidget {
  final bool lifted;

  const _CenterPin({this.lifted = false});

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
          child: const Icon(Icons.location_on_rounded,
              size: 52, color: MarketPalette.red, shadows: [
            Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
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

  /// İğnenin altındaki mahalle/sokak adını bulur (null: gösterilmez)
  final GeocodingService? geocoding;

  const AddressMapPickerPage({
    super.key,
    this.initial,
    this.locationService = const LocationService(),
    this.geocoding,
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

  // İğnenin altındaki yer adı (iğne durunca sorulur)
  PlaceInfo? _place;
  bool _placeLoading = false;
  Timer? _placeTimer;
  int _placeSeq = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _center = initial != null
        ? AddressMap.toLatLng(initial)
        : AddressMap.devrekCenter;
    // Yeni adreste harita açılır açılmaz kullanıcının konumu gösterilir.
    if (initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_goToMyLocation());
      });
    } else {
      _schedulePlaceLookup();
    }
  }

  @override
  void dispose() {
    _placeTimer?.cancel();
    _map.dispose();
    super.dispose();
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

  Future<void> _goToMyLocation() async {
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
          final point = AddressMap.toLatLng(result.point!);
          _myLocation = point;
          if (AddressMap.isInDevrek(result.point!)) {
            _center = point;
            if (_mapReady) _map.move(point, AddressMap.streetZoom);
            _schedulePlaceLookup();
          } else {
            _note = null; // Bölge dışındaysa harita Devrek'te kalır
          }
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
  }

  bool get _myLocationOutside =>
      _myLocation != null &&
      !AddressMap.isInDevrek(AddressMap.toGeoPoint(_myLocation!));

  void _confirm() =>
      Navigator.of(context).pop(AddressMap.toGeoPoint(_center));

  @override
  Widget build(BuildContext context) {
    final initialZoom = widget.initial != null
        ? AddressMap.streetZoom
        : AddressMap.townZoom;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: MarketPalette.surfaceMuted,
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
                  onMapReady: () {
                    _mapReady = true;
                    // Konum harita hazır olmadan geldiyse şimdi gidilir
                    if (_center != _map.camera.center) {
                      _map.move(_center, AddressMap.streetZoom);
                    }
                  },
                  onPositionChanged: (camera, hasGesture) {
                    _center = camera.center;
                    if (hasGesture && !_dragging) {
                      setState(() => _dragging = true);
                    }
                  },
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd ||
                        event is MapEventFlingAnimationEnd ||
                        event is MapEventDoubleTapZoomEnd ||
                        event is MapEventScrollWheelZoom) {
                      if (_dragging) setState(() => _dragging = false);
                      _schedulePlaceLookup();
                    }
                  },
                ),
                children: [
                  ..._tileLayers(),
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
          _CenterPin(lifted: _dragging),
          // Üst: geri düğmesi ve başlık
          Positioned(
            top: topInset + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _RoundMapButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MarketPalette.surface,
                      borderRadius: BorderRadius.circular(MarketRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: MarketPalette.greenDeep.withValues(alpha: .12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Teslimat konumunu seç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.heading(size: 15),
                    ),
                  ),
                ),
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
              'Haritayı kaydırarak iğneyi binanın üstüne getir. Mahalle ve '
              'sokak bilgisi sonraki adımda otomatik dolar.',
              style: MarketText.caption(size: 13),
            ),
            if (_note != null || _myLocationOutside) ...[
              const SizedBox(height: 10),
              _buildNote(),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _confirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(MarketSize.button),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Bu konumu kullan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNote() {
    if (_myLocationOutside) {
      return const MarketNotice.info(
        icon: Icons.travel_explore_rounded,
        text: 'Şu an Devrek dışında görünüyorsun. Teslimat adresini Devrek '
            'haritasında işaretle.',
      );
    }
    final service = widget.locationService;
    final (text, action, onAction) = switch (_note!) {
      _MapNote.denied => (
          'Konum izni verilmedi. Sorun değil, iğneyi haritada kendin kapına getir.',
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
          'Konumun alınamadı. İğneyi haritada kendin kapına getirebilirsin.',
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

/// Alt çubukta iğnenin altındaki mahalle · sokak satırı
class _PlaceLine extends StatelessWidget {
  final PlaceInfo? place;
  final bool loading;

  const _PlaceLine({required this.place, required this.loading});

  @override
  Widget build(BuildContext context) {
    final text = place == null
        ? (loading ? 'Adres bulunuyor…' : 'Mahalle bilgisi bulunamadı')
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
              color: place == null ? MarketPalette.muted : MarketPalette.greenDark,
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
