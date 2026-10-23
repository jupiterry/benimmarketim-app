import '../../models/delivery.dart';
import 'market_ui.dart';

/// Adrese teslimat ekranlarının ortak metinleri. Tutarlar uygulamanın geri
/// kalanı gibi ₺ ile gösterilir (₺40, ₺249,90).

/// Bölge satırındaki ücret: "Ücretsiz teslimat" / "Teslimat ₺40"
String zoneFeeLabel(DeliveryZone zone) {
  if (zone.isFree || zone.deliveryFee <= 0) return 'Ücretsiz teslimat';
  return 'Teslimat ${formatTlShort(zone.deliveryFee)}';
}

/// Bölge satırının alt bilgisi: "Teslimat ₺40 · 30-60 dk"
String zoneSubtitle(DeliveryZone zone) => [
      zoneFeeLabel(zone),
      if (zone.etaText.trim().isNotEmpty) zone.etaText.trim(),
    ].join(' · ');

/// Ücretsiz teslimat eşiği ipucu: "₺360 daha ekle, teslimat ücretsiz"
String freeDeliveryHint(double remaining) =>
    '${formatTlShort(remaining)} daha ekle, teslimat ücretsiz';

/// Minimum tutar uyarısı
String minimumOrderMessage(DeliveryQuote quote) =>
    'Bu bölge için en az ${formatTlShort(quote.minimumOrderAmount)} tutarında '
    'sipariş gerekiyor (${formatTlShort(quote.missingForMinimum)} daha ekle).';

/// İlk siparişte teyit araması bilgisi
const String firstOrderCallbackNote =
    'İlk siparişin için seni arayıp teyit edeceğiz.';

/// Teyit araması bekleyen sipariş
const String awaitingCallbackNote =
    'Siparişini teyit etmek için seni arayacağız.';

/// Kapalı bölgedeki kayıtlı adres
const String zoneClosedNote = 'Bu bölgeye şu an teslimat yok.';
