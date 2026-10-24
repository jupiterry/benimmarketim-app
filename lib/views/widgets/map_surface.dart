import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../models/delivery.dart';
import 'market_ui.dart';

/// Haritayı koddan taşımak için ([MapSurface.onReady] ile gelir).
abstract class MapSurfaceHandle {
  /// Haritanın şu anki merkezi
  LatLng get center;
  void move(LatLng point, double zoom);
  void fit(LatLngBounds bounds);
}

/// Adres haritasının çizildiği yüzey: MapLibre (vektör harita, OpenFreeMap
/// karoları; anahtar gerekmez). Teslimat alanı ([area]) verilirse alanın
/// dışı hafifçe karartılır ve sınırı yeşil çizilir.
///
/// Alan, sınır ve konum noktası stil yüklenince bir kez eklenen GeoJSON
/// katmanlarıdır; değişince yalnızca verileri güncellenir (yanıp sönmez,
/// üst üste binmez). Katmanlar dokunmayı yutmaz, [onTap] her yerde gelir.
class MapSurface extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;

  /// Harita merkezi bu alanın dışına çıkamaz
  final LatLngBounds? centerBounds;

  /// Teslimat alanı (aynı nesne geldikçe yeniden çizilmez)
  final DeliveryArea? area;

  /// Kullanıcının konumu (mavi nokta)
  final LatLng? myLocation;

  /// false: dokunulmaz önizleme
  final bool interactive;

  /// MapLibre kaynak düğmesinin (ⓘ) sol alt köşeden uzaklığı
  final EdgeInsets attributionPadding;

  /// Harita stili yüklendi, taşınabilir
  final ValueChanged<MapSurfaceHandle>? onReady;

  /// Merkez değişti; [gesture]: kullanıcı kaydırdı. Harita durunca son
  /// konum `gesture: false` ile bir kez daha gelir.
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
    this.area,
    this.myLocation,
    this.interactive = true,
    this.attributionPadding = const EdgeInsets.all(12),
    this.onReady,
    this.onMove,
    this.onIdle,
    this.onTap,
  });

  /// Testlerde gerçek harita (platform görünümü) yerine düz bir yüzey.
  static bool debugShowTiles = true;

  /// Harita stili. OpenFreeMap ücretsizdir ve anahtar istemez; başka bir
  /// sağlayıcıya (ör. MapTiler) geçmek için yalnızca bu satır değişir.
  static const String styleUrl = MapLibreStyles.openfreemapLiberty;

  @override
  State<MapSurface> createState() => _MapSurfaceState();
}

class _MapSurfaceState extends State<MapSurface> {
  @override
  Widget build(BuildContext context) {
    if (!MapSurface.debugShowTiles) return _PlainSurface(widget);
    return _MapLibreSurface(widget);
  }
}

// ---------------------------------------------------------------------------
// GeoJSON (koordinatlar [boylam, enlem])
// ---------------------------------------------------------------------------

/// Alanın dışını kaplayan çerçeve (alanın dış sınırları bunda delik)
const _outerRing = [
  [26.0, 36.0],
  [38.0, 36.0],
  [38.0, 44.0],
  [26.0, 44.0],
  [26.0, 36.0],
];

List<List<double>> _ring(List<GeoPoint> ring) => [
      for (final p in ring) [p.lng, p.lat],
    ];

Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
      'type': 'FeatureCollection',
      'features': features,
    };

Map<String, dynamic> _feature(String type, Object coordinates) => {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {'type': type, 'coordinates': coordinates},
    };

/// Karartma: çerçeve eksi teslimat alanları; alanların içindeki delikler
/// (teslimat yok) ayrıca karartılır.
Map<String, dynamic> _maskData(DeliveryArea? area) {
  if (area == null) return _collection(const []);
  return _collection([
    _feature('Polygon', [
      _outerRing,
      for (final rings in area.polygons) _ring(rings.first),
    ]),
    for (final rings in area.polygons)
      for (final hole in rings.skip(1)) _feature('Polygon', [_ring(hole)]),
  ]);
}

/// Sınır: tüm halkalar (çok parçalı alan ve delikler dahil)
Map<String, dynamic> _borderData(DeliveryArea? area) {
  if (area == null) return _collection(const []);
  return _collection([
    for (final rings in area.polygons)
      for (final ring in rings) _feature('LineString', _ring(ring)),
  ]);
}

Map<String, dynamic> _pointData(LatLng? point) => _collection([
      if (point != null) _feature('Point', [point.longitude, point.latitude]),
    ]);

/// MapLibre renkleri "#RRGGBB" ister
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// ---------------------------------------------------------------------------
// MapLibre
// ---------------------------------------------------------------------------

class _MapLibreSurface extends StatefulWidget {
  final MapSurface config;
  const _MapLibreSurface(this.config);

  @override
  State<_MapLibreSurface> createState() => _MapLibreSurfaceState();
}

class _MapLibreSurfaceState extends State<_MapLibreSurface>
    implements MapSurfaceHandle {
  static const _maskSource = 'teslimat-maske';
  static const _borderSource = 'teslimat-sinir';
  static const _locationSource = 'konumum';

  MapLibreMapController? _controller;
  bool _layersReady = false;
  late LatLng _center = widget.config.initialCenter;

  /// Kamera koddan taşınıyor: bu sırada gelen hareketler kullanıcının değil.
  /// Harita durunca (idle) ya da kısa süre sonra düşer.
  bool _programmatic = false;
  Timer? _programmaticTimer;

  /// Katman güncellemeleri sırayla gider
  Future<void> _jobs = Future.value();

  @override
  void initState() {
    super.initState();
    // Android: harita TextureView'a çizilir ve Flutter katmanı olarak
    // birleştirilir. Varsayılan GLSurfaceView + "virtual display" modu,
    // üstüne Flutter içeriği binen (iğne, arama, kart), kırpılan (önizleme)
    // ve aynı anda iki tane açık kalan haritalarda kırılgandır; emülatörde
    // uygulamayı kapatabiliyor. İlk harita kurulmadan ayarlanmalı.
    MapLibreMap.useHybridComposition = true;
  }

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
    unawaited(
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(point, zoom)));
  }

  @override
  void fit(LatLngBounds bounds) {
    _markProgrammatic();
    unawaited(_controller?.moveCamera(CameraUpdate.newLatLngBounds(
      bounds,
      left: 28,
      top: 28,
      right: 28,
      bottom: 28,
    )));
  }

  void _queue(Future<void> Function(MapLibreMapController controller) job) {
    _jobs = _jobs.then((_) async {
      final controller = _controller;
      if (!mounted || controller == null) return;
      try {
        await job(controller);
      } catch (e) {
        debugPrint('Harita katmanı güncellenemedi: $e');
      }
    });
  }

  /// Stil yüklenince kaynaklar ve katmanlar bir kez eklenir.
  void _addLayers() {
    _queue((map) async {
      await map.addGeoJsonSource(_maskSource, _maskData(c.area));
      await map.addGeoJsonSource(_borderSource, _borderData(c.area));
      await map.addGeoJsonSource(_locationSource, _pointData(c.myLocation));
      await map.addFillLayer(
        _maskSource,
        '$_maskSource-katman',
        FillLayerProperties(
          fillColor: _hex(MarketPalette.greenDeep),
          fillOpacity: .16,
        ),
        enableInteraction: false,
      );
      await map.addLineLayer(
        _borderSource,
        '$_borderSource-katman',
        LineLayerProperties(
          lineColor: _hex(MarketPalette.green),
          lineWidth: 3,
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await map.addCircleLayer(
        _locationSource,
        '$_locationSource-katman',
        CircleLayerProperties(
          circleRadius: 8,
          circleColor: _hex(MarketPalette.blue),
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
        enableInteraction: false,
      );
      _layersReady = true;
    });
  }

  @override
  void didUpdateWidget(covariant _MapLibreSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final area = c.area;
    if (!identical(area, oldWidget.config.area)) {
      _queue((map) async {
        if (!_layersReady) return;
        await map.setGeoJsonSource(_maskSource, _maskData(area));
        await map.setGeoJsonSource(_borderSource, _borderData(area));
      });
    }
    final location = c.myLocation;
    if (location != oldWidget.config.myLocation) {
      _queue((map) async {
        if (!_layersReady) return;
        await map.setGeoJsonSource(_locationSource, _pointData(location));
      });
    }
  }

  @override
  void dispose() {
    _programmaticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = c.centerBounds;
    return MapLibreMap(
      styleString: MapSurface.styleUrl,
      initialCameraPosition: CameraPosition(
        target: c.initialCenter,
        zoom: c.initialZoom,
      ),
      minMaxZoomPreference: MinMaxZoomPreference(c.minZoom, c.maxZoom),
      cameraTargetBounds: bounds == null
          ? CameraTargetBounds.unbounded
          : CameraTargetBounds(bounds),
      trackCameraPosition: true,
      scrollGesturesEnabled: c.interactive,
      zoomGesturesEnabled: c.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      // Nesne sürükleme yok (Android'de her kaydırmada sorgu yapmasın)
      dragEnabled: false,
      // Hazır nesne (annotation) katmanı kullanılmıyor; dokunmalar haritaya
      // gelir (liste en az bir öğe ister, sembol hiç eklenmez).
      annotationOrder: const [],
      annotationConsumeTapEvents: const [AnnotationType.symbol],
      // Kaynak bilgisi: MapLibre'nin kendi (ⓘ) düğmesi, sol altta
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: Point(
        c.attributionPadding.left,
        c.attributionPadding.bottom,
      ),
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () {
        _addLayers();
        c.onReady?.call(this);
      },
      onCameraMove: (position) {
        _center = position.target;
        c.onMove?.call(_center, !_programmatic);
      },
      onCameraIdle: () {
        _programmatic = false;
        // Son konum yalnızca durunca kesinleşir (iOS'ta animasyonsuz
        // taşımada hareket bildirimi hiç gelmez)
        final position = _controller?.cameraPosition;
        if (position != null) {
          _center = position.target;
          c.onMove?.call(_center, false);
        }
        c.onIdle?.call();
      },
      onMapClick: (_, __) => c.onTap?.call(),
    );
  }
}

// ---------------------------------------------------------------------------
// Testler için düz yüzey
// ---------------------------------------------------------------------------

/// Testlerde platform görünümü yerine düz yüzey. Taşıma, gerçek harita gibi
/// bir sonraki adımda "hareket + durdu" olarak bildirilir.
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

  void _settle(LatLng point) {
    _center = point;
    scheduleMicrotask(() {
      if (!mounted) return;
      widget.config.onMove?.call(_center, false);
      widget.config.onIdle?.call();
    });
  }

  @override
  void move(LatLng point, double zoom) => _settle(point);

  @override
  void fit(LatLngBounds bounds) => _settle(LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ));

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
