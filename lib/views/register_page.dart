import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/referral_viewmodel.dart';
import 'widgets/auth_ui.dart';
import 'widgets/legal_links.dart';
import 'widgets/market_ui.dart';

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

  // Gönderimde ilk hatalı alana kaydırıp odaklanmak için
  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _confirmKey = GlobalKey();
  final _consentKey = GlobalKey();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _referralFocus = FocusNode();

  // Onay metnindeki yasal metin bağlantıları
  late final TapGestureRecognizer _termsLink = TapGestureRecognizer()
    ..onTap = () => LegalLinks.open(context, LegalLinks.terms);
  late final TapGestureRecognizer _kvkkLink = TapGestureRecognizer()
    ..onTap = () => LegalLinks.open(context, LegalLinks.kvkk);
  late final TapGestureRecognizer _privacyLink = TapGestureRecognizer()
    ..onTap = () => LegalLinks.open(context, LegalLinks.privacy);

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _debounceTimer;
  bool? _isReferralCodeValid;
  String? _referralMessage;
  bool _isCheckingReferralCode = false;
  bool _showReferralField = false;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _submitted = false;

  // Kayıt başarısızsa formun içinde gösterilen hata
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _referralFocus.dispose();
    _termsLink.dispose();
    _kvkkLink.dispose();
    _privacyLink.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _clearError([String _ = '']) {
    if (_error != null) setState(() => _error = null);
  }

  void _checkReferralCode(String code) {
    _clearError();
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

  static String? _validateName(String? value) {
    final words = (value ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length < 2 || words.any((word) => word.length < 2)) {
      return 'Adını ve soyadını eksiksiz yaz';
    }
    return null;
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresini yaz';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi yaz (ör. ad@mail.com)';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Bir şifre belirle';
    if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
    if (value.length > 50) return 'Şifre en fazla 50 karakter olabilir';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Şifreni tekrar yaz';
    if (value != _passwordController.text) return 'Şifreler aynı değil';
    return null;
  }

  /// İlk hatalı alanı (ya da onay kutusunu) görünür yapar ve odaklar; uzun
  /// formda hata ekran dışında kalmaz.
  void _revealFirstProblem() {
    final checks = <(GlobalKey, FocusNode?, bool)>[
      (_nameKey, _nameFocus, _validateName(_nameController.text) != null),
      (_emailKey, _emailFocus, _validateEmail(_emailController.text) != null),
      (_phoneKey, _phoneFocus, validateTrMobile(_phoneController.text) != null),
      (_passwordKey, _passwordFocus, _validatePassword(_passwordController.text) != null),
      (_confirmKey, _confirmFocus, _validateConfirm(_confirmPasswordController.text) != null),
      (_consentKey, null, !_acceptedTerms),
    ];
    for (final (key, focus, invalid) in checks) {
      if (!invalid) continue;
      final target = key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .15,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      focus?.requestFocus();
      return;
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!_acceptedTerms) setState(() => _showTermsError = true);
    if (!formValid || !_acceptedTerms) {
      _revealFirstProblem();
      return;
    }

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

    final message = auth.error?.trim();
    setState(() => _error = message == null || message.isEmpty
        ? 'Kayıt tamamlanamadı. Bilgilerini kontrol edip tekrar dene.'
        : message);
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
      header: const AuthBrandHeader(title: 'Aramıza katıl', compact: true),
      child: AuthFormCard(
        child: Form(
          key: _formKey,
          autovalidateMode:
              _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  key: _nameKey,
                  controller: _nameController,
                  focusNode: _nameFocus,
                  label: 'Ad soyad',
                  hint: 'Adın ve soyadın',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  onChanged: _clearError,
                  validator: _validateName,
                ),
                const SizedBox(height: 17),
                AuthTextField(
                  key: _emailKey,
                  controller: _emailController,
                  focusNode: _emailFocus,
                  label: 'E-posta adresi',
                  hint: 'ornek@email.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onChanged: _clearError,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 17),
                AuthTextField(
                  key: _phoneKey,
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  label: 'Cep telefonu',
                  hint: '05XX XXX XX XX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: const [TrPhoneInputFormatter()],
                  onChanged: _clearError,
                  validator: validateTrMobile,
                ),
                const SizedBox(height: 17),
                AuthTextField(
                  key: _passwordKey,
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  label: 'Şifre',
                  hint: 'En az 6 karakter',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onToggleVisibility: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  onChanged: _clearError,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 17),
                AuthTextField(
                  key: _confirmKey,
                  controller: _confirmPasswordController,
                  focusNode: _confirmFocus,
                  label: 'Şifre tekrarı',
                  hint: 'Şifreni tekrar yaz',
                  icon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onToggleVisibility: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  onChanged: _clearError,
                  validator: _validateConfirm,
                ),
                const SizedBox(height: 14),
                if (_showReferralField || _referralCodeController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildReferralField(),
                  const SizedBox(height: 14),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _showReferralField = true);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _referralFocus.requestFocus(),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: MarketPalette.greenDark,
                        minimumSize: const Size(0, MarketSize.tapTarget),
                        padding: const EdgeInsets.fromLTRB(2, 0, 8, 0),
                        textStyle: MarketText.label(size: 13),
                      ),
                      icon: const Icon(Icons.card_giftcard_rounded, size: 19),
                      label: const Text('Davet kodun var mı?'),
                    ),
                  ),
                _buildConsent(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AuthErrorNotice(message: _error!),
                ],
                const SizedBox(height: 20),
                Consumer<AuthViewModel>(
                  builder: (context, auth, _) => AuthPrimaryButton(
                    label: 'Hesabımı oluştur',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: auth.isLoading,
                    onPressed: _register,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Zaten hesabın var mı?', style: MarketText.caption(size: 13)),
                    TextButton(
                      onPressed: _openLogin,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
                        textStyle: MarketText.label(size: 13, weight: FontWeight.w800),
                      ),
                      child: const Text('Giriş yap'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsent() {
    void toggle() => setState(() {
          _acceptedTerms = !_acceptedTerms;
          if (_acceptedTerms) _showTermsError = false;
        });

    final base = MarketText.body(size: 13, height: 1.45, color: MarketPalette.inkSoft);
    final link = MarketText.body(
      size: 13,
      height: 1.45,
      color: MarketPalette.greenDark,
      weight: FontWeight.w700,
    ).copyWith(decoration: TextDecoration.underline, decorationColor: MarketPalette.greenDark);

    return Column(
      key: _consentKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kutunun kendisi 48 × 48 dokunma alanı
            SizedBox(
              width: MarketSize.tapTarget,
              height: MarketSize.tapTarget,
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (_) => toggle(),
                semanticLabel: 'Kullanım koşullarını ve KVKK aydınlatma metnini onaylıyorum',
                isError: _showTermsError && !_acceptedTerms,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                // Bağlantı dışındaki metne dokunmak kutuyu işaretler
                onTap: toggle,
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      style: base,
                      children: [
                        TextSpan(text: 'Kullanım Koşulları', style: link, recognizer: _termsLink),
                        const TextSpan(text: "'nı kabul ediyorum; "),
                        TextSpan(text: 'KVKK Aydınlatma Metni', style: link, recognizer: _kvkkLink),
                        const TextSpan(text: "'ni ve "),
                        TextSpan(text: 'Gizlilik Politikası', style: link, recognizer: _privacyLink),
                        const TextSpan(text: "'nı okudum."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showTermsError && !_acceptedTerms)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Text(
              'Hesap oluşturmak için onay kutusunu işaretle',
              style: MarketText.caption(
                color: MarketPalette.red,
                weight: FontWeight.w600,
              ),
            ),
          ),
      ],
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
            Text('Davet kodu', style: MarketText.label(size: 13)),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: MarketPalette.blueSoft,
                borderRadius: BorderRadius.circular(MarketRadius.xs),
              ),
              child: Text(
                'İsteğe bağlı',
                style: MarketText.label(color: MarketPalette.blue, size: 11),
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
          focusNode: _referralFocus,
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
              borderRadius: BorderRadius.circular(MarketRadius.sm),
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
                    style: MarketText.label(color: validationColor, size: 12),
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
            color: MarketPalette.blue,
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
