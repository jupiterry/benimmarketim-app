import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'home_quick_carts.dart';
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
  void initState() {
    super.initState();
    // Aşağı çekip yenileyince ilerleme de güncellenir
    homeRefreshSignal.addListener(_reload);
  }

  @override
  void dispose() {
    homeRefreshSignal.removeListener(_reload);
    super.dispose();
  }

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
      _load(userId);
    }
  }

  void _reload() {
    final userId = _loadedForUser;
    if (userId != null) _load(userId);
  }

  Future<void> _load(String userId) async {
    final missions = await ApiService().getActiveMissions();
    // Yükleme sürerken hesap değiştiyse eski sonucu gösterme
    if (!mounted || _loadedForUser != userId) return;
    setState(() => _missions = missions);
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MarketSpace.gutterOf(context);
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _missions.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.fromLTRB(gutter, MarketSpace.xxl, gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _missions.length; i++) ...[
                    if (i > 0) const SizedBox(height: MarketSpace.md),
                    _MissionCard(mission: _missions[i]),
                  ],
                ],
              ),
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
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          if (rule.isNotEmpty) ...[
            const SizedBox(height: MarketSpace.sm),
            // Yöneticinin belirlediği kural: "300 TL ve üzeri 3 sipariş ver, 100 TL kupon kazan"
            Text(
              rule,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: MarketText.heading(size: 15),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MarketText.caption(),
            ),
          ],
          const SizedBox(height: 10),
          Semantics(
            label: 'İlerleme: $target siparişten $progress',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: target <= 10
                      ? _SegmentedProgress(total: target, done: progress)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(MarketRadius.pill),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: MarketPalette.surface,
                            color: MarketPalette.green,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$progress/$target',
                  style: MarketText.price(color: MarketPalette.greenDark, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: MarketSpace.sm),
          if (completed && couponCode != null)
            _CouponRow(code: couponCode)
          else
            Text(
              progress == 0
                  ? 'İlk siparişinle başla · teslim edilince sayılır'
                  : '$remaining sipariş kaldı · teslim edilince sayılır',
              style: MarketText.caption(),
            ),
        ],
      ),
    );
  }
}

/// Hedef küçükse (en çok 10) her sipariş ayrı bir parça olarak görünür.
class _SegmentedProgress extends StatelessWidget {
  final int total;
  final int done;

  const _SegmentedProgress({required this.total, required this.done});

  @override
  Widget build(BuildContext context) {
    final count = total < 1 ? 1 : total;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < done ? MarketPalette.green : MarketPalette.surface,
                borderRadius: BorderRadius.circular(MarketRadius.pill),
                border: i < done
                    ? null
                    : Border.all(color: MarketPalette.limeLine),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CouponRow extends StatelessWidget {
  final String code;

  const _CouponRow({required this.code});

  @override
  Widget build(BuildContext context) {
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: code));
      if (context.mounted) {
        showMarketSnack(context, 'Kupon kodu kopyalandı');
      }
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Kupon kodunu kopyala: $code',
      excludeSemantics: true,
      onTap: copy,
      child: InkWell(
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        onTap: copy,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MarketSize.control),
          child: Row(
            children: [
              // Kod hiç kesilmez: sığmazsa "Kuponun hazır:" satırının altına
              // iner (kazanılan kupon okunabilmeli).
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Kuponun hazır: ',
                        style: MarketText.label(color: MarketPalette.greenDark),
                      ),
                      Text(code, style: MarketText.code(size: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MarketSpace.sm),
              Text(
                'Kopyala',
                style: MarketText.label(color: MarketPalette.greenDark),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded,
                  size: 16, color: MarketPalette.greenDark),
            ],
          ),
        ),
      ),
    );
  }
}
