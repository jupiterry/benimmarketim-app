import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'market_ui.dart';

/// Topluluk (kupon isteği) kampanyası yardımcıları.
abstract final class CommunityCampaign {
  /// Kullanıcı şartı sağlıyor ama henüz katılmamışsa true.
  static bool canJoin(Map<String, dynamic>? campaign) =>
      campaign != null &&
      campaign['isEligible'] != false &&
      campaign['userRequested'] != true;

  static String title(Map<String, dynamic> campaign) =>
      (campaign['title'] ?? 'Topluluk indirimi').toString();

  static String percent(Map<String, dynamic> campaign) =>
      '%${campaign['discountPercentage'] ?? ''}';

  /// Katılım isteği gönderir; sonucu bildirir. Güncel kampanyayı döndürür
  /// (başarısızsa null).
  static Future<Map<String, dynamic>?> join(BuildContext context) async {
    final response = await ApiService().requestCouponCampaign();
    if (!context.mounted) return null;
    final ok = response['success'] == true;
    showMarketSnack(
      context,
      ok
          ? 'Topluluk indirimine katıldın! Hedefe ulaşılınca kuponun cüzdanına eklenir.'
          : (response['message'] ?? 'İstek gönderilemedi').toString(),
      error: !ok,
    );
    if (ok && response['campaign'] is Map) {
      return Map<String, dynamic>.from(response['campaign']);
    }
    return null;
  }

  /// Sipariş öncesi "katılmak ister misin?" sorusu.
  /// true: katıl, false: katılmadan devam et, null: kapatıldı.
  static Future<bool?> askToJoin(
    BuildContext context,
    Map<String, dynamic> campaign,
  ) {
    final target = (campaign['targetCount'] ?? 0) as num;
    final current = (campaign['weightedCount'] ?? 0) as num;
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    final progressBox = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: MarketPalette.limeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.limeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title(campaign),
                    style: MarketText.label(
                        color: MarketPalette.greenDeep, size: 14)),
              ),
              const SizedBox(width: 8),
              Text('${current.toInt()} / ${target.toInt()} puan',
                  style: MarketText.caption(
                      color: MarketPalette.greenDark,
                      weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(MarketRadius.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    return showMarketSheet<bool>(
      context,
      builder: (sheetContext) => MarketPromptSheet(
        icon: Icons.groups_rounded,
        title: '${percent(campaign)} topluluk indirimine katılabilirsin',
        message:
            'Katılım şartını sağlıyorsun. Hedefe ulaşıldığında katılanlara ${percent(campaign)} indirim kuponu tanımlanır. Bu siparişin etkilenmez.',
        primaryLabel: 'Katıl ve devam et',
        primaryIcon: Icons.how_to_reg_rounded,
        onPrimary: () => Navigator.pop(sheetContext, true),
        secondaryLabel: 'Katılmadan devam et',
        onSecondary: () => Navigator.pop(sheetContext, false),
        child: progressBox,
      ),
    );
  }
}
