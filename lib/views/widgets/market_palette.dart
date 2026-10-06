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

  // Metin (muted, beyaz üzerinde ~5.3:1 kontrast — küçük metinde AA)
  static const ink = Color(0xFF17231B);
  static const inkSoft = Color(0xFF34443A);
  static const muted = Color(0xFF5F6E66);
  static const subtle = Color(0xFF8A968F);

  // Marka
  static const green = Color(0xFF168A52);
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

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenDeep, greenDark, Color(0xFF117A48)],
    stops: [0, .58, 1],
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
}
