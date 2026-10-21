import 'package:flutter/material.dart';

/// Uygulamanın tek renk kaynağı. Ekranlar sabit renk yerine bu değerleri
/// kullanır; `AppColors` da bu tonlara bağlıdır.
abstract final class MarketPalette {
  // Zeminler
  static const canvas = Color(0xFFF5F7F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F3EF);
  static const line = Color(0xFFE5EAE6);
  static const lineStrong = Color(0xFFD5DDD7);
  static const fill = Color(0xFFE9EEE9); // iskelet, nötr rozet zemini

  /// Pasif buton / kontrol zemini (üstündeki metin [muted] olur: ~4.1:1).
  static const disabled = Color(0xFFDCE4DE);

  /// Alt sayfa ve diyalogların arkasındaki karartma. Durum çubuğu şeridi de
  /// aynı oranda kararır (MarketSystemFrame).
  static const scrim = Color(0x8A000000);

  // Metin (muted, beyaz üzerinde ~5.3:1 kontrast — küçük metinde AA).
  // subtle yalnızca simge ve ayırıcı içindir; metinde kullanılmaz (~3:1).
  static const ink = Color(0xFF17231B);
  static const inkSoft = Color(0xFF34443A);
  static const muted = Color(0xFF5F6E66);
  static const subtle = Color(0xFF8A968F);

  // Marka. green üzerinde beyaz metin ~5:1 (AA); küçük yeşil metin için
  // (kazanç, "Ücretsiz", bölüm etiketi) greenDark kullanılır.
  static const green = Color(0xFF147F4B);
  static const greenDark = Color(0xFF075B39);
  static const greenDeep = Color(0xFF063F2B);
  static const greenSoft = Color(0xFFE7F5EC);
  static const lime = Color(0xFFB8E36F);
  static const limeSoft = Color(0xFFF1F9E2);
  static const greenLine = Color(0xFFCDE9D8); // yeşil zeminli kutu çizgisi
  static const limeLine = Color(0xFFD5EBC0);

  // Durum
  static const orange = Color(0xFFFFA14A);
  static const orangeInk = Color(0xFF9B5B13);
  static const orangeSoft = Color(0xFFFFF3DF);
  static const red = Color(0xFFD93B3B);
  static const redSoft = Color(0xFFFDECEC);
  static const redLine = Color(0xFFF2C4C4);
  static const blue = Color(0xFF3D63DD);
  static const blueSoft = Color(0xFFEAF0FF);
  static const pink = Color(0xFFD84B68);
  static const pinkSoft = Color(0xFFFFECF0);

  /// Kategori kutularının pastel zeminleri (sıra sabittir; bir kategoriye
  /// hep aynı ton düşsün diye anahtarla eşlenerek kullanılır).
  static const categoryTints = [
    Color(0xFFE9F6ED),
    Color(0xFFFFF1DF),
    Color(0xFFEAF0FF),
    Color(0xFFFFEDEF),
    Color(0xFFE8F7F7),
    Color(0xFFF3ECFF),
    Color(0xFFFFF7D9),
    Color(0xFFEDF3E6),
  ];

  // Saatin durduğu durum çubuğu şeridi (MarketSystemFrame) düz greenDeep'tir.
  // Başlık da üstte aynı renkle başlar, ilk çeyreğinde hiç değişmez ve aşağıya
  // doğru yalnızca hafifçe açılır; böylece kısa başlıklarda bile şeritle
  // başlık arasında renk farkı ya da bant görünmez.
  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenDeep, greenDeep, greenDark],
    stops: [0, .25, 1],
  );
}

/// Köşe yarıçapı ölçeği. Yeni bileşenlerde sabit sayı yerine bunlar kullanılır.
abstract final class MarketRadius {
  static const double xs = 8; // rozet, küçük etiket
  static const double sm = 12; // çip, ikon kutusu, küçük buton
  static const double md = 16; // buton, giriş alanı, bildirim
  static const double lg = 22; // kart, diyalog
  static const double xl = 30; // başlık altı, alt sayfa, büyük görsel kutusu
  static const double pill = 99;
}

/// Boşluk ölçeği (4'ün katları).
abstract final class MarketSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20; // sayfa kenar boşluğu
  static const double xxl = 24;
  static const double section = 32;

  /// 360 pt'den dar telefonlarda sayfa kenar boşluğu.
  static const double gutterCompact = 16;

  /// Ekran genişliğine göre sayfa kenar boşluğu: dar telefonda 16, diğerlerinde 20.
  static double gutterOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360 ? gutterCompact : xl;
}

/// Dokunma alanı ve kontrol yükseklikleri. Buton/kontrol boyunda sabit sayı
/// yerine bunlar kullanılır.
abstract final class MarketSize {
  /// En küçük dokunma alanı (görsel daha küçük olsa da).
  static const double tapTarget = 48;

  /// Adet seçici, küçük buton, çip gibi satır içi kontroller.
  static const double control = 44;

  /// Ana eylem butonu (sepete ekle, siparişi ver, alt çubuk butonları).
  static const double button = 54;

  /// İkincil / küçük buton.
  static const double buttonSm = 44;

  /// Koyu başlıktaki kare simge butonu (MarketHeaderButton).
  static const double headerButton = 46;
}
