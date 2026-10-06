import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'market_ui.dart';

/// Ana sayfada süren sipariş görevlerini ve müşterinin ilerlemesini gösterir.
/// Görev yoksa veya giriş yapılmamışsa yer kaplamaz.
class MissionSection extends StatefulWidget {
  const MissionSection({super.key});

  @override
  State<MissionSection> createState() => _MissionSectionState();
}

class _MissionSectionState extends State<MissionSection> {
  List<Map<String, dynamic>> _missions = const [];
  String? _loadedForUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Giriş durumu değişince (ör. açılışta profil yüklenince) yeniden yüklenir
    // didChangeDependencies içinde context.watch hata ayıklama modunda
    // izin verilmediği için Provider.of kullanılır.
    final auth = Provider.of<AuthViewModel>(context);
    final userId = auth.isLoggedIn ? auth.user?.id : null;
    if (userId == _loadedForUser) return;
    _loadedForUser = userId;
    if (userId == null) {
      _missions = const [];
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final missions = await ApiService().getActiveMissions();
    if (!mounted) return;
    setState(() => _missions = missions);
  }

  @override
  Widget build(BuildContext context) {
    if (_missions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(MarketSpace.xl, MarketSpace.lg, MarketSpace.xl, 0),
      child: Column(
        children: [
          for (final mission in _missions)
            Padding(
              padding: const EdgeInsets.only(bottom: MarketSpace.md),
              child: _MissionCard(mission: mission),
            ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Map<String, dynamic> mission;

  const _MissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final target = ((mission['targetOrders'] as num?) ?? 1).toInt();
    final progress = ((mission['progress'] as num?) ?? 0).toInt();
    final completed = mission['completed'] == true;
    final couponCode = mission['couponCode']?.toString();
    final ratio = target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0).toDouble();
    final remaining = progress >= target ? 0 : target - progress;
    final description = (mission['description'] ?? '').toString();
    final rule = (mission['rule'] ?? '').toString();
    final reward = (mission['rewardAmount'] as num?) ?? 0;

    return MarketCard(
      color: completed ? MarketPalette.greenSoft : MarketPalette.limeSoft,
      borderColor: completed ? MarketPalette.greenLine : MarketPalette.limeLine,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed
                    ? Icons.emoji_events_rounded
                    : Icons.local_fire_department_rounded,
                size: 18,
                color: completed ? MarketPalette.green : MarketPalette.orangeInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (mission['title'] ?? 'Görev').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.label(color: MarketPalette.inkSoft),
                ),
              ),
              const SizedBox(width: MarketSpace.sm),
              // Ödül her zaman görünür
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MarketPalette.greenDeep,
                  borderRadius: BorderRadius.circular(MarketRadius.pill),
                ),
                child: Text(
                  '${formatTlShort(reward)} ödül',
                  style: MarketText.label(color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: MarketSpace.sm),
          // Yöneticinin belirlediği kural: "300 TL ve üzeri 3 sipariş ver, 100 TL kupon kazan"
          Text(rule, style: MarketText.heading(size: 17)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(description, style: MarketText.caption(size: 13)),
          ],
          const SizedBox(height: MarketSpace.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MarketRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: MarketPalette.surface,
                    color: MarketPalette.green,
                  ),
                ),
              ),
              const SizedBox(width: MarketSpace.md),
              Text(
                '$progress/$target',
                style: MarketText.price(color: MarketPalette.greenDark, size: 16),
              ),
            ],
          ),
          const SizedBox(height: MarketSpace.sm),
          if (completed && couponCode != null)
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: couponCode));
                if (context.mounted) {
                  showMarketSnack(context, 'Kupon kodu kopyalandı',
                      aboveNavigation: true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tamamlandı! Kuponun: $couponCode',
                        style: MarketText.label(color: MarketPalette.greenDark),
                      ),
                    ),
                    const Icon(Icons.copy_rounded,
                        size: 16, color: MarketPalette.greenDark),
                  ],
                ),
              ),
            )
          else
            Text(
              progress == 0
                  ? 'İlk siparişinle başla. Siparişler teslim edilince sayılır.'
                  : '$remaining sipariş kaldı. Siparişler teslim edilince sayılır.',
              style: MarketText.caption(size: 12),
            ),
        ],
      ),
    );
  }
}
