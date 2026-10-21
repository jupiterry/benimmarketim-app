import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'market_mascot.dart';
import 'market_ui.dart';

/// Giriş / kayıt sayfası iskeleti. Yeşil başlık kaydırılan içeriğin bir
/// parçasıdır: klavye açılınca ya da sayfa kaydırılınca beyaz yazı açık
/// zemine taşmaz. Form kartı başlığın alt kısmına biner.
class AuthPageShell extends StatelessWidget {
  /// Yeşil zemindeki marka ve başlık (genellikle [AuthBrandHeader]).
  final Widget header;

  /// Başlığın altına binen form kartı ve altındaki bağlantılar.
  final Widget child;
  final VoidCallback? onBack;

  const AuthPageShell({
    super.key,
    required this.header,
    required this.child,
    this.onBack,
  });

  /// Kartın yeşil başlığa bindiği yükseklik.
  static const double _overlap = 72;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final gutter = MarketSpace.gutterOf(context);
    Widget constrained(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        );

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: SingleChildScrollView(
        // Üst kenarda esneme yok: yeşil zeminin üstünde açık şerit görünmez.
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(gradient: MarketPalette.headerGradient),
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, padding.top + 10, gutter, 26),
                child: constrained(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onBack != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AuthBackButton(onTap: onBack!),
                        ),
                        const SizedBox(height: 18),
                      ] else
                        const SizedBox(height: 8),
                      header,
                    ],
                  ),
                ),
              ),
            ),
            Stack(
              children: [
                // Başlığın devamı: kartın üst kısmının arkasında kalır.
                const SizedBox(
                  height: _overlap,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MarketPalette.greenDark,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(MarketRadius.xl),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + padding.bottom),
                  child: constrained(child),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeşil zemindeki marka imzası, büyük başlık ve kısa açıklama.
class AuthBrandHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Uzun formlar için kısa başlık: boşluk daralır, açıklama gösterilmez.
  final bool compact;

  const AuthBrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketBrandMark(
          mascotSize: compact ? 38 : 44,
          wordmarkHeight: compact ? 26 : 30,
          tagline: 'Devrek • Yurda teslimat',
        ),
        SizedBox(height: compact ? 18 : 28),
        Semantics(
          header: true,
          child: Text(
            title,
            style: narrow || compact
                ? MarketText.title(color: Colors.white, size: 26)
                : MarketText.display(color: Colors.white),
          ),
        ),
        if (!compact && subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: MarketText.body(
              color: Colors.white.withValues(alpha: .78),
              size: 14,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthFormCard extends StatelessWidget {
  final Widget child;

  const AuthFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Container(
      padding: EdgeInsets.all(narrow ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketRadius.xl),
        border: Border.all(color: MarketPalette.line),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.ink.withValues(alpha: .07),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool showLabel;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
    this.onChanged,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.showLabel = true,
    this.focusNode,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(MarketRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(label, style: MarketText.label(size: 13)),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          style: MarketText.body(weight: FontWeight.w600),
          decoration: InputDecoration(
            // Etiket görünmüyorsa ekran okuyucu yine de alanın adını duyar.
            labelText: showLabel ? null : label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: hint,
            hintStyle: MarketText.body(color: MarketPalette.muted),
            prefixIcon: Icon(icon, color: MarketPalette.green, size: 21),
            suffixIcon: suffix ??
                (onToggleVisibility == null
                    ? null
                    : IconButton(
                        onPressed: onToggleVisibility,
                        tooltip: obscureText ? 'Şifreyi göster' : 'Şifreyi gizle',
                        icon: Icon(
                          obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: MarketPalette.muted,
                          size: 20,
                        ),
                      )),
            filled: true,
            fillColor: MarketPalette.canvas,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            border: border(MarketPalette.line),
            enabledBorder: border(MarketPalette.line),
            focusedBorder: border(MarketPalette.green, 1.5),
            errorBorder: border(MarketPalette.red),
            focusedErrorBorder: border(MarketPalette.red, 1.5),
            errorMaxLines: 2,
            errorStyle: MarketText.caption(color: MarketPalette.red, size: 12, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(MarketSize.button),
        backgroundColor: MarketPalette.green,
        // Yüklenirken buton yeşil kalır; yalnızca dönen gösterge değişir.
        disabledBackgroundColor: isLoading ? MarketPalette.green : null,
        disabledForegroundColor: isLoading ? Colors.white : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.md),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? Semantics(
              label: 'Bekleniyor',
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(color: Colors.white, size: 15, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(icon, color: Colors.white, size: 19),
              ],
            ),
    );
  }
}

/// Formun içindeki hata kutusu (giriş / kayıt başarısız). Ekran okuyucu
/// metni hemen duyurur; alanlar görünür kalır.
class AuthErrorNotice extends StatelessWidget {
  final String message;

  const AuthErrorNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MarketNotice(
        icon: Icons.error_outline_rounded,
        text: message,
        background: MarketPalette.redSoft,
        foreground: MarketPalette.red,
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MarketHeaderButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Geri',
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon numarası (kayıt formu ve Hesabım'daki düzenleme penceresi)
// ---------------------------------------------------------------------------

/// Yalnızca rakam kabul eder ve numarayı yazarken "0532 123 45 67" diye
/// gruplar. "+90 532…" yapıştırılırsa başına 0 koyar. En fazla 11 hane.
class TrPhoneInputFormatter extends TextInputFormatter {
  const TrPhoneInputFormatter();

  static String digitsOf(String text) {
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length >= 12) digits = '0${digits.substring(2)}';
    return digits.length > 11 ? digits.substring(0, 11) : digits;
  }

  /// "05321234567" → "0532 123 45 67"; "5321234567" → "532 123 45 67".
  static String group(String digits) {
    final groups = digits.startsWith('0') ? const [4, 3, 2, 2] : const [3, 3, 2, 2];
    final buffer = StringBuffer();
    var index = 0;
    for (final size in groups) {
      if (index >= digits.length) break;
      if (index > 0) buffer.write(' ');
      final end = (index + size).clamp(0, digits.length);
      buffer.write(digits.substring(index, end));
      index = end;
    }
    if (index < digits.length) buffer.write(digits.substring(index));
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsOf(newValue.text);
    final text = group(digits);
    // İmleç, kendinden önceki rakam sayısı korunarak yeni metne taşınır.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBefore = digitsOf(newValue.text.substring(0, cursor)).length;
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBefore) {
      if (text[offset] != ' ') seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Türkiye cep telefonu doğrulaması (05XX XXX XX XX ya da başında 0 olmadan).
/// Geçerliyse null döner.
String? validateTrMobile(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'Telefon numaranı yaz';
  if (!RegExp(r'^0?5\d{9}$').hasMatch(digits)) {
    return 'Numaran 05 ile başlamalı ve 11 haneli olmalı';
  }
  return null;
}
