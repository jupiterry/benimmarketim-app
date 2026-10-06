import 'package:flutter/material.dart';

/// Uygulamanın kaydırma davranışı: sayfa en üstteyken aşağı çekildiğinde
/// içerik yerinden oynamaz (yeşil başlığın üstünde boşluk açılmaz), aşağıda
/// ise alışılmış esneme korunur. Yenileme göstergesi (RefreshIndicator)
/// bu fizikle de çalışır.
class MarketScrollPhysics extends BouncingScrollPhysics {
  const MarketScrollPhysics({super.parent});

  @override
  MarketScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      MarketScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Yatay listeler (ürün rafları) eskisi gibi iki uçta da esner
    if (position.axis != Axis.vertical) {
      return super.applyBoundaryConditions(position, value);
    }
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels; // en üstteyken daha fazla çekme
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent; // hızla üst kenara varma
    }
    return 0.0;
  }
}

/// Fiziği açıkça belirtmeyen tüm listeler için varsayılan davranış. iOS'te
/// üst kenar sabitlenir; Android zaten üstte esnemediği için değişmez.
class MarketScrollBehavior extends MaterialScrollBehavior {
  const MarketScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const MarketScrollPhysics();
      default:
        return super.getScrollPhysics(context);
    }
  }
}
