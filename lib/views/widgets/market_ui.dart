import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'market_palette.dart';

export 'market_palette.dart';
export 'market_scroll.dart';

// ---------------------------------------------------------------------------
// Tipografi: başlıklar Manrope, metinler Inter. En küçük metin 11 px.
// ---------------------------------------------------------------------------

abstract final class MarketText {
  static TextStyle display({Color color = MarketPalette.ink}) =>
      GoogleFonts.manrope(
        color: color,
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
      );

  static TextStyle title({Color color = MarketPalette.ink, double size = 22}) =>
      GoogleFonts.manrope(
        color: color,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -.45,
      );

  static TextStyle heading({Color color = MarketPalette.ink, double size = 16}) =>
      GoogleFonts.manrope(
        color: color,
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -.25,
      );

  static TextStyle body({
    Color color = MarketPalette.ink,
    double size = 14,
    FontWeight weight = FontWeight.w500,
    double height = 1.45,
  }) =>
      GoogleFonts.inter(
        color: color,
        fontSize: size,
        height: height,
        fontWeight: weight,
      );

  static TextStyle label({
    Color color = MarketPalette.ink,
    double size = 13,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.inter(
        color: color,
        fontSize: size,
        height: 1.25,
        fontWeight: weight,
      );

  static TextStyle caption({
    Color color = MarketPalette.muted,
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.inter(
        color: color,
        fontSize: size,
        height: 1.35,
        fontWeight: weight,
      );

  /// Bölüm üstündeki küçük büyük harfli etiket.
  static TextStyle eyebrow({Color color = MarketPalette.green}) =>
      GoogleFonts.inter(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      );

  static TextStyle price({Color color = MarketPalette.ink, double size = 16}) =>
      GoogleFonts.manrope(
        color: color,
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      );

  static TextStyle code({Color color = MarketPalette.greenDark, double size = 14}) =>
      GoogleFonts.spaceMono(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      );
}

/// Türk Lirası biçimi: ₺1.249,90
String formatTl(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}₺$buffer,${parts[1]}';
}

/// Tam sayıysa kuruşsuz gösterir: ₺250 / ₺249,90
String formatTlShort(num value) {
  if (value == value.roundToDouble()) {
    final text = formatTl(value);
    return text.substring(0, text.length - 3);
  }
  return formatTl(value);
}

// ---------------------------------------------------------------------------
// Sayfa başlığı (koyu yeşil, alt köşeleri yuvarlak)
// ---------------------------------------------------------------------------

class MarketHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;
  final bool compact;

  const MarketHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.bottom,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Geri butonu her zaman görünür; geri gidilecek sayfa yoksa ana sayfaya
    // döner (bildirim / doğrudan link ile açılan sayfalarda kullanıcı kalmaz).
    final canPop = showBack;
    final titleRow = Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 13),
        ] else if (icon != null) ...[
          MarketIconTile(
            icon: icon!,
            size: compact ? 42 : 48,
            background: MarketPalette.lime,
            foreground: MarketPalette.greenDeep,
          ),
          const SizedBox(width: 13),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MarketText.title(color: Colors.white),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(
                    color: Colors.white.withValues(alpha: .74),
                    size: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Geri butonu yoksa aksiyonlar başlıkla aynı satırda durur.
        if (!canPop)
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(width: i == 0 ? 12 : 8),
            actions[i],
          ],
      ],
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: MarketPalette.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(MarketRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 14 : 20),
              child: Row(
                children: [
                  if (canPop)
                    MarketHeaderButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Geri',
                      onTap: onBack ?? () => _pop(context),
                    ),
                  const Spacer(),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ),
          titleRow,
          if (bottom != null) ...[
            const SizedBox(height: 18),
            bottom!,
          ],
        ],
      ),
    );
  }

  static void _pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }
}

class MarketHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;

  const MarketHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(MarketRadius.md),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: MarketCountBadge(count: badgeCount, outline: MarketPalette.greenDeep),
            ),
        ],
      ),
    );
  }
}

/// Sayı rozeti (sepet, okunmamış mesaj). Lime zemin + koyu metin: yüksek kontrast.
class MarketCountBadge extends StatelessWidget {
  final int count;
  final Color outline;

  const MarketCountBadge({
    super.key,
    required this.count,
    this.outline = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: MarketPalette.lime,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        border: Border.all(color: outline, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.inter(
          color: MarketPalette.greenDeep,
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Temel yapı taşları
// ---------------------------------------------------------------------------

class MarketIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  const MarketIconTile({
    super.key,
    required this.icon,
    this.size = 42,
    this.background = MarketPalette.greenSoft,
    this.foreground = MarketPalette.greenDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, color: foreground, size: size * .5),
    );
  }
}

class MarketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;
  final bool shadow;

  const MarketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color = MarketPalette.surface,
    this.borderColor = MarketPalette.line,
    this.radius = MarketRadius.lg,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: MarketPalette.greenDeep.withValues(alpha: .05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class MarketSectionTitle extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const MarketSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!, style: MarketText.eyebrow()),
                const SizedBox(height: 5),
              ],
              Text(title, style: MarketText.title(size: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: MarketText.caption(size: 13)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              textStyle: MarketText.label(size: 13),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
      ],
    );
  }
}

class MarketPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const MarketPill({
    super.key,
    required this.label,
    this.icon,
    this.background = MarketPalette.greenSoft,
    this.foreground = MarketPalette.greenDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MarketRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MarketText.label(color: foreground, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color tint;
  final Color tintSoft;

  /// Verilirse simge kutusunun yerine gösterilir (ör. maskot).
  final Widget? illustration;

  const MarketEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.tint = MarketPalette.greenDark,
    this.tintSoft = MarketPalette.greenSoft,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              illustration ??
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: tintSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.xl),
                    ),
                    child: Icon(icon, size: 52, color: tint),
                  ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MarketText.title(size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: MarketText.body(color: MarketPalette.muted, size: 14),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 20),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(minimumSize: const Size(220, 54)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ayarlar / Hesabım listeleri için gruplu menü.
class MarketMenuGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const MarketMenuGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(title!.toUpperCase(), style: MarketText.eyebrow(color: MarketPalette.muted)),
          ),
        MarketCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 68, color: MarketPalette.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MarketMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;
  final Color iconBackground;
  final bool destructive;

  const MarketMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor = MarketPalette.greenDark,
    this.iconBackground = MarketPalette.greenSoft,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? MarketPalette.red : MarketPalette.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            MarketIconTile(
              icon: icon,
              size: 40,
              background: destructive ? MarketPalette.redSoft : iconBackground,
              foreground: destructive ? MarketPalette.red : iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MarketText.label(color: color, size: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: MarketText.caption()),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: MarketPalette.subtle),
          ],
        ),
      ),
    );
  }
}

/// Miktar seçici (sepet, ürün detay).
class MarketStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;
  final IconData? minusIcon;

  const MarketStepper({
    super.key,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
    this.minusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 38.0 : 44.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: minusIcon ?? Icons.remove_rounded,
            onTap: onMinus,
            size: height,
            width: compact ? 30 : 40,
            tooltip: quantity <= 1 && minusIcon != null ? 'Sepetten çıkar' : 'Azalt',
          ),
          SizedBox(
            width: compact ? 22 : 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: MarketText.label(color: MarketPalette.greenDeep, size: compact ? 13 : 14),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: onPlus,
            size: height,
            width: compact ? 30 : 40,
            tooltip: 'Artır',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double width;
  final String tooltip;

  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.width,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.sm),
        child: SizedBox(
          width: width,
          height: size,
          child: Icon(icon, color: MarketPalette.greenDark, size: 19),
        ),
      ),
    );
  }
}

/// Bilgi / uyarı kutusu.
class MarketNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final Widget? trailing;

  const MarketNotice({
    super.key,
    required this.icon,
    required this.text,
    this.background = MarketPalette.greenSoft,
    this.foreground = MarketPalette.greenDark,
    this.trailing,
  });

  const MarketNotice.warning({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  })  : background = MarketPalette.orangeSoft,
        foreground = MarketPalette.orangeInk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: MarketText.body(color: foreground, size: 13, weight: FontWeight.w600, height: 1.4),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Basit iskelet (yükleniyor) kutusu.
class MarketSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const MarketSkeleton({super.key, this.width, required this.height, this.radius = MarketRadius.sm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MarketPalette.fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// İskeletleri hafifçe soldurup açar; "hareketi azalt" açıksa sabit kalır.
class MarketSkeletonPulse extends StatefulWidget {
  final Widget child;
  final String semanticLabel;

  const MarketSkeletonPulse({
    super.key,
    required this.child,
    this.semanticLabel = 'Yükleniyor',
  });

  @override
  State<MarketSkeletonPulse> createState() => _MarketSkeletonPulseState();
}

class _MarketSkeletonPulseState extends State<MarketSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: .5).animate(_controller),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Liste ekranları için kart iskeleti (sipariş, görüşme, geçmiş).
class MarketListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const MarketListSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return MarketSkeletonPulse(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: MarketSpace.md),
              const MarketCard(
                shadow: false,
                child: Row(
                  children: [
                    MarketSkeleton(width: 48, height: 48, radius: MarketRadius.md),
                    SizedBox(width: MarketSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: .6,
                            child: MarketSkeleton(height: 14, radius: MarketRadius.xs),
                          ),
                          SizedBox(height: MarketSpace.sm),
                          FractionallySizedBox(
                            widthFactor: .9,
                            child: MarketSkeleton(height: 12, radius: MarketRadius.xs),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uygulama genelinde aynı görünen bildirim çubuğu.
void showMarketSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  bool error = false,
  bool aboveNavigation = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline_rounded : icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MarketText.label(color: Colors.white, size: 13, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: error ? MarketPalette.red : MarketPalette.greenDeep,
        margin: EdgeInsets.fromLTRB(16, 0, 16, aboveNavigation ? 104 : 16),
        duration: const Duration(milliseconds: 1800),
      ),
    );
}
