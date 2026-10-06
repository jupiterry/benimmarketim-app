import 'package:benimmarketim_app/services/turkish_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Büyük/küçük harf ve aksandan bağımsız arama', () {
    expect(TurkishText.contains('İstanbul Simidi', 'istanbul'), isTrue);
    expect(TurkishText.contains('ISPARTA GÜLÜ', 'ısparta'), isTrue);
    expect(TurkishText.contains('Toz Şeker 1 kg', 'seker'), isTrue);
    expect(TurkishText.contains('Çikolatalı Gofret', 'cikolata'), isTrue);
    expect(TurkishText.contains('Süt', 'ekmek'), isFalse);
  });

  test('Türk alfabesine göre sıralama', () {
    final names = ['Zeytin', 'Şeker', 'Çay', 'Ayran', 'Süt', 'Cips', 'Ödeme', 'Ozon', 'Irmik', 'İncir', 'Ürün', 'Un', 'Quinoa', 'Peynir', 'Reçel'];
    names.sort(TurkishText.compare);
    expect(names, ['Ayran', 'Cips', 'Çay', 'Irmik', 'İncir', 'Ozon', 'Ödeme', 'Peynir', 'Quinoa', 'Reçel', 'Süt', 'Şeker', 'Un', 'Ürün', 'Zeytin']);
  });
}
