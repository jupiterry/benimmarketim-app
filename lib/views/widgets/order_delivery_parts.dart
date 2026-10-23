import 'package:flutter/material.dart';

import '../../models/order.dart';
import 'delivery_ui.dart';
import 'market_ui.dart';

// ---------------------------------------------------------------------------
// Sipariş listesi ve sipariş onayının ortak teslimat parçaları: teslimat yeri,
// teslimat ücreti / tutar dökümü ve teyit / teslim edilemedi notları.
// ---------------------------------------------------------------------------

const _cancelledStatus = 'İptal Edildi';
const _deliveredStatus = 'Teslim Edildi';

/// Teslimat ücreti satırı gösterilsin mi? Adresli siparişte her zaman
/// ("Ücretsiz teslimat" dahil); eski yurt siparişlerinde ücret yoksa satır
/// eklenmez.
bool orderShowsDeliveryFee(Order order) =>
    order.isAddressDelivery || order.deliveryFee > 0;

/// "Ücretsiz teslimat" ya da "₺40,00"
String orderDeliveryFeeText(Order order) =>
    order.deliveryFee <= 0 ? 'Ücretsiz teslimat' : formatTl(order.deliveryFee);

/// Kupon öncesi ürün tutarı (teslimat hariç). Ürünler − kupon + teslimat =
/// ödenecek tutar dökümünün ilk satırı.
double orderProductsBeforeCoupon(Order order) {
  final productTotal = order.productTotal;
  if (productTotal != null) return productTotal + order.couponDiscount;
  // Eski siparişlerde teslimat yok: önceki hesap aynen kalır
  if (!orderShowsDeliveryFee(order)) return order.subtotalOrDerived;
  if (order.subtotalAmount > 0) return order.subtotalAmount;
  return order.productTotalOrDerived + order.couponDiscount;
}

/// Siparişin teslimat yeri: adresli siparişte bölge + adres + tarif, yurt
/// siparişinde yurdun adı.
class OrderPlace {
  /// Bölge ya da yurt adı ("Cumhuriyet Mahallesi", "Kız KYK Yurdu")
  final String title;

  /// Sokak / bina özeti ("Atatürk Cd. No:5 · Kat 2")
  final String? detail;

  /// Adres tarifi
  final String? directions;

  const OrderPlace({required this.title, this.detail, this.directions});

  static OrderPlace? of(Order order) {
    String? clean(String? value) {
      final text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final pointName = clean(order.deliveryPointName);
    final zoneName = clean(order.deliveryZone?.name);
    if (!order.isAddressDelivery) {
      final title = pointName ?? zoneName;
      return title == null ? null : OrderPlace(title: title);
    }
    final address = order.deliveryAddress;
    final detail = clean(address?.summary);
    final directions = clean(address?.directions);
    if (zoneName != null && (detail != null || directions != null)) {
      return OrderPlace(title: zoneName, detail: detail, directions: directions);
    }
    // Adres alanları gelmediyse sunucunun kısa özeti kullanılır
    final title = pointName ?? zoneName;
    if (title == null) return null;
    return OrderPlace(title: title, detail: detail, directions: directions);
  }

  /// Tek satırda: "Cumhuriyet Mahallesi · Atatürk Cd. No:5"
  String get oneLine => [title, if (detail != null) detail!].join(' · ');
}

/// Siparişin teslimat bölgesinin kimliği (tahmini süre için). Eski yurt
/// siparişlerinde bölge yoksa teslimat noktası (girlsDorm / boysDorm) aynı
/// kimliği taşır.
String? orderZoneId(Order order) {
  final id = order.deliveryZone?.id ?? '';
  if (id.isNotEmpty) return id;
  return order.deliveryPoint.isEmpty ? null : order.deliveryPoint;
}

/// İptal nedeni metni: "İptal nedeni: Fikrimi değiştirdim · “not”"
String? orderCancelReasonText(Order order) {
  final label = order.cancelReasonLabel.trim();
  if (label.isEmpty) return null;
  final note = order.cancelReasonNote.trim();
  return note.isEmpty
      ? 'İptal nedeni: $label'
      : 'İptal nedeni: $label · “$note”';
}

/// Siparişin durumuna göre önemli teslimat notları:
/// - iptal edildi + teslim edilemedi nedeni → kırmızı kutu
/// - iptal edildi + müşterinin iptal nedeni → gri kutu
/// - süren sipariş + teyit araması bekleniyor → mavi bilgi kutusu
class OrderDeliveryNotes extends StatelessWidget {
  final Order order;

  const OrderDeliveryNotes({super.key, required this.order});

  static bool _cancelled(Order order) => order.status == _cancelledStatus;

  static String? _outcome(Order order) {
    final text = order.deliveryOutcomeLabel.trim();
    return _cancelled(order) && text.isNotEmpty ? text : null;
  }

  static bool _showCallback(Order order) =>
      order.awaitingCallback &&
      order.status != _cancelledStatus &&
      order.status != _deliveredStatus;

  /// Gösterilecek not var mı (boşluk ayarlamak için)
  static bool hasAny(Order order) =>
      _outcome(order) != null ||
      (_cancelled(order) && orderCancelReasonText(order) != null) ||
      _showCallback(order);

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome(order);
    final reason = _cancelled(order) ? orderCancelReasonText(order) : null;
    final notes = <Widget>[
      if (outcome != null)
        Semantics(
          liveRegion: true,
          child: MarketNotice(
            icon: Icons.report_gmailerrorred_rounded,
            text: outcome,
            background: MarketPalette.redSoft,
            foreground: MarketPalette.red,
          ),
        ),
      if (reason != null)
        MarketNotice(
          icon: Icons.info_outline_rounded,
          text: reason,
          background: MarketPalette.surfaceMuted,
          foreground: MarketPalette.inkSoft,
        ),
      if (_showCallback(order))
        const MarketNotice.info(
          icon: Icons.phone_callback_outlined,
          text: awaitingCallbackNote,
        ),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) const SizedBox(height: MarketSpace.sm),
          notes[i],
        ],
      ],
    );
  }
}
