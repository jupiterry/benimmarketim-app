import 'package:benimmarketim_app/views/widgets/market_palette.dart';
import 'package:benimmarketim_app/views/widgets/market_system_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color _bandColor(WidgetTester tester) => tester
    .widget<ColoredBox>(find
        .descendant(of: find.byType(MarketSystemFrame), matching: find.byType(ColoredBox))
        .first)
    .color;

void main() {
  final chrome = MarketChromeObserver.instance;

  setUp(chrome.debugReset);

  Future<BuildContext> pumpFrame(WidgetTester tester) async {
    late BuildContext home;
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [chrome],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 44)),
        child: MarketSystemFrame(child: child!),
      ),
      home: Builder(builder: (context) {
        home = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    await tester.pumpAndSettle();
    return home;
  }

  testWidgets('durum şeridi alt sayfa açıkken kararır, kapanınca açılır', (tester) async {
    final home = await pumpFrame(tester);
    expect(_bandColor(tester), MarketPalette.greenDeep);

    showModalBottomSheet<void>(context: home, builder: (_) => const SizedBox(height: 200));
    await tester.pumpAndSettle();
    expect(chrome.modalDim.value, closeTo(MarketPalette.scrim.a, .01));
    expect(_bandColor(tester), isNot(MarketPalette.greenDeep));
    expect(chrome.lightStatusIcons, isTrue);

    Navigator.of(home).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Kapanış animasyonu sürerken şerit de yavaş yavaş açılır.
    expect(chrome.modalDim.value, inExclusiveRange(0, MarketPalette.scrim.a));
    await tester.pumpAndSettle();
    expect(chrome.modalDim.value, 0);
    expect(_bandColor(tester), MarketPalette.greenDeep);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MarketStatusBand üstteki sayfanın şerit rengini seçer', (tester) async {
    final home = await pumpFrame(tester);
    Navigator.of(home).push(MaterialPageRoute<void>(
      builder: (_) => const MarketStatusBand(
        color: MarketPalette.limeSoft,
        child: Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(chrome.status.value.color, MarketPalette.limeSoft);
    expect(chrome.lightStatusIcons, isFalse);
    expect(_bandColor(tester), MarketPalette.limeSoft);

    Navigator.of(home).pop();
    await tester.pumpAndSettle();
    expect(chrome.status.value, MarketStatusStyle.brand);
    expect(_bandColor(tester), MarketPalette.greenDeep);
    expect(tester.takeException(), isNull);
  });
}
