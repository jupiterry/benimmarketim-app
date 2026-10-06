import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benimmarketim_app/main.dart';

void main() {
  testWidgets('Application starts with Turkish storefront and release banner hidden',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Benim Marketim');
    expect(app.locale, const Locale('tr', 'TR'));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.text('Benim Marketim'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
