// Ödeme ekranındaki yasal metinler: siparişe özel içerik ve zorunlu onay.

import 'package:benimmarketim_app/models/legal_documents.dart';
import 'package:benimmarketim_app/views/widgets/checkout_consent.dart';
import 'package:benimmarketim_app/views/widgets/market_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_utils.dart';

LegalOrderData _data({double? fee = 40, String payment = 'Kapıda nakit'}) =>
    LegalOrderData(
      buyerName: 'Ayşe Yılmaz',
      buyerPhone: '0532 123 45 67',
      deliveryPlace: 'Devrek · Cumhuriyet Mah. · Atatürk Cd. No:5',
      lines: const [
        LegalOrderLine(name: 'Süt 1 L', quantity: 2, unitPrice: 30),
        LegalOrderLine(name: 'Ekmek', quantity: 1, unitPrice: 15),
      ],
      productsTotal: 75,
      couponDiscount: 10,
      deliveryFee: fee,
      payable: 75 - 10 + (fee ?? 0),
      paymentMethod: payment,
      date: DateTime(2026, 10, 25, 14, 5),
    );

String _money(num v) => '₺${v.toStringAsFixed(2)}';

void main() {
  group('metinler siparişe özel', () {
    test('ön bilgilendirme formu: satıcı, alıcı, ürünler, tutarlar, cayma', () {
      final doc = buildPreInformationForm(_data(), _money);
      final text = doc.plainText;
      expect(doc.title, 'Ön Bilgilendirme Formu');
      expect(text, contains(SellerInfo.legalName));
      expect(text, contains(SellerInfo.address));
      expect(text, contains('Ayşe Yılmaz'));
      expect(text, contains('Devrek · Cumhuriyet Mah. · Atatürk Cd. No:5'));
      expect(text, contains('2 × Süt 1 L — birim ₺30.00, toplam ₺60.00'));
      expect(text, contains('Kupon indirimi: −₺10.00'));
      expect(text, contains('Teslimat ücreti: ₺40.00'));
      expect(text, contains('Ödenecek toplam (KDV dahil): ₺105.00'));
      expect(text, contains('Ödeme yöntemi: Kapıda nakit'));
      expect(text, contains('14 gün'));
      expect(text, contains('çabuk bozulabilen'));
      expect(text, contains('Tüketici Hakem Heyetine'));
      expect(text, contains('25.10.2026 14:05'));
      // Bilinmeyen satıcı bilgileri boş bırakılır, yer tutucu yazılmaz
      expect(text, isNot(contains('XXX')));
      expect(text, isNot(contains('[')));
    });

    test('ücretsiz ve henüz hesaplanmamış teslimat', () {
      expect(buildPreInformationForm(_data(fee: 0), _money).plainText,
          contains('Teslimat ücreti: Ücretsiz'));
      expect(buildPreInformationForm(_data(fee: null), _money).plainText,
          contains('teslimat yeri seçilince hesaplanır'));
    });

    test('ödeme yöntemi seçilmediyse seçenekler yazılır', () {
      expect(buildPreInformationForm(_data(payment: ''), _money).plainText,
          contains('Kapıda nakit ya da kapıda kart (POS)'));
    });

    test('mesafeli satış sözleşmesi: taraflar, ürünler, yürürlük', () {
      final doc = buildDistanceSalesContract(_data(), _money);
      final text = doc.plainText;
      expect(doc.title, 'Mesafeli Satış Sözleşmesi');
      expect(text, contains('Madde 1 – Taraflar'));
      expect(text, contains('SATICI'));
      expect(text, contains('ALICI'));
      expect(text, contains('1 × Ekmek'));
      expect(text, contains('6502 sayılı'));
      expect(text, contains('onaylanmasıyla (25.10.2026 14:05) kurulur'));
    });
  });

  group('onay kutusu', () {
    configureMarketTests();

    testWidgets('dokununca değişir, metin adı formu açar, hata gösterilir',
        (tester) async {
      await withoutFontErrors(() async {
        var accepted = false;
        var error = true;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: CheckoutConsent(
                  accepted: accepted,
                  error: error,
                  onChanged: (v) => setState(() {
                    accepted = v;
                    if (v) error = false;
                  }),
                  data: _data,
                ),
              ),
            ),
          ),
        ));
        expect(find.text('Siparişi vermek için metinleri onaylaman gerekiyor.'),
            findsOneWidget);

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(accepted, isTrue);
        expect(find.text('Siparişi vermek için metinleri onaylaman gerekiyor.'),
            findsNothing);

        // "Ön Bilgilendirme Formu" bağlantısı: metnin sol başı
        final rich = find.byWidgetPredicate((w) =>
            w is RichText && w.text.toPlainText().startsWith('Ön Bilgi'));
        await tester.tapAt(tester.getTopLeft(rich) + const Offset(20, 8));
        await tester.pumpAndSettle();
        expect(find.text('Bu siparişe göre hazırlandı'), findsOneWidget);
        expect(find.text('1. Satıcı'), findsOneWidget);
        expect(
            find.textContaining('Süt 1 L', findRichText: true), findsWidgets);
        await tester.tap(find.text('Okudum'));
        await tester.pumpAndSettle();
        expect(find.text('Bu siparişe göre hazırlandı'), findsNothing);
        // Bağlantıya dokunmak onayı değiştirmez
        expect(accepted, isTrue);
      });
    });
  });

  test('formatTl ile para biçimi', () {
    expect(buildPreInformationForm(_data(), formatTl).plainText,
        contains(formatTl(105)));
  });
}
