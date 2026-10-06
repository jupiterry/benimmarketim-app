import 'package:flutter/material.dart';

import 'market_ui.dart';

class AuthPageShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;

  const AuthPageShell({
    super.key,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: onBack == null
                              ? const SizedBox.shrink()
                              : AuthBackButton(onTap: onBack!),
                        ),
                      ),
                      const SizedBox(height: 14),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthBrandHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: MarketPalette.lime,
                borderRadius: BorderRadius.circular(MarketRadius.md),
              ),
              child: Icon(icon, color: MarketPalette.greenDeep, size: 26),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Benim Marketim',
                  style: MarketText.heading(color: Colors.white, size: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Devrek • Mahallenin marketi',
                  style: MarketText.caption(color: Colors.white.withValues(alpha: .74)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: MarketText.display(color: Colors.white),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          style: MarketText.body(color: Colors.white.withValues(alpha: .72), size: 13),
        ),
      ],
    );
  }
}

class AuthFormCard extends StatelessWidget {
  final Widget child;

  const AuthFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: MarketText.label(size: 12),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          style: MarketText.body(weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: MarketText.body(color: MarketPalette.subtle),
            prefixIcon: Icon(icon, color: MarketPalette.green, size: 21),
            suffixIcon: suffix ??
                (onToggleVisibility == null
                    ? null
                    : IconButton(
                        onPressed: onToggleVisibility,
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: MarketPalette.muted,
                          size: 20,
                        ),
                      )),
            filled: true,
            fillColor: MarketPalette.canvas,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
              borderSide: const BorderSide(color: MarketPalette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
              borderSide: const BorderSide(color: MarketPalette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
              borderSide: const BorderSide(
                color: MarketPalette.green,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
              borderSide: const BorderSide(color: MarketPalette.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MarketRadius.md),
              borderSide: const BorderSide(
                color: MarketPalette.red,
                width: 1.5,
              ),
            ),
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
        minimumSize: const Size.fromHeight(58),
        backgroundColor: MarketPalette.green,
        disabledBackgroundColor: MarketPalette.green.withValues(alpha: .55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.md),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: MarketText.label(color: Colors.white, size: 14, weight: FontWeight.w800),
                ),
                const SizedBox(width: 9),
                Icon(icon, color: Colors.white, size: 19),
              ],
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

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: MarketPalette.headerGradient,
            ),
          ),
        ),
        const Expanded(
          flex: 6,
          child: ColoredBox(color: MarketPalette.canvas),
        ),
      ],
    );
  }
}
