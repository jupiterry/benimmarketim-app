import 'package:flutter/material.dart';

/// Lazily mounts tabs and retains their state across navigation.
///
/// Sekme değişince yeni sayfa, gidilen yönden hafifçe kayarak ve solarak
/// gelir (sağdaki sekmeye geçerken sağdan, soldakine dönerken soldan).
/// Kayma küçüktür (ekranın ~%4'ü); içerik yer değiştirmiş gibi değil,
/// yerine oturmuş gibi hissettirir. Hareket azaltma açıksa anında geçer.
class MarketTabStack extends StatefulWidget {
  const MarketTabStack(
      {super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<MarketTabStack> createState() => _MarketTabStackState();
}

class _MarketTabStackState extends State<MarketTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubicEmphasized,
  );
  late final Animation<double> _opacity =
      Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
    parent: _controller,
    // Solma kaymadan önce biter; sayfa hâlâ yerine otururken net görünür
    curve: const Interval(0, .6, curve: Curves.easeOut),
  ));
  late Animation<Offset> _slide = _slideFrom(0);
  final Set<int> _visited = {};

  Animation<Offset> _slideFrom(double direction) =>
      Tween<Offset>(begin: Offset(.04 * direction, 0), end: Offset.zero)
          .animate(_curve);

  @override
  void didUpdateWidget(covariant MarketTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _slide = _slideFrom((widget.index - oldWidget.index).sign.toDouble());
        // Yeni sayfa ilk kez açılıyorsa kurulumu uzun sürer; animasyon o
        // sırada zamanla ilerleyip ilk karede bitmiş olurdu. Geçiş başta
        // bekletilir, sayfanın ilk karesi çizilince başlar.
        _controller.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.forward(from: 0);
        });
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: widget.index,
          sizing: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              TickerMode(
                enabled: i == widget.index,
                // Gizli sekmelerdeki ürün görselleri Hero geçişine katılmaz;
                // aynı ürün hem ana sayfada hem sepet önerilerinde olunca
                // "aynı etiketli birden fazla Hero" hatası oluşuyordu.
                child: HeroMode(
                  enabled: i == widget.index,
                  child: _visited.contains(i)
                      ? RepaintBoundary(child: widget.children[i])
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
