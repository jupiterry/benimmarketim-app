import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/image_url.dart';
import 'market_system_frame.dart';
import 'market_ui.dart';

/// Ürün görselini beyaz, tam ekran bir görüntüleyicide açar (ürün detayındaki
/// görsele dokununca). Görsel yoksa hiçbir şey yapmaz.
Future<void> showProductImageViewer(BuildContext context, Product product) {
  if (product.image.trim().isEmpty) return Future<void>.value();
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final duration =
      reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, __, ___) => ProductImageViewer(product: product),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Tam ekran ürün görseli: iki parmakla ya da iki kez dokunarak
/// yakınlaştırılır (en fazla 4x). Yakınlaştırılmamışken aşağı/yukarı
/// sürükleyince kapanır. Ürün detayıyla aynı Hero etiketini kullanır.
class ProductImageViewer extends StatefulWidget {
  final Product product;

  const ProductImageViewer({super.key, required this.product});

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;
  static const double _dismissDistance = 120;

  final TransformationController _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;
  Animation<double>? _dragAnimation;
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _animation.addListener(_onAnimate);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _animation.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onAnimate() {
    final zoom = _zoomAnimation;
    if (zoom != null) _transform.value = zoom.value;
    final drag = _dragAnimation;
    if (drag != null) setState(() => _dragOffset = drag.value);
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Çift dokunuş: 1x ↔ 2.5x, dokunulan nokta yerinde kalır.
  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      final p = _doubleTapAt;
      target = Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
        ..setTranslationRaw(
          p.dx * (1 - _doubleTapScale),
          p.dy * (1 - _doubleTapScale),
          0,
        );
    }
    if (_reduceMotion) {
      _transform.value = target;
      if (_dragOffset != 0) setState(() => _dragOffset = 0);
      return;
    }
    _zoomAnimation = Matrix4Tween(begin: _transform.value, end: target)
        .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    // Bırakılan sürüklemenin geri dönüşü yarıda kaldıysa yakınlaştırmayla
    // birlikte tamamlanır; görsel kaymış ve zemin yarı saydam kalmaz.
    _dragAnimation = _dragOffset == 0
        ? null
        : Tween<double>(begin: _dragOffset, end: 0).animate(
            CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
          );
    _animation.forward(from: 0);
  }

  /// Görsel geri dönerken yeniden sürüklenirse parmağı izler: dönüş olduğu
  /// yerde durur (süren bir yakınlaştırma da hedefine atlar).
  void _onDragStart(DragStartDetails details) {
    _dragAnimation = null;
    if (_animation.isAnimating) _animation.value = 1;
    _zoomAnimation = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.abs() > _dismissDistance || velocity.abs() > 900) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_reduceMotion) {
      setState(() => _dragOffset = 0);
      return;
    }
    _zoomAnimation = null;
    _dragAnimation = Tween<double>(begin: _dragOffset, end: 0)
        .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final gutter = MarketSpace.gutterOf(context);
    // Sürükledikçe zemin saydamlaşır; alttaki sayfa görünmeye başlar.
    final fade = 1 - (_dragOffset.abs() / 400).clamp(0.0, .6);

    return MarketStatusBand(
      color: MarketPalette.surface,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: MarketPalette.surface.withValues(alpha: fade),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: GestureDetector(
                  onDoubleTapDown: (details) =>
                      _doubleTapAt = details.localPosition,
                  onDoubleTap: _toggleZoom,
                  onVerticalDragStart: _zoomed ? null : _onDragStart,
                  onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
                  onVerticalDragEnd: _zoomed ? null : _onDragEnd,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 4,
                    panEnabled: _zoomed,
                    child: SizedBox.expand(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          MarketSize.tapTarget + 24,
                          gutter,
                          72,
                        ),
                        child: Semantics(
                          image: true,
                          label: 'Ürün görseli: ${productDisplayName(product.name)}',
                          child: Hero(
                            tag: 'product_image_${product.id}',
                            child: _ViewerImage(url: product.image),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: gutter,
              child: _CloseButton(onTap: () => Navigator.of(context).maybePop()),
            ),
            Positioned(
              left: gutter,
              right: gutter,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: MarketSpace.lg),
                  child: AnimatedOpacity(
                    opacity: _zoomed || _dragOffset != 0 ? 0 : 1,
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: Text(
                      'Yakınlaştırmak için iki kez dokun',
                      textAlign: TextAlign.center,
                      style: MarketText.caption(size: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yüksek çözünürlüklü görsel; gelene kadar detay sayfasında zaten yüklü
/// olan görsel gösterilir.
class _ViewerImage extends StatelessWidget {
  final String url;

  const _ViewerImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final detail = Image.network(
      optimizedImageUrl(url, width: MarketImageSize.detail),
      fit: BoxFit.contain,
      cacheWidth: 850,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: MarketPalette.subtle,
          size: 64,
        ),
      ),
    );
    return Image.network(
      optimizedImageUrl(url, width: MarketImageSize.banner),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) =>
          frame != null || sync ? child : detail,
      errorBuilder: (_, __, ___) => detail,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Kapat',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: 'Kapat',
        excludeFromSemantics: true,
        child: Material(
          color: MarketPalette.surface,
          shape: const CircleBorder(side: BorderSide(color: MarketPalette.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox.square(
              dimension: MarketSize.tapTarget,
              child: Icon(
                Icons.close_rounded,
                color: MarketPalette.ink,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
