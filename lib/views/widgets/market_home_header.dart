import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'market_ui.dart';

class MarketHomeHeader extends StatelessWidget {
  const MarketHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<ChatViewModel, int>((c) => c.totalUnreadCount);
    final name = context.select<AuthViewModel, String?>((a) => a.user?.name);
    final firstName = (name ?? '').trim().split(RegExp(r'\s+')).first;

    return Container(
      decoration: const BoxDecoration(
        gradient: MarketPalette.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(MarketRadius.xl)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -70,
            child: _DecorativeCircle(size: 230, opacity: .05),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MarketIconTile(
                      icon: Icons.storefront_rounded,
                      size: 44,
                      background: MarketPalette.lime,
                      foreground: MarketPalette.greenDeep,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Benim Marketim',
                            style: MarketText.heading(color: Colors.white, size: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Devrek • Yurda teslimat',
                            style: MarketText.caption(
                              color: Colors.white.withValues(alpha: .7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MarketHeaderButton(
                      icon: Icons.favorite_border_rounded,
                      tooltip: 'Favorilerim',
                      onTap: () => context.push('/favorites'),
                    ),
                    const SizedBox(width: 8),
                    MarketHeaderButton(
                      icon: Icons.support_agent_rounded,
                      tooltip: 'Canlı destek',
                      badgeCount: unread,
                      onTap: () => context.push('/chat'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  firstName.isEmpty ? 'Merhaba' : 'Merhaba, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.display(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün neye ihtiyacın var?',
                  style: MarketText.body(
                    color: Colors.white.withValues(alpha: .76),
                    size: 14,
                  ),
                ),
                const SizedBox(height: 14),
                const _StoreStatusRow(),
                const SizedBox(height: 16),
                const _SearchField(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mağaza açık mı, ne zaman kapanıyor, minimum sepet — müşterinin
/// sipariş vermeden önce bilmesi gerekenler.
class _StoreStatusRow extends StatelessWidget {
  const _StoreStatusRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, settings, _) {
        String hhmm(int h, int m) =>
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        final open = settings.isWithinOrderHours;
        final allDay = settings.orderStartHour == 0 &&
            settings.orderStartMinute == 0 &&
            settings.orderEndHour == 0 &&
            settings.orderEndMinute == 0;
        final statusText = allDay
            ? '7/24 açık'
            : open
                ? 'Açık • Kapanış ${hhmm(settings.orderEndHour, settings.orderEndMinute)}'
                : 'Kapalı • Açılış ${hhmm(settings.orderStartHour, settings.orderStartMinute)}';

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: open ? MarketPalette.lime : MarketPalette.orange,
                  shape: BoxShape.circle,
                ),
              ),
              label: statusText,
            ),
            _HeaderChip(
              leading: Icon(
                Icons.shopping_basket_outlined,
                size: 15,
                color: Colors.white.withValues(alpha: .85),
              ),
              label: 'Min. sepet ${formatTlShort(settings.minimumOrderAmount)}',
            ),
          ],
        );
      },
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final Widget leading;
  final String label;

  const _HeaderChip({required this.leading, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(MarketRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 7),
          Text(
            label,
            style: MarketText.label(color: Colors.white, size: 12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ürünlerde ara',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        elevation: 0,
        child: InkWell(
          onTap: () => context.push('/search'),
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search_rounded, color: MarketPalette.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ürün, kategori veya marka ara',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.body(color: MarketPalette.muted, size: 14),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: MarketPalette.greenSoft,
                    borderRadius: BorderRadius.circular(MarketRadius.sm),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: MarketPalette.greenDark,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
