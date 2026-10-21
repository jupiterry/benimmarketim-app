import 'dart:ui' show Color;

import '../../services/turkish_text.dart';
import 'market_palette.dart';

String categoryDisplayName(String rawName) {
  const names = <String, String>{
    'atistirma': 'Atıştırma',
    'icecekler': 'İçecekler',
    'kisisel': 'Kişisel Bakım',
    'kisiselbakim': 'Kişisel Bakım',
    'bakim': 'Kişisel Bakım',
    'temizlik': 'Temizlik Ürünleri',
    'dondurma': 'Dondurma',
    'gida': 'Temel Gıda',
    'cips': 'Cips & Çerez',
    'makarna': 'Makarna',
    'cayseker': 'Çay & Şeker',
    'bespara': 'Uygun Fiyatlı',
    'tozicecekler': 'Toz İçecekler',
    'tozicecekleri': 'Toz İçecekler',
    'kahve': 'Kahve',
    'sut': 'Süt Ürünleri',
    'kahvalti': 'Kahvaltılık',
    'baharat': 'Baharat',
    'yiyecekler': 'Yiyecekler',
    'dondurulmus': 'Dondurulmuş Ürünler',
    'dondurulumus': 'Dondurulmuş Ürünler',
    'et': 'Et Ürünleri',
    'bebek': 'Bebek Bakımı',
    'evcilhayvan': 'Evcil Hayvan',
    'evcil': 'Evcil Hayvan',
    'meyvesebze': 'Meyve & Sebze',
    'firin': 'Fırın & Ekmek',
    'kirtasiye': 'Kırtasiye',
    'kozmetik': 'Kozmetik',
    'bakliyat': 'Bakliyat',
    'kuruyemis': 'Kuruyemiş',
    'konserve': 'Konserve',
  };

  final key = normalizedCategoryKey(rawName);
  return names[key] ?? _turkishTitleCase(rawName);
}

String categoryEmoji(String rawName) {
  final key = normalizedCategoryKey(rawName);
  if (key == 'atistirma') return '🍫';
  if (key == 'icecekler') return '🥤';
  if (key == 'kisisel' || key == 'kisiselbakim' || key == 'bakim') return '🧴';
  if (key == 'temizlik') return '🧹';
  if (key == 'dondurma') return '🍦';
  if (key == 'gida') return '🥫';
  if (key == 'cips') return '🍿';
  if (key == 'makarna') return '🍝';
  if (key == 'cayseker') return '🍵';
  if (key == 'bespara') return '🏷️';
  if (key == 'tozicecekler' || key == 'tozicecekleri') return '🧃';
  if (key == 'kahve') return '☕';
  if (key == 'sut') return '🥛';
  if (key == 'kahvalti') return '🍳';
  if (key == 'baharat') return '🌶️';
  if (key == 'yiyecekler') return '🍽️';
  if (key == 'dondurulmus' || key == 'dondurulumus') return '❄️';
  if (key == 'et') return '🥩';
  if (key.contains('meyve') || key.contains('sebze')) return '🥦';
  if (key.contains('bebek')) return '👶';
  if (key.contains('evcil') || key.contains('pet')) return '🐾';
  if (key.contains('ekmek') || key.contains('firin')) return '🥖';
  // Öğrenci marketine uygun, eşlemesi olmayan reyonlar
  if (key.contains('kirtasiye')) return '✏️';
  if (key.contains('kozmetik') || key.contains('makyaj')) return '💄';
  if (key.contains('kagit') || key.contains('hijyen') || key.contains('mendil')) {
    return '🧻';
  }
  if (key.contains('konserve')) return '🥫';
  // Yeni emojiler (🫘, 🫙) eski Android'de kutu olarak görünür
  if (key.contains('bakliyat')) return '🌾';
  if (key == 'sos' || key == 'soslar') return '🍅';
  if (key.contains('cerez') || key.contains('kuruyemis')) return '🥜';
  return '🛍️';
}

/// Kategori kutusunun pastel zemini. Renk sıradan değil adından gelir;
/// kategorilerin sırası değişse de her kategori hep aynı tonda görünür.
Color categoryTint(String rawName) {
  const known = <String, int>{
    'meyvesebze': 0,
    'sut': 1,
    'atistirma': 2,
    'icecekler': 3,
    'temizlik': 4,
    'firin': 5,
    'kahvalti': 6,
    'et': 7,
  };
  const tints = MarketPalette.categoryTints;
  final key = normalizedCategoryKey(rawName);
  final index = known[key];
  if (index != null) return tints[index];
  // Bilinmeyen kategoriler için kararlı (her açılışta aynı) bir özet değeri
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return tints[hash % tints.length];
}

String normalizedCategoryKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp('[^a-z0-9]'), '');
}

String _turkishTitleCase(String value) {
  final words =
      value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);

  return words.map((word) {
    // Türkçe kurallarıyla küçült ("İ" → "i", "I" → "ı"); toLowerCase "İ"yi
    // noktalı i + birleşik nokta yapıyordu
    final lower = TurkishText.toLower(word);
    final first = switch (lower[0]) {
      'i' => 'İ',
      'ı' => 'I',
      'ç' => 'Ç',
      'ğ' => 'Ğ',
      'ö' => 'Ö',
      'ş' => 'Ş',
      'ü' => 'Ü',
      _ => lower[0].toUpperCase(),
    };
    return '$first${lower.substring(1)}';
  }).join(' ');
}
