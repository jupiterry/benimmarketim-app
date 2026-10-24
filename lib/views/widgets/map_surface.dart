import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'market_ui.dart';

/// Haritayı koddan taşımak için ([MapSurface.onReady] ile gelir).
abstract class MapSurfaceHandle {
  /// Haritanın şu anki merkezi
  LatLng get center;
  void move(LatLng point, double zoom);
  void fit(LatLngBounds bounds);
}

/// Adres haritasının çizildiği yüzey: MapLibre (vektör harita, OpenFreeMap
/// karoları; anahtar gerekmez). Teslimat alanı ([areaRings]) verilirse
/// alanın dışı hafifçe karartılır ve sınırı yeşil çizilir.
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

  /// Kaynak gösteriminin kenar boşluğu
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

  /// Testlerde gerçek harita (platform görünümü) yerine düz bir yüzey.
  static bool debugShowTiles = true;

  /// Harita stili. OpenFreeMap ücretsizdir ve anahtar istemez; başka bir
  /// sağlayıcıya (ör. MapTiler) geçmek için yalnızca bu satır değişir.
  static const String styleUrl = MapLibreStyles.openfreemapLiberty;

  /// Alanın dışını kaplayan çerçeve (alanın dış sınırları bunda delik)
  static const _outer = [
    LatLng(36, 26),
    LatLng(36, 38),
    LatLng(44, 38),
    LatLng(44, 26),
    LatLng(36, 26),
  ];

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

/// MapLibre renkleri "#RRGGBB" ister
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Lisans gereği kaynak gösterimi
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(MarketRadius.xs),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text('© OpenStreetMap katkıcıları · OpenFreeMap',
              style:
                  MarketText.caption(size: 11, color: MarketPalette.inkSoft)),
        ),
      );
}

class _MapLibreSurface extends StatefulWidget {
  final MapSurface config;
  const _MapLibreSurface(this.config);

  @override
  State<_MapLibreSurface> createState() => _MapLibreSurfaceState();
}

class _MapLibreSurfaceState extends State<_MapLibreSurface>
    implements MapSurfaceHandle {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  late LatLng _center = widget.config.initialCenter;

  /// Kamera koddan taşınıyor: bu sırada gelen hareketler kullanıcının değil.
  /// Hareket bitince (idle) ya da kısa süre sonra düşer.
  bool _programmatic = false;
  Timer? _programmaticTimer;

  // Çizili katmanlar (alan, sınır, konum); veri değişince yeniden çizilir
  Fill? _mask;
  Line? _border;
  Circle? _myLocation;

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

  @override
  void didUpdateWidget(covariant _MapLibreSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleLoaded) return;
    if (c.areaRings != oldWidget.config.areaRings) unawaited(_drawArea());
    if (c.myLocation != oldWidget.config.myLocation) {
      unawaited(_drawMyLocation());
    }
  }

  @override
  void dispose() {
    _programmaticTimer?.cancel();
    super.dispose();
  }

  Future<void> _drawArea() async {
    final controller = _controller;
    if (controller == null) return;
    if (_mask != null) await controller.removeFill(_mask!);
    if (_border != null) await controller.removeLine(_border!);
    _mask = null;
    _border = null;
    if (c.areaRings.isEmpty) return;
    _mask = await controller.addFill(FillOptions(
      geometry: [MapSurface._outer, ...c.areaRings],
      fillColor: _hex(MarketPalette.greenDeep),
      fillOpacity: .16,
    ));
    _border = await controller.addLine(LineOptions(
      // Sınır çizgisi: ayrı halkalar tek çizgide birleşmesin diye yalnızca
      // ilk halka çizilir; alan çok parçalıysa dolgu zaten dışı karartır.
      geometry: c.areaRings.first,
      lineColor: _hex(MarketPalette.green),
      lineWidth: 3,
    ));
  }

  Future<void> _drawMyLocation() async {
    final controller = _controller;
    if (controller == null) return;
    if (_myLocation != null) await controller.removeCircle(_myLocation!);
    _myLocation = null;
    final point = c.myLocation;
    if (point == null) return;
    _myLocation = await controller.addCircle(CircleOptions(
      geometry: point,
      circleRadius: 8,
      circleColor: _hex(MarketPalette.blue),
      circleStrokeColor: '#ffffff',
      circleStrokeWidth: 3,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bounds = c.centerBounds;
    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
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
            dragEnabled: c.interactive,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            // Kaynak gösterimi alttaki kendi satırımızda
            attributionButtonPosition: AttributionButtonPosition.topRight,
            attributionButtonMargins: const Point(-100, -100),
            onMapCreated: (controller) {
              _controller = controller;
            },
            onStyleLoadedCallback: () {
              _styleLoaded = true;
              unawaited(_drawArea());
              unawaited(_drawMyLocation());
              c.onReady?.call(this);
            },
            onCameraMove: (position) {
              _center = position.target;
              c.onMove?.call(_center, !_programmatic);
            },
            onCameraIdle: () {
              _programmatic = false;
              final position = _controller?.cameraPosition;
              if (position != null) _center = position.target;
              c.onIdle?.call();
            },
            onMapClick: (_, __) => c.onTap?.call(),
          ),
        ),
        Positioned(
          left: c.attributionPadding.left,
          bottom: c.attributionPadding.bottom,
          child: const _Attribution(),
        ),
      ],
    );
  }
}

/// Testlerde platform görünümü yerine düz yüzey.
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
  void fit(LatLngBounds bounds) => _center = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onReady?.call(this);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.config.onTap,
              child: const ColoredBox(color: MarketPalette.surfaceMuted),
            ),
          ),
          Positioned(
            left: widget.config.attributionPadding.left,
            bottom: widget.config.attributionPadding.bottom,
            child: const _Attribution(),
          ),
        ],
      );
}
