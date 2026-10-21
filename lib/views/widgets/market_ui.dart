import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/turkish_text.dart';
import 'market_palette.dart';

export 'market_palette.dart';
export 'market_scroll.dart';
export 'market_sheet.dart';

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

  /// Bölüm üstündeki küçük büyük harfli etiket (metni TurkishText.toUpper ile
  /// büyütülür).
  static TextStyle eyebrow({Color color = MarketPalette.greenDark}) =>
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

  /// İndirimden önceki, üstü çizili fiyat.
  static TextStyle oldPrice({double size = 12, Color color = MarketPalette.muted}) =>
      GoogleFonts.inter(
        color: color,
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.lineThrough,
        decorationColor: color,
        decorationThickness: 1.6,
      );

  /// Tek başına duran emoji (kategori simgesi vb.).
  static TextStyle emoji(double size) => GoogleFonts.inter(fontSize: size, height: 1);
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
// Metin biçimleri
// ---------------------------------------------------------------------------

const String _nbsp = '\u00A0';

// Rakam + birim ("400 g", "1 L", "10 lu", "4 x"). Birimden sonra harf gelirse
// eşleşmez ("1 Lira", "3 Lezzet").
final RegExp _unitAfterNumber = RegExp(
  r'(\d)\s+(?=(?:kg|kilo|gr|gram|g|mg|litre|lt|l|ml|cl|cc|adet|paket|li|lı|lu|lü|x|×)(?![A-Za-zÇĞİÖŞÜçğıöşü]))',
  caseSensitive: false,
);
// Çoklu paket: "4 x 100 g", "6×200 ml"
final RegExp _packSize = RegExp(r'\d\s*[x×]\s*\d', caseSensitive: false);
// Sondaki birim parantezi: "Bütün Piliç (kg)"
final RegExp _unitParenthesis = RegExp(
  r'\s+(?=\((?:kg|gr|g|adet|lt|l|ml|demet|paket)\))',
  caseSensitive: false,
);
final RegExp _whitespace = RegExp(r'\s+');

/// Ürün adını ekranda göstermek için hazırlar: sayı ile birimi ("400 g",
/// "4×100 g") ve sondaki "(kg)" gibi birim parantezini bölünmez boşlukla
/// birbirine bağlar; böylece birim tek başına alt satıra düşmez.
///
/// Yalnızca gösterim içindir; API'ye, aramaya ya da analitiğe giden ad
/// değiştirilmez.
String productDisplayName(String name) {
  return name
      .replaceAllMapped(_packSize, (m) => m[0]!.replaceAll(_whitespace, _nbsp))
      .replaceAllMapped(_unitAfterNumber, (m) => '${m[1]}$_nbsp')
      .replaceAll(_unitParenthesis, _nbsp);
}

/// Telefon numarasını "0532 123 45 67" biçiminde gösterir. Türk numarasına
/// benzemiyorsa (10–11 hane, +90 ile 12 hane) girdiyi olduğu gibi döndürür.
String formatPhoneTr(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('90')) digits = digits.substring(2);
  if (digits.length == 10 && !digits.startsWith('0')) digits = '0$digits';
  if (digits.length != 11 || !digits.startsWith('0')) return raw;
  return '${digits.substring(0, 4)} ${digits.substring(4, 7)} '
      '${digits.substring(7, 9)} ${digits.substring(9)}';
}

const List<String> _trMonths = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// Bir anı Türkiye saatine (UTC+3) çevirir. Dönen değer UTC işaretlidir ama
/// alanları (gün, saat) Türkiye'deki duvar saatidir.
DateTime turkeyTime(DateTime time) => time.toUtc().add(const Duration(hours: 3));

/// Tarihi Türkiye saatiyle kısa ve okunur yazar: "Bugün 04:40", "Dün 22:15",
/// "18 Eki 03:05"; başka bir yıldaysa "18 Eki 2025 03:05". [withTime] false
/// ise yalnızca gün ("Bugün", "18 Eki"). [now] testler içindir.
String formatTrDateTime(DateTime time, {bool withTime = true, DateTime? now}) {
  final local = turkeyTime(time);
  final today = turkeyTime(now ?? DateTime.now());
  final dayDiff = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  final String day;
  if (dayDiff == 0) {
    day = 'Bugün';
  } else if (dayDiff == 1) {
    day = 'Dün';
  } else if (dayDiff == -1) {
    day = 'Yarın';
  } else {
    final date = '${local.day} ${_trMonths[local.month - 1]}';
    day = local.year == today.year ? date : '$date ${local.year}';
  }
  if (!withTime) return day;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $hour:$minute';
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

  /// Alt sayfalar için kısa başlık: geri butonu, başlık ve aksiyonlar tek
  /// satırda durur (simge kutusu gösterilmez). Ekranın çok daha azını kaplar.
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

  static const _decoration = BoxDecoration(
    gradient: MarketPalette.headerGradient,
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(MarketRadius.xl)),
  );

  bool get _hasSubtitle => subtitle != null && subtitle!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);

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
            size: 48,
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.title(color: Colors.white),
                ),
              ),
              if (_hasSubtitle) ...[
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
      decoration: _decoration,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
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

  /// Tek satır: [geri | leading | simge kutusu] başlık/alt başlık [aksiyonlar].
  Widget _buildCompact(BuildContext context) {
    final lead = <Widget>[
      if (showBack)
        MarketHeaderButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Geri',
          onTap: onBack ?? () => _pop(context),
        ),
      if (leading != null)
        leading!
      else if (!showBack && icon != null)
        MarketIconTile(
          icon: icon!,
          size: 42,
          background: MarketPalette.lime,
          foreground: MarketPalette.greenDeep,
        ),
    ];
    return Container(
      width: double.infinity,
      decoration: _decoration,
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom == null ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final widget in lead) ...[widget, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MarketText.title(color: Colors.white, size: 20),
                      ),
                    ),
                    if (_hasSubtitle) ...[
                      const SizedBox(height: 2),
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
              for (var i = 0; i < actions.length; i++) ...[
                SizedBox(width: i == 0 ? 12 : 8),
                actions[i],
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 14),
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
    return Semantics(
      button: true,
      label: badgeCount > 0 ? '$tooltip, $badgeCount' : tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
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
                  width: MarketSize.headerButton,
                  height: MarketSize.headerButton,
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
      ),
    );
  }
}

/// Sayı rozeti (sepet, okunmamış mesaj). Lime zemin + koyu metin: yüksek kontrast.
/// Sayı artınca kısa bir büyüyüp küçülme ile dikkat çeker ("hareketi azalt"
/// açıksa durağan kalır).
class MarketCountBadge extends StatefulWidget {
  final int count;
  final Color outline;

  const MarketCountBadge({
    super.key,
    required this.count,
    this.outline = Colors.white,
  });

  @override
  State<MarketCountBadge> createState() => _MarketCountBadgeState();
}

class _MarketCountBadgeState extends State<MarketCountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_bump);

  @override
  void didUpdateWidget(covariant MarketCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count && !MediaQuery.disableAnimationsOf(context)) {
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: MarketPalette.lime,
          borderRadius: BorderRadius.circular(MarketRadius.sm),
          border: Border.all(color: widget.outline, width: 2),
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

  /// İç sayfa bölümleri için sade başlık: 18 pt başlık, tek satır alt başlık,
  /// üst etiket (eyebrow) gösterilmez. Eylem 44 pt dokunma alanlı "Tümü ›".
  final bool dense;

  /// Eylem yoksa başlığın yanında "[count] [countLabel]" hapı gösterilir.
  final int? count;
  final String countLabel;

  const MarketSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.dense = false,
    this.count,
    this.countLabel = 'ürün',
  });

  bool get _hasAction => actionLabel != null && onAction != null;

  @override
  Widget build(BuildContext context) {
    return dense ? _buildDense() : _buildRegular();
  }

  Widget _buildRegular() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(TurkishText.toUpper(eyebrow!), style: MarketText.eyebrow()),
                const SizedBox(height: 5),
              ],
              Semantics(
                header: true,
                child: Text(title, style: MarketText.title(size: 22)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: MarketText.caption(size: 13)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (_hasAction)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(actionLabel!, semanticsLabel: '$actionLabel: $title'),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              textStyle: MarketText.label(size: 13),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          )
        else if (count != null) ...[
          const SizedBox(width: 8),
          _countPill(),
        ],
      ],
    );
  }

  Widget _buildDense() {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Row(
      crossAxisAlignment: hasSubtitle ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.heading(size: 18),
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.caption(size: 12),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (_hasAction)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(actionLabel!, semanticsLabel: '$actionLabel: $title'),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              textStyle: MarketText.label(size: 13),
              minimumSize: const Size(MarketSize.control, MarketSize.control),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          )
        else if (count != null) ...[
          const SizedBox(width: 8),
          _countPill(),
        ],
      ],
    );
  }

  Widget _countPill() => MarketPill(
        label: '$count $countLabel',
        background: MarketPalette.fill,
        foreground: MarketPalette.muted,
      );
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

  /// Ana butonun altında ikincil, yazı görünümlü eylem (ör. "Aramayı temizle").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Bağlantı / sunucu hatası: aynı simge, metin ve "Tekrar dene" butonu.
  const MarketEmptyState.error({
    super.key,
    required VoidCallback onRetry,
    this.title = 'Bağlantı kurulamadı',
    this.message = 'İnternet bağlantını kontrol edip tekrar dene.',
    this.illustration,
    this.secondaryLabel,
    this.onSecondary,
  })  : icon = Icons.cloud_off_rounded,
        actionLabel = 'Tekrar dene',
        actionIcon = Icons.refresh_rounded,
        onAction = onRetry,
        tint = MarketPalette.orangeInk,
        tintSoft = MarketPalette.orangeSoft;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: MarketText.title(size: 22),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: MarketText.body(color: MarketPalette.muted, size: 14),
              ),
              if (hasAction) ...[
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 20),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(minimumSize: const Size(220, MarketSize.button)),
                ),
              ],
              if (hasSecondary) ...[
                SizedBox(height: hasAction ? 8 : 22),
                TextButton(
                  onPressed: onSecondary,
                  style: TextButton.styleFrom(
                    foregroundColor: MarketPalette.greenDark,
                    minimumSize: const Size(220, MarketSize.tapTarget),
                  ),
                  child: Text(secondaryLabel!),
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
            child: Semantics(
              header: true,
              child: Text(
                TurkishText.toUpper(title!),
                style: MarketText.eyebrow(color: MarketPalette.muted),
              ),
            ),
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

/// Miktar seçici (sepet, ürün kartı, ürün detay).
///
/// Görünür boyutlar: [compact] 44 × 90, normal 44 × 108, [large] 54 × 124
/// (satın alma çubuğunda 54 pt'lik butonla aynı boy). [height] verilirse
/// yükseklik onunla değişir (48'den büyükse geniş düğmeler kullanılır).
/// Seçicinin sol yarısı azaltır, sağ yarısı artırır; her yarı en az 44 pt
/// genişliğindedir. Ekran okuyucu tek bir ayarlanabilir "Adet" denetimi ve
/// ayrıca Azalt / Artır düğmeleri duyar.
class MarketStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;
  final IconData? minusIcon;

  /// Satın alma çubuğu boyu (54).
  final bool large;

  /// Yüksekliği elle belirler (ör. 52'lik bir butonun yanında).
  final double? height;

  /// false ise ilgili düğme soluklaşır ve dokunulmaz (ör. en az / en çok adet).
  final bool canDecrement;
  final bool canIncrement;

  /// Ekran okuyucunun duyduğu ad.
  final String semanticLabel;

  const MarketStepper({
    super.key,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
    this.minusIcon,
    this.large = false,
    this.height,
    this.canDecrement = true,
    this.canIncrement = true,
    this.semanticLabel = 'Adet',
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? (large ? MarketSize.button : MarketSize.control);
    final wide = large || h > 48;
    final step = wide ? 46.0 : (compact ? 34.0 : 40.0);
    final countWidth = wide ? 32.0 : (compact ? 22.0 : 28.0);
    final half = step + countWidth / 2;
    final fontSize = wide ? 16.0 : (compact ? 13.0 : 14.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final minusTooltip = !canDecrement
        ? 'En az $quantity adet'
        : quantity <= 1 && minusIcon != null
            ? 'Sepetten çıkar'
            : 'Azalt';
    final plusTooltip = canIncrement ? 'Artır' : 'En fazla $quantity adet';

    return Semantics(
      container: true,
      label: semanticLabel,
      value: '$quantity',
      increasedValue: canIncrement ? '${quantity + 1}' : null,
      decreasedValue: canDecrement ? '${quantity - 1}' : null,
      onIncrease: canIncrement ? onPlus : null,
      onDecrease: canDecrement ? onMinus : null,
      child: Material(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: h,
          width: half * 2,
          child: Stack(
            children: [
              Row(
                children: [
                  _StepButton(
                    icon: minusIcon ?? Icons.remove_rounded,
                    onTap: canDecrement ? onMinus : null,
                    width: half,
                    iconWidth: step,
                    alignment: Alignment.centerLeft,
                    tooltip: minusTooltip,
                    iconSize: wide ? 22 : 19,
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: canIncrement ? onPlus : null,
                    width: half,
                    iconWidth: step,
                    alignment: Alignment.centerRight,
                    tooltip: plusTooltip,
                    iconSize: wide ? 22 : 19,
                  ),
                ],
              ),
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
                      child: Text(
                        '$quantity',
                        key: ValueKey(quantity),
                        textAlign: TextAlign.center,
                        style: MarketText.label(color: MarketPalette.greenDeep, size: fontSize),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double width;
  final double iconWidth;
  final Alignment alignment;
  final String tooltip;
  final double iconSize;

  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.width,
    required this.iconWidth,
    required this.alignment,
    required this.tooltip,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Align(
            alignment: alignment,
            child: SizedBox(
              width: iconWidth,
              child: Icon(
                icon,
                color: onTap == null ? MarketPalette.subtle : MarketPalette.greenDark,
                size: iconSize,
              ),
            ),
          ),
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

  /// Nötr bilgi (mavi): uyarı olmayan açıklamalar için.
  const MarketNotice.info({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  })  : background = MarketPalette.blueSoft,
        foreground = MarketPalette.blue;

  /// Olumlu durum (yeşil); varsayılan kurucuyla aynı görünür.
  const MarketNotice.success({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  })  : background = MarketPalette.greenSoft,
        foreground = MarketPalette.greenDark;

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

// ---------------------------------------------------------------------------
// Çip (filtre, sıralama, seçenek)
// ---------------------------------------------------------------------------

enum MarketChipTone { neutral, danger }

/// Uygulamanın tek çip bileşeni: filtre, sıralama, seçenek ve açılır seçim.
///
/// Görünür yükseklik 40, dokunma alanı 48 (üst/alt 4 pt boşluk dahil).
/// Seçiliyken yumuşak zemin + 1,5 pt vurgu çerçevesi; simge yoksa ✓ gösterilir.
/// [dropdown] sağa açılır ok ekler; [onClear] verilirse ok yerine kendi
/// dokunma alanı olan ✕ ("Filtreyi kaldır") çıkar.
class MarketChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final bool dropdown;
  final VoidCallback? onClear;
  final MarketChipTone tone;

  /// Seçili çerçeve/simge, seçili zemin ve seçili metin rengi. Verilmezse
  /// tona göre: nötr yeşil (green / greenSoft / greenDark), tehlike kırmızı.
  final Color? accent;
  final Color? accentSoft;
  final Color? accentInk;

  /// Etiketin yanında küçük sayı (ör. etkin filtre sayısı).
  final int? badgeCount;

  /// Seçiliyken simge yoksa ✓ gösterilsin mi.
  final bool showCheck;

  /// Ekran okuyucu etiketi (verilmezse [label]).
  final String? semanticLabel;

  final bool _onDark;

  const MarketChip({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.selected = false,
    this.onTap,
    this.dropdown = false,
    this.onClear,
    this.tone = MarketChipTone.neutral,
    this.accent,
    this.accentSoft,
    this.accentInk,
    this.badgeCount,
    this.showCheck = true,
    this.semanticLabel,
  }) : _onDark = false;

  /// Koyu yeşil başlık üzerindeki çip: yarı saydam beyaz zemin; seçiliyken lime.
  const MarketChip.onDark({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.selected = false,
    this.onTap,
    this.dropdown = false,
    this.badgeCount,
    this.semanticLabel,
  })  : _onDark = true,
        onClear = null,
        tone = MarketChipTone.neutral,
        accent = null,
        accentSoft = null,
        accentInk = null,
        showCheck = false;

  @override
  Widget build(BuildContext context) {
    final danger = tone == MarketChipTone.danger;
    final accentColor = accent ?? (danger ? MarketPalette.red : MarketPalette.green);
    final Color background;
    final Color foreground;
    final Color iconColor;
    final BorderSide side;
    if (_onDark) {
      background = selected ? MarketPalette.lime : Colors.white.withValues(alpha: .12);
      foreground = selected ? MarketPalette.greenDeep : Colors.white;
      iconColor = selected ? MarketPalette.greenDeep : MarketPalette.lime;
      side = BorderSide.none;
    } else if (selected) {
      background = accentSoft ?? (danger ? MarketPalette.redSoft : MarketPalette.greenSoft);
      foreground = accentInk ?? (danger ? MarketPalette.red : MarketPalette.greenDark);
      iconColor = accentColor;
      side = BorderSide(color: accentColor, width: 1.5);
    } else {
      background = MarketPalette.surface;
      foreground = MarketPalette.ink;
      iconColor = MarketPalette.muted;
      side = const BorderSide(color: MarketPalette.line);
    }

    final lead = leading ??
        (icon != null
            ? Icon(icon, size: 18, color: iconColor)
            : selected && showCheck
                ? Icon(Icons.check_rounded, size: 16, color: iconColor)
                : null);
    final count = badgeCount ?? 0;

    final chip = Material(
      color: background,
      shape: StadiumBorder(side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.only(
              left: lead == null ? 14 : 12,
              right: onClear != null ? 4 : (dropdown ? 10 : 14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 6)],
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.label(color: foreground, size: 13, weight: FontWeight.w600),
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: MarketPalette.lime,
                      borderRadius: BorderRadius.circular(MarketRadius.pill),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: MarketText.label(color: MarketPalette.greenDeep, size: 11, weight: FontWeight.w800),
                    ),
                  ),
                ],
                if (onClear != null) ...[
                  const SizedBox(width: 2),
                  Semantics(
                    container: true,
                    button: true,
                    label: 'Filtreyi kaldır',
                    child: InkWell(
                      onTap: onClear,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.close_rounded, size: 18, color: foreground),
                      ),
                    ),
                  ),
                ] else if (dropdown) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 18, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final text = semanticLabel ?? (count > 0 ? '$label, $count filtre etkin' : label);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: text,
      child: ExcludeSemantics(
        excluding: onClear == null,
        // Çipin üstündeki/altındaki 4 pt da dokunmayı alır (48 pt hedef).
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: chip,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt eylem çubuğu (sepet, ödeme, ürün detay)
// ---------------------------------------------------------------------------

/// Sayfanın altına sabitlenen beyaz eylem çubuğu. Beyaz zemin ana ekran
/// çubuğunun (home indicator) altına kadar uzanır; içerik güvenli alanda kalır.
class MarketBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// false ise alt güvenli alan eklenmez (ör. altında başka bir çubuk varsa).
  final bool safeArea;

  const MarketBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MarketPalette.surface,
        border: const Border(top: BorderSide(color: MarketPalette.line)),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: safeArea,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Toplam tutar + ana eylem: solda etiket, fiyat ve (varsa) kazanç; sağda
/// geniş buton. [MarketBottomBar] içinde kullanılır.
class MarketTotalAction extends StatelessWidget {
  /// Tutarın üstündeki etiket ("Toplam", "Ödenecek").
  final String label;
  final double amount;

  /// 0'dan büyükse "₺X kazanç" satırı gösterilir.
  final double savings;
  final String actionLabel;

  /// null ise buton pasif görünür (ör. "₺38,60 daha ekle").
  final VoidCallback? onPressed;

  /// true iken buton yeşil kalır, yerine dönen gösterge çıkar ve dokunulmaz.
  final bool loading;
  final IconData? actionIcon;

  const MarketTotalAction({
    super.key,
    required this.label,
    required this.amount,
    this.savings = 0,
    required this.actionLabel,
    this.onPressed,
    this.loading = false,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: MarketText.caption()),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatTl(amount), style: MarketText.price(size: 22)),
                  ),
                  if (savings > 0)
                    Text(
                      '${formatTl(savings)} kazanç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.caption(color: MarketPalette.greenDark, weight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: loading ? null : onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(MarketSize.button),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  disabledBackgroundColor: loading ? MarketPalette.green : null,
                  disabledForegroundColor: loading ? Colors.white : null,
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    // Dar ekranda / büyük yazıda önce ok simgesi düşer, sonra
                    // metin iki satıra iner; yazı küçültülmez. Simge, metin
                    // onunla tek satıra sığmıyorsa da gösterilmez.
                    : LayoutBuilder(
                        builder: (context, box) {
                          var showIcon = actionIcon != null && box.maxWidth >= 170;
                          if (showIcon) {
                            final painter = TextPainter(
                              text: TextSpan(text: actionLabel, style: DefaultTextStyle.of(context).style),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                              maxLines: 1,
                            )..layout();
                            showIcon = painter.width + 28 <= box.maxWidth;
                            painter.dispose();
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  actionLabel,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showIcon) ...[
                                const SizedBox(width: 8),
                                Icon(actionIcon, size: 20),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Diyalog tonları ve bekleme göstergesi
// ---------------------------------------------------------------------------

/// Diyalog / onay pencerelerinin tonu: marka (yeşil), tehlike (kırmızı, silme
/// gibi geri alınamayan işler), favori (pembe kalp).
enum MarketTone { brand, danger, favorite }

/// [task] bitene kadar ekranı "[message]" yazan bir bekleme kartıyla kilitler
/// (geri tuşu ve dışarı dokunma kapatmaz), sonra kartı kapatıp sonucu döndürür.
/// Hata olursa kart yine kapanır ve hata çağırana iletilir. [liveMessage]
/// verilirse metin ilerledikçe güncellenir (ör. "3/5 ürün ekleniyor").
Future<T> runWithMarketProgress<T>(
  BuildContext context, {
  required String message,
  ValueListenable<String>? liveMessage,
  required Future<T> Function() task,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: MarketPalette.scrim,
    builder: (_) => _MarketProgressCard(message: message, liveMessage: liveMessage),
  );
  navigator.push(route);
  try {
    return await task();
  } finally {
    if (route.isActive) {
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }
  }
}

class _MarketProgressCard extends StatelessWidget {
  final String message;
  final ValueListenable<String>? liveMessage;

  const _MarketProgressCard({required this.message, this.liveMessage});

  @override
  Widget build(BuildContext context) {
    Widget text(String value) => Text(
          value,
          textAlign: TextAlign.center,
          style: MarketText.label(size: 14),
        );
    return PopScope(
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Material(
            color: MarketPalette.surface,
            borderRadius: BorderRadius.circular(MarketRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: MarketPalette.green),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: liveMessage == null
                        ? text(message)
                        : ValueListenableBuilder<String>(
                            valueListenable: liveMessage!,
                            builder: (context, value, _) => text(value),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bildirim çubuğu (snackbar)
// ---------------------------------------------------------------------------

/// Uygulama genelinde aynı görünen bildirim çubuğu.
///
/// Scaffold yüzen çubuğu zaten alt gezinme çubuğunun ve varsa yüzen butonun
/// üstüne yerleştirir; [aboveNavigation] bu yüzden artık etkisizdir (yalnızca
/// eski çağrılar derlensin diye duruyor). Sayfanın alt kenarında Scaffold'un
/// bilmediği bir çubuk varsa [bottomGap] kadar yukarı kaldırılır.
///
/// [actionLabel] + [onAction] verilirse sağda lime renkli eylem ("Geri al")
/// çıkar ve süre 4 sn olur; aksi halde 2,6 sn.
void showMarketSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  bool error = false,
  bool aboveNavigation = false,
  double bottomGap = 0,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final hasAction = actionLabel != null && onAction != null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Semantics(
          container: true,
          liveRegion: true,
          child: Row(
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
        ),
        backgroundColor: error ? MarketPalette.red : MarketPalette.greenDeep,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomGap),
        duration: duration ?? Duration(milliseconds: hasAction ? 4000 : 2600),
        // Eylemli çubuk da süresi dolunca kapanır (Flutter'ın varsayılanı açık
        // kalmak); ekran okuyucu açıksa eyleme ulaşılabilsin diye açık kalır.
        persist: hasAction && MediaQuery.accessibleNavigationOf(context),
        action: hasAction
            ? SnackBarAction(
                label: actionLabel,
                textColor: MarketPalette.lime,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
