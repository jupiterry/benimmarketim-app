// Alt menüdeki hareketli maskot: seçili sekmeye zıplar, hareket azaltmada
// doğrudan yerine geçer.

import 'package:benimmarketim_app/viewmodels/cart_viewmodel.dart';
import 'package:benimmarketim_app/views/widgets/market_bottom_navigation.dart';
import 'package:benimmarketim_app/views/widgets/market_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/orders_test_utils.dart' show installOrdersPlatformMocks;
import 'support/test_utils.dart';

Future<void> _pump(WidgetTester tester, int index,
    {bool reduceMotion = false}) {
  return tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => CartViewModel(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: MarketBottomNavigation(
              selectedIndex: index,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

double _mascotX(WidgetTester tester) => tester
    .getCenter(find.descendant(
        of: find.byType(MarketBottomNavigation),
        matching: find.byType(MarketMascot)))
    .dx;

void main() {
  configureMarketTests();
  setUp(installOrdersPlatformMocks);

  testWidgets('sekme değişince maskot o sekmeye zıplar', (tester) async {
    await withoutFontErrors(() async {
      await _pump(tester, 0);
      final home = _mascotX(tester);
      final top = tester
          .getTopLeft(find.descendant(
              of: find.byType(MarketBottomNavigation),
              matching: find.byType(MarketMascot)))
          .dy;
      final barTop = tester.getTopLeft(find.text('Ana Sayfa')).dy;
      // Menünün üstünde durur
      expect(top, lessThan(barTop));

      await _pump(tester, 2);
      await tester.pump(const Duration(milliseconds: 260));
      final midway = _mascotX(tester);
      expect(midway, greaterThan(home));
      await tester.pump(const Duration(milliseconds: 400));
      final account = _mascotX(tester);
      expect(account, greaterThan(midway));
      // Hesabım sekmesinin sağ üstünde
      expect(account, greaterThan(tester.getCenter(find.text('Hesabım')).dx));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('hareket azaltmada doğrudan yerine geçer', (tester) async {
    await withoutFontErrors(() async {
      await _pump(tester, 0, reduceMotion: true);
      await _pump(tester, 1, reduceMotion: true);
      await tester.pump();
      final x = _mascotX(tester);
      // Sepet sekmesinin sağ üstünde, Hesabım'dan önce
      expect(x, greaterThan(tester.getCenter(find.text('Sepet')).dx));
      expect(x, lessThan(tester.getCenter(find.text('Hesabım')).dx));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
