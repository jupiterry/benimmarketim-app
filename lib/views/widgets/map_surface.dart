import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../services/maps_config.dart';
import 'market_ui.dart';

/// Haritayı koddan taşımak için ([MapSurface.onReady] ile gelir).
abstract class MapSurfaceHandle {
  /// Haritanın şu anki merkezi
  LatLng get center;
  void move(LatLng point, double zoom);
  void fit(LatLngBounds bounds);
}

/// Adres haritasının çizildiği yüzey. Google Maps anahtarı varsa Google
/// haritası, yoksa OpenStreetMap (flutter_map) kullanılır; ikisi aynı
/// geri çağrıları verir. Teslimat alanı ([areaRings]) verilirse alanın dışı
/// hafifçe karartılır ve sınırı yeşil çizilir.
class MapSurface extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;

  /// Harita merkezi bu alanın dışına çıkamaz
  final LatLngBounds? centerBounds;

  /// Teslimat alanının dış sınırları
  final List<List<LatLng>> areaRings;

  /// Kullanıcının konumu (mavi nokta)
  final LatLng? myLocation;

  /// false: dokunulmaz önizleme
  final bool interactive;

  /// OSM kaynak gösteriminin kenar boşluğu
  final EdgeInsets attributionPadding;

  final ValueChanged<MapSurfaceHandle>? onReady;

  /// Merkez değişti; [gesture]: kullanıcı kaydırdı
  final void Function(LatLng center, bool gesture)? onMove;

  /// Harita durdu
  final VoidCallback? onIdle;
  final VoidCallback? onTap;

  const MapSurface({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    this.minZoom = 11,
    this.maxZoom = 19,
    this.centerBounds,
    this.areaRings = const [],
    this.myLocation,
    this.interactive = true,
    this.attributionPadding = const EdgeInsets.all(12),
    this.onReady,
    this.onMove,
    this.onIdle,
    this.onTap,
  });

  /// Testlerde gerçek harita çizilmez: OSM karoları indirilmez, Google
  /// haritası (platform görünümü) yerine düz bir yüzey gösterilir.
  static bool debugShowTiles = true;

  /// OSM karo adresi. Trafik büyürse ücretli bir sağlayıcıya (ör. MapTiler)
  /// geçmek için yalnızca bu satır değişir.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackage = 'com.jupi.benimapp.benimmarketim_app';

  /// Alanın dışını kaplayan çerçeve (alanın dış sınırları bunda delik)
  static const _outer = [
    LatLng(36, 26),
    LatLng(36, 38),
    LatLng(44, 38),
    LatLng(44, 26),
  ];

  static Color get _maskColor => MarketPalette.greenDeep.withValues(alpha: .16);

  @override
  State<MapSurface> createState() => _MapSurfaceState();
}

class _MapSurfaceState extends State<MapSurface> {
  @override
  Widget build(BuildContext context) {
    if (!MapsConfig.useGoogle) return _OsmSurface(widget);
    if (!MapSurface.debugShowTiles) return _PlainSurface(widget);
    return _GoogleSurface(widget);
  }
}

// ---------------------------------------------------------------------------
// OpenStreetMap (flutter_map)
// ---------------------------------------------------------------------------

class _OsmSurface extends StatefulWidget {
  final MapSurface config;
  const _OsmSurface(this.config);

  @override
  State<_OsmSurface> createState() => _OsmSurfaceState();
}

class _OsmSurfaceState extends State<_OsmSurface> implements MapSurfaceHandle {
  final MapController _map = MapController();
  bool _ready = false;
  LatLng? _pending;

  MapSurface get c => widget.config;

  @override
  LatLng get center =>
      _ready ? _map.camera.center : (_pending ?? c.initialCenter);

  @override
  void move(LatLng point, double zoom) {
    if (_ready) {
      _map.move(point, zoom);
    } else {
      _pending = point;
    }
  }

  @override
  void fit(LatLngBounds bounds) {
    if (!_ready) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(28),
    ));
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: c.initialCenter,
              initialZoom: c.initialZoom,
              minZoom: c.minZoom,
              maxZoom: c.maxZoom,
              backgroundColor: MarketPalette.surfaceMuted,
              cameraConstraint: c.centerBounds != null
                  ? CameraConstraint.containCenter(bounds: c.centerBounds!)
                  : const CameraConstraint.unconstrained(),
              interactionOptions: InteractionOptions(
                flags: c.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              onTap: (_, __) => c.onTap?.call(),
              onMapReady: () {
                _ready = true;
                final pending = _pending;
                if (pending != null) _map.move(pending, _map.camera.zoom);
                c.onReady?.call(this);
              },
              onPositionChanged: (camera, hasGesture) =>
                  c.onMove?.call(camera.center, hasGesture),
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventDoubleTapZoomEnd ||
                    event is MapEventScrollWheelZoom) {
                  c.onIdle?.call();
                }
              },
            ),
            children: [
              if (MapSurface.debugShowTiles)
                TileLayer(
                  urlTemplate: MapSurface.tileUrl,
                  userAgentPackageName: MapSurface.userAgentPackage,
                  maxNativeZoom: 19,
                ),
              if (c.areaRings.isNotEmpty)
                PolygonLayer(polygons: [
                  Polygon(
                    points: MapSurface._outer,
                    holePointsList: c.areaRings,
                    color: MapSurface._maskColor,
                    borderColor: MarketPalette.green,
                    borderStrokeWidth: 3,
                  ),
                ]),
              if (c.myLocation != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: c.myLocation!,
                    radius: 9,
                    color: MarketPalette.blue,
                    borderColor: Colors.white,
                    borderStrokeWidth: 3,
                  ),
                ]),
            ],
          ),
        ),
        Positioned(
          left: c.attributionPadding.left,
          bottom: c.attributionPadding.bottom,
          child: const _OsmAttribution(),
        ),
      ],
    );
  }
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

// ---------------------------------------------------------------------------
// Google Maps
// ---------------------------------------------------------------------------

gm.LatLng _gm(LatLng p) => gm.LatLng(p.latitude, p.longitude);

class _GoogleSurface extends StatefulWidget {
  final MapSurface config;
  const _GoogleSurface(this.config);

  @override
  State<_GoogleSurface> createState() => _GoogleSurfaceState();
}

class _GoogleSurfaceState extends State<_GoogleSurface>
    implements MapSurfaceHandle {
  gm.GoogleMapController? _controller;
  late LatLng _center = widget.config.initialCenter;

  /// Kamera koddan taşınıyor: bu sırada gelen hareketler kullanıcının değil.
  /// Kamera aynı yerdeyse "durdu" gelmeyebilir; bayrak kısa süre sonra düşer.
  bool _programmatic = false;
  Timer? _programmaticTimer;

  MapSurface get c => widget.config;

  @override
  LatLng get center => _center;

  void _markProgrammatic() {
    _programmatic = true;
    _programmaticTimer?.cancel();
    _programmaticTimer = Timer(const Duration(milliseconds: 1500), () {
      _programmatic = false;
    });
  }

  @override
  void move(LatLng point, double zoom) {
    _center = point;
    _markProgrammatic();
    unawaited(_controller
        ?.animateCamera(gm.CameraUpdate.newLatLngZoom(_gm(point), zoom)));
  }

  @override
  void fit(LatLngBounds bounds) {
    _markProgrammatic();
    unawaited(_controller?.moveCamera(gm.CameraUpdate.newLatLngBounds(
      gm.LatLngBounds(
        southwest: _gm(bounds.southWest),
        northeast: _gm(bounds.northEast),
      ),
      28,
    )));
  }

  @override
  void dispose() {
    _programmaticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = c.centerBounds;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: _gm(c.initialCenter),
        zoom: c.initialZoom,
      ),
      minMaxZoomPreference: gm.MinMaxZoomPreference(c.minZoom, c.maxZoom),
      cameraTargetBounds: bounds == null
          ? gm.CameraTargetBounds.unbounded
          : gm.CameraTargetBounds(gm.LatLngBounds(
              southwest: _gm(bounds.southWest),
              northeast: _gm(bounds.northEast),
            )),
      liteModeEnabled: !c.interactive,
      scrollGesturesEnabled: c.interactive,
      zoomGesturesEnabled: c.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      // Konum izni verildiyse (konum bulunduysa) Google'ın mavi noktası
      myLocationEnabled: c.myLocation != null,
      polygons: {
        if (c.areaRings.isNotEmpty)
          gm.Polygon(
            polygonId: const gm.PolygonId('teslimat-alani'),
            points: MapSurface._outer.map(_gm).toList(),
            holes: [
              for (final ring in c.areaRings) ring.map(_gm).toList(),
            ],
            fillColor: MapSurface._maskColor,
            strokeColor: MarketPalette.green,
            strokeWidth: 3,
            consumeTapEvents: false,
          ),
      },
      onMapCreated: (controller) {
        _controller = controller;
        c.onReady?.call(this);
      },
      onCameraMove: (position) {
        _center = LatLng(position.target.latitude, position.target.longitude);
        c.onMove?.call(_center, !_programmatic);
      },
      onCameraIdle: () {
        _programmatic = false;
        c.onIdle?.call();
      },
      onTap: (_) => c.onTap?.call(),
    );
  }
}

/// Google seçiliyken testlerde platform görünümü yerine düz yüzey.
class _PlainSurface extends StatefulWidget {
  final MapSurface config;
  const _PlainSurface(this.config);

  @override
  State<_PlainSurface> createState() => _PlainSurfaceState();
}

class _PlainSurfaceState extends State<_PlainSurface>
    implements MapSurfaceHandle {
  late LatLng _center = widget.config.initialCenter;

  @override
  LatLng get center => _center;

  @override
  void move(LatLng point, double zoom) => _center = point;

  @override
  void fit(LatLngBounds bounds) => _center = bounds.center;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onReady?.call(this);
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.config.onTap,
        child: const ColoredBox(color: MarketPalette.surfaceMuted),
      );
}
