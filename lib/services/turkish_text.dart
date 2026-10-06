/// Türkçe'ye duyarlı metin yardımcıları (arama ve sıralama için).
class TurkishText {
  TurkishText._();

  /// Türkçe kurallarına göre küçük harfe çevirir (I → ı, İ → i).
  static String toLower(String input) =>
      input.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Arama karşılaştırması için sadeleştirir: küçük harf + aksan katlama.
  /// "İstanbul", "ISTANBUL" ve "istanbul" aynı sonucu verir;
  /// "şeker" ile "seker" eşleşir.
  static String normalize(String input) {
    final lower = input.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_fold[char] ?? char);
    }
    return buffer.toString();
  }

  /// [text] içinde [query] geçiyor mu (Türkçe duyarsız).
  static bool contains(String text, String query) =>
      normalize(text).contains(normalize(query));

  /// Türk alfabesi sırasıyla karşılaştırır (Ç, Ğ, I, Ö, Ş, Ü doğru yerde).
  static int compare(String a, String b) {
    final la = toLower(a);
    final lb = toLower(b);
    final ra = la.runes.toList();
    final rb = lb.runes.toList();
    final length = ra.length < rb.length ? ra.length : rb.length;
    for (var i = 0; i < length; i++) {
      final diff = _rank(ra[i]) - _rank(rb[i]);
      if (diff != 0) return diff;
    }
    final lengthDiff = ra.length - rb.length;
    if (lengthDiff != 0) return lengthDiff;
    return a.compareTo(b);
  }

  static const _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';
  static final Map<int, int> _ranks = {
    for (var i = 0; i < _alphabet.length; i++) _alphabet.codeUnitAt(i): i * 2,
    // Türk alfabesinde olmayan harfler komşu harfin hemen arkasına.
    'q'.codeUnitAt(0): _alphabet.indexOf('p') * 2 + 1,
    'w'.codeUnitAt(0): _alphabet.indexOf('v') * 2 + 1,
    'x'.codeUnitAt(0): _alphabet.indexOf('v') * 2 + 1,
  };

  static int _rank(int rune) {
    final rank = _ranks[rune];
    if (rank != null) return rank + 1000;
    // Rakam ve noktalama harflerden önce, diğer karakterler sonra gelir.
    return rune < 'a'.runes.first ? rune : rune + 2000;
  }

  static const Map<String, String> _fold = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    '̇': '', // "İ".toLowerCase() sonrası kalan birleşik nokta
  };
}
