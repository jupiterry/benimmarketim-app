import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/coupon.dart';
import '../models/referral.dart';
import '../viewmodels/referral_viewmodel.dart';
import 'widgets/market_ui.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<ReferralViewModel>();
      viewModel.loadReferralInfo();
      viewModel.loadCoupons(); // Kuponları yükle
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer<ReferralViewModel>(
        builder: (context, viewModel, child) {
          final referral = viewModel.referral;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              MarketHeader(
                title: 'Arkadaşını getir',
                subtitle: referral == null
                    ? 'Davet et, birlikte kazanın'
                    : 'Arkadaşın ilk siparişinde %${referral.inviteeDiscountPercent}, sen %${referral.rewardDiscountPercent} indirim kazanırsın',
                icon: Icons.celebration_rounded,
                compact: true,
              ),
              if (viewModel.isLoading && referral == null)
                const MarketListSkeleton(count: 3)
              else if (referral == null)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: MarketEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Davet bilgilerin yüklenemedi',
                    message: 'Bağlantını kontrol edip tekrar dene.',
                    actionLabel: 'Tekrar dene',
                    actionIcon: Icons.refresh_rounded,
                    onAction: viewModel.loadReferralInfo,
                    tint: MarketPalette.red,
                    tintSoft: MarketPalette.redSoft,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: _buildContent(viewModel, referral),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ReferralViewModel viewModel, Referral referral) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCodeCard(referral),
        const SizedBox(height: 14),
        _buildStatisticsRow(referral),
        const SizedBox(height: 14),
        MarketNotice.warning(
          icon: Icons.info_outline_rounded,
          text: referral.isActive
              ? '${referral.remainingInvites} davet hakkın kaldı. Ödül kuponun arkadaşının ilk siparişinden sonra oluşur ve ${referral.rewardExpiresInDays} gün geçerlidir.'
              : 'Davet görevin tamamlandı. Kazandığın ödül kuponunu sepetindeki kupon cüzdanında görebilirsin.',
        ),
        if (viewModel.referralCoupons.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Kazandığın kuponlar', style: MarketText.heading()),
          const SizedBox(height: 12),
          ...viewModel.referralCoupons.map(_buildCouponCard),
        ],
        if (referral.referredUsers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Davet ettiklerin', style: MarketText.heading()),
          const SizedBox(height: 12),
          MarketCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < referral.referredUsers.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 70),
                  _buildUserRow(referral.referredUsers[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildHowItWorks(referral),
      ],
    );
  }

  Widget _buildCodeCard(Referral referral) {
    return MarketCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          Text(
            referral.isActive ? 'Davet kodun' : 'Davet tamamlandı',
            style: MarketText.label(color: MarketPalette.muted, size: 13),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _copyCode(referral.code),
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: MarketPalette.limeSoft,
                borderRadius: BorderRadius.circular(MarketRadius.md),
                border: Border.all(color: MarketPalette.limeLine, width: 1.5),
              ),
              child: Text(
                referral.code,
                textAlign: TextAlign.center,
                style: MarketText.code(color: MarketPalette.greenDeep, size: 28)
                    .copyWith(letterSpacing: 4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyCode(referral.code),
                  icon: const Icon(Icons.copy_rounded, size: 19),
                  label: const Text('Kopyala'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: referral.isActive ? () => _shareCode(referral) : null,
                  icon: const Icon(Icons.share_rounded, size: 19),
                  label: const Text('Paylaş'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow(Referral referral) {
    Widget stat(IconData icon, String value, String label, Color fg, Color bg) =>
        Expanded(
          child: MarketCard(
            shadow: false,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                MarketIconTile(icon: icon, size: 38, background: bg, foreground: fg),
                const SizedBox(height: 8),
                Text(value, style: MarketText.title(size: 22)),
                Text(label, style: MarketText.caption()),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat(Icons.people_outline_rounded, '${referral.totalReferrals}', 'Davet',
            MarketPalette.blue, MarketPalette.blueSoft),
        const SizedBox(width: 10),
        stat(Icons.check_circle_outline_rounded, '${referral.successfulReferrals}',
            'Sipariş veren', MarketPalette.greenDark, MarketPalette.greenSoft),
        const SizedBox(width: 10),
        stat(Icons.redeem_rounded, '${referral.totalRewardsEarned}', 'Ödül',
            MarketPalette.orangeInk, MarketPalette.orangeSoft),
      ],
    );
  }

  Widget _buildUserRow(ReferredUser user) {
    final (Color fg, Color bg) = switch (user.status) {
      ReferralStatus.pending => (MarketPalette.orangeInk, MarketPalette.orangeSoft),
      ReferralStatus.completed => (MarketPalette.blue, MarketPalette.blueSoft),
      ReferralStatus.rewarded => (MarketPalette.greenDark, MarketPalette.greenSoft),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MarketPalette.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              user.name.isNotEmpty ? user.name.characters.first.toUpperCase() : '?',
              style: MarketText.heading(color: MarketPalette.greenDark, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: MarketText.label(size: 14)),
                Text(_formatDate(user.signedUpAt), style: MarketText.caption()),
              ],
            ),
          ),
          MarketPill(label: user.statusText, background: bg, foreground: fg),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(Referral referral) {
    final steps = [
      'Davet kodunu arkadaşlarınla paylaş',
      'Arkadaşın kodla kayıt olsun',
      'İlk siparişinde %${referral.inviteeDiscountPercent} indirim kazansın',
      'Sen de %${referral.rewardDiscountPercent} indirim kuponu kazan',
    ];
    return MarketCard(
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nasıl çalışır?', style: MarketText.heading(size: 16)),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == steps.length - 1 ? MarketPalette.lime : MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.xs),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: MarketText.label(color: MarketPalette.greenDeep, size: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(steps[i], style: MarketText.body(color: MarketPalette.inkSoft, size: 14)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    showMarketSnack(context, 'Kod kopyalandı');
  }

  void _shareCode(Referral referral) {
    HapticFeedback.lightImpact();

    final message = '''
🎁 Benim Marketim'e davetlisin!

"${referral.code}" koduyla kayıt ol, ilk siparişinde %${referral.inviteeDiscountPercent} indirim kazan!

${referral.link}
''';
    Share.share(message);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildCouponCard(Coupon coupon) {
    final isExpiringSoon = coupon.daysUntilExpiration <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MarketCard(
        shadow: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MarketPalette.greenDeep,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child: Text(
                coupon.discountText,
                style: MarketText.label(color: Colors.white, size: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.code,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.code(color: MarketPalette.ink, size: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isExpiringSoon
                        ? '${coupon.daysUntilExpiration} gün içinde süresi doluyor'
                        : 'Son gün ${_formatDate(coupon.expirationDate)}',
                    style: MarketText.caption(
                      color: isExpiringSoon ? MarketPalette.orangeInk : MarketPalette.muted,
                      weight: isExpiringSoon ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _copyCode(coupon.code),
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Kopyala'),
            ),
          ],
        ),
      ),
    );
  }
}
