import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'widgets/auth_ui.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/market_palette.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthViewModel>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/home');
      }
      return;
    }

    CustomDialog.show(
      context: context,
      title: 'Giriş yapılamadı',
      message: auth.error ?? 'Bilgilerini kontrol edip tekrar deneyebilirsin.',
      confirmButtonText: 'Tekrar dene',
      showCancelButton: false,
      isDestructive: true,
      icon: Icons.error_outline_rounded,
      onConfirm: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      onBack: context.canPop() ? () => context.pop() : null,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                icon: Icons.storefront_rounded,
                title: 'Tekrar hoş geldin',
                subtitle:
                    'Siparişlerine, favorilerine ve sana özel deneyimine kaldığın yerden devam et.',
              ),
              const SizedBox(height: 30),
              AuthFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: MarketPalette.greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_open_rounded,
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
                                'Hesabına giriş yap',
                                style: GoogleFonts.manrope(
                                  color: MarketPalette.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Bilgilerin güvenli şekilde korunur.',
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
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Şifre',
                      hint: 'En az 6 karakter',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onToggleVisibility: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      onSubmitted: _login,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifrenizi girin';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Consumer<AuthViewModel>(
                      builder: (context, auth, _) => AuthPrimaryButton(
                        label: 'Giriş Yap',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: auth.isLoading,
                        onPressed: _login,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Henüz hesabın yok mu?',
                          style: GoogleFonts.inter(
                            color: MarketPalette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text(
                            'Kayıt ol',
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
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => context.go('/home'),
                style: TextButton.styleFrom(
                  foregroundColor: MarketPalette.greenDeep,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.explore_outlined, size: 19),
                label: Text(
                  'Giriş yapmadan ürünleri keşfet',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
