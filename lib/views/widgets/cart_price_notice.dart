import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/cart_viewmodel.dart';
import 'market_ui.dart';

/// Sepet sunucudan yeniden fiyatlanıp bir kalemin fiyatı değişince (ör. flash
/// sale bitti) hangi ekranda olunursa olsun kısa bir bilgi gösterir.
/// Uygulamanın kökünde (main.dart, MaterialApp.builder) bir kez kullanılır.
class CartPriceNotice extends StatefulWidget {
  final Widget child;

  const CartPriceNotice({super.key, required this.child});

  static const String message = 'Sepetindeki bazı ürünlerin fiyatı güncellendi.';

  @override
  State<CartPriceNotice> createState() => _CartPriceNoticeState();
}

class _CartPriceNoticeState extends State<CartPriceNotice> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        context.read<CartViewModel>().priceUpdates.listen((_) => _show());
  }

  void _show() {
    if (!mounted) return;
    showMarketSnack(
      context,
      CartPriceNotice.message,
      icon: Icons.sell_outlined,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
