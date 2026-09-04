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
  return '🛍️';
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
    final lower = word.toLowerCase();
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
