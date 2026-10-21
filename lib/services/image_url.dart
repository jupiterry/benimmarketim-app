/// Ürün ve banner görselleri Cloudinary'de tam boyutlu PNG olarak duruyor
/// (çoğu birkaç yüz KB). Liste ekranlarında bu dosyaların tamamını indirmek
/// ürünlerin geç görünmesinin ana nedeniydi. Cloudinary adresine boyut ve
/// biçim dönüşümü eklenince aynı görsel ekrana uygun genişlikte ve WebP
/// olarak gelir (genellikle 10-20 kat küçük). `f_auto` yerine `f_webp`
/// kullanılır: Flutter'ın HTTP istemcisi tarayıcı gibi `Accept` başlığı
/// göndermediği için `f_auto` çoğu zaman özgün PNG'yi döndürür; WebP'yi ise
/// Flutter Android ve iOS'ta saydamlığıyla birlikte çözer.
///
/// Aynı görselin farklı ekranlarda aynı adresle istenmesi için genişlikler
/// sabit kademelerdir; önbellek böylece paylaşılır.
abstract final class MarketImageSize {
  static const int thumb = 200; // sepet, sipariş satırları
  static const int card = 400; // ürün kartları
  static const int detail = 900; // ürün detayı
  static const int banner = 1200; // ana sayfa banner'ı
}

const _cloudinaryHost = 'res.cloudinary.com';
const _uploadSegment = '/image/upload/';

/// Cloudinary adresiyse [width] genişliğinde, WebP ve otomatik kaliteyle
/// döndürür; değilse adresi olduğu gibi bırakır. Adreste zaten bir dönüşüm
/// varsa (ör. `w_300`) dokunulmaz.
String optimizedImageUrl(String url, {required int width}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host != _cloudinaryHost) return trimmed;
  final index = trimmed.indexOf(_uploadSegment);
  if (index < 0) return trimmed;
  final rest = trimmed.substring(index + _uploadSegment.length);
  final firstSegment = rest.split('/').first;
  // Sürüm (v123...) ya da klasör adıyla başlıyorsa dönüşüm yoktur.
  final hasTransformation = firstSegment.contains(',') ||
      RegExp(r'^(w|h|c|f|q|e|ar|dpr|t)_').hasMatch(firstSegment);
  if (hasTransformation) return trimmed;
  final prefix = trimmed.substring(0, index + _uploadSegment.length);
  return '${prefix}w_$width,c_limit,f_webp,q_auto/$rest';
}
