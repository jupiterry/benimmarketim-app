import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/referral_viewmodel.dart';
import 'widgets/auth_ui.dart';
import 'widgets/market_palette.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _debounceTimer;
  bool? _isReferralCodeValid;
  String? _referralMessage;
  bool _isCheckingReferralCode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _checkReferralCode(String code) {
    _debounceTimer?.cancel();
    final normalizedCode = code.trim();

    if (normalizedCode.isEmpty) {
      setState(() {
        _isReferralCodeValid = null;
        _referralMessage = null;
        _isCheckingReferralCode = false;
      });
      return;
    }

    setState(() => _isCheckingReferralCode = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final result = await context
          .read<ReferralViewModel>()
          .checkReferralCode(normalizedCode);
      if (!mounted) return;
      setState(() {
        _isReferralCodeValid = result.isValid;
        _referralMessage = result.message;
        _isCheckingReferralCode = false;
      });
    });
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthViewModel>();
    final referralCode = _referralCodeController.text.trim();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _phoneController.text.replaceAll(' ', ''),
      referralCode: referralCode.isEmpty ? null : referralCode,
    );

    if (!mounted) return;
    if (success) {
      context.go('/home');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE9E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: MarketPalette.red,
          ),
        ),
        title: Text(
          'Kayıt tamamlanamadı',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: MarketPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          auth.error ?? 'Bilgilerini kontrol edip tekrar deneyebilirsin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: MarketPalette.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: MarketPalette.green,
            ),
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  void _openLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      onBack: _openLogin,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Aramıza katıl',
                subtitle:
                    'Siparişlerini kolayca takip et, favorilerini sakla ve alışverişini hızlandır.',
              ),
              const SizedBox(height: 30),
              AuthFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormIntro(
                      title: 'Hesabını oluştur',
                      subtitle: 'Birkaç bilgiyle hemen başlayabilirsin.',
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _nameController,
                      label: 'Ad soyad',
                      hint: 'Adınız ve soyadınız',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) {
                        final words = (value ?? '')
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((word) => word.isNotEmpty)
                            .toList();
                        if (words.length < 2 ||
                            words.any((word) => word.length < 2)) {
                          return 'Adınızı ve soyadınızı eksiksiz girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),
                    AuthTextField(
                      controller: _emailController,
                      label: 'E-posta adresi',
                      hint: 'ornek@email.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'E-posta adresini girin';
                        if (!RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)) {
                          return 'Geçerli bir e-posta adresi girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Telefon numarası',
                      hint: '5XX XXX XX XX',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      validator: (value) {
                        final phone = (value ?? '').replaceAll(' ', '');
                        if (phone.isEmpty) {
                          return 'Telefon numaranızı girin';
                        }
                        if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
                          return 'Telefon numarası yalnızca rakam içermeli';
                        }
                        if (phone.length < 10 || phone.length > 15) {
                          return 'Telefon numarası 10-15 haneli olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Şifre',
                      hint: 'En az 6 karakter',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      onToggleVisibility: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifrenizi belirleyin';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        if (value.length > 50) {
                          return 'Şifre en fazla 50 karakter olabilir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 17),
                    AuthTextField(
                      controller: _confirmPasswordController,
                      label: 'Şifre tekrarı',
                      hint: 'Şifrenizi yeniden girin',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onToggleVisibility: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifrenizi tekrar girin';
                        }
                        if (value != _passwordController.text) {
                          return 'Şifreler birbiriyle eşleşmiyor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    _buildReferralField(),
                    const SizedBox(height: 25),
                    Consumer<AuthViewModel>(
                      builder: (context, auth, _) => AuthPrimaryButton(
                        label: 'Hesabımı Oluştur',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: auth.isLoading,
                        onPressed: _register,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zaten hesabın var mı?',
                          style: GoogleFonts.inter(
                            color: MarketPalette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: _openLogin,
                          child: Text(
                            'Giriş yap',
                            style: GoogleFonts.inter(
                              color: MarketPalette.greenDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralField() {
    final validationColor = _isReferralCodeValid == true
        ? MarketPalette.green
        : _isReferralCodeValid == false
            ? MarketPalette.red
            : MarketPalette.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Davet kodu',
              style: GoogleFonts.inter(
                color: MarketPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF0FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'İsteğe bağlı',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4C6FFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AuthTextField(
          controller: _referralCodeController,
          label: 'Kod',
          hint: 'Varsa davet kodunu gir',
          icon: Icons.card_giftcard_rounded,
          showLabel: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: _checkReferralCode,
          suffix: _referralSuffix(validationColor),
        ),
        if (_referralMessage?.isNotEmpty == true) ...[
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: validationColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isReferralCodeValid == true
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: validationColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _referralMessage!,
                    style: GoogleFonts.inter(
                      color: validationColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _referralSuffix(Color color) {
    if (_isCheckingReferralCode) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF4C6FFF),
          ),
        ),
      );
    }
    if (_isReferralCodeValid == null) return null;
    return Icon(
      _isReferralCodeValid! ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: color,
    );
  }
}

class _FormIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FormIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MarketPalette.greenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_add_alt_rounded,
            color: MarketPalette.greenDark,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: MarketPalette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
