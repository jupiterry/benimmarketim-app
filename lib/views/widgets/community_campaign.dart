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
      aboveNavigation: true,
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

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MarketPalette.canvas,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: MarketPalette.lineStrong,
                      borderRadius: BorderRadius.circular(MarketRadius.sm),
                    ),
                  ),
                ),
                const Center(
                  child: MarketIconTile(
                    icon: Icons.groups_rounded,
                    size: 64,
                    background: MarketPalette.lime,
                    foreground: MarketPalette.greenDeep,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${percent(campaign)} topluluk indirimine katılabilirsin',
                  textAlign: TextAlign.center,
                  style: MarketText.title(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Katılım şartını sağlıyorsun. Hedefe ulaşıldığında katılanlara ${percent(campaign)} indirim kuponu tanımlanır. Bu siparişin etkilenmez.',
                  textAlign: TextAlign.center,
                  style: MarketText.body(color: MarketPalette.muted, size: 14),
                ),
                const SizedBox(height: 16),
                Container(
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
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('Katıl ve devam et'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.inkSoft,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Katılmadan devam et'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
