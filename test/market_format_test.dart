import 'package:benimmarketim_app/views/widgets/market_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const nb = ' ';

void main() {
  test('Ürün adında sayı ile birim ayrılmaz', () {
    expect(productDisplayName('Sek Kaşar Peyniri 400 g'), 'Sek Kaşar Peyniri 400${nb}g');
    expect(productDisplayName('Pınar Süt 1 L'), 'Pınar Süt 1${nb}L');
    expect(productDisplayName('Tamek Bezelye 830 gr'), 'Tamek Bezelye 830${nb}gr');
    expect(productDisplayName('Yoğurt 4×100 g'), 'Yoğurt 4×100${nb}g');
    expect(productDisplayName('Ayran 4 x 200 ml'), 'Ayran 4${nb}x${nb}200${nb}ml');
    expect(productDisplayName('Yumurta 10 lu'), 'Yumurta 10${nb}lu');
    expect(productDisplayName('Banvit Bütün Piliç (kg)'), 'Banvit Bütün Piliç$nb(kg)');
    expect(productDisplayName('Hediye Çeki 1 Lira'), 'Hediye Çeki 1 Lira');
    expect(productDisplayName('Ülker Çikolata'), 'Ülker Çikolata');
  });

  test('Telefon numarası biçimi', () {
    expect(formatPhoneTr('05321234567'), '0532 123 45 67');
    expect(formatPhoneTr('5321234567'), '0532 123 45 67');
    expect(formatPhoneTr('+90 532 123 45 67'), '0532 123 45 67');
    expect(formatPhoneTr('12345'), '12345');
  });

  test('Tarih Türkiye saatiyle kısa yazılır', () {
    // 21 Ekim 2026, 12:00 Türkiye saati
    final now = DateTime.utc(2026, 10, 21, 9);
    expect(formatTrDateTime(DateTime.utc(2026, 10, 21, 1, 40), now: now), 'Bugün 04:40');
    expect(formatTrDateTime(DateTime.utc(2026, 10, 20, 19, 15), now: now), 'Dün 22:15');
    expect(formatTrDateTime(DateTime.utc(2026, 10, 18, 0, 5), now: now), '18 Eki 03:05');
    expect(formatTrDateTime(DateTime.utc(2025, 12, 31, 20), now: now), '31 Ara 2025 23:00');
    expect(formatTrDateTime(DateTime.utc(2026, 10, 18), now: now, withTime: false), '18 Eki');
  });
}
