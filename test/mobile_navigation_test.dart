import 'package:benimmarketim_app/views/widgets/market_system_frame.dart';
import 'package:benimmarketim_app/views/widgets/market_tab_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tab changes retain input and tolerate rapid selection',
      (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, _) => MarketTabStack(
            index: index,
            children: const [TextField(), Text('Cart'), Text('Account')],
          ),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'retained');
    for (final index in [1, 2, 0, 2, 1, 0]) {
      selected.value = index;
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.text('retained'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status inset is reserved once on every route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: MarketSystemFrame(child: child!),
      ),
      home: Scaffold(
        body: Builder(
            builder: (context) => Column(children: [
                  const SizedBox(key: ValueKey('content'), height: 10),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                          body: SafeArea(
                        child: SizedBox(key: ValueKey('next'), height: 10),
                      )),
                    )),
                    child: const Text('Next'),
                  ),
                ])),
      ),
    ));
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, 44);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dy, 44);
    expect(tester.takeException(), isNull);
  });
}
