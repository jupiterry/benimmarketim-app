import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'widgets/auth_ui.dart';
import 'widgets/market_ui.dart';

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
  bool _submitted = false;

  // Giriş başarısızsa formun içinde gösterilen hata (alanlar görünür kalır)
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });
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

    final message = auth.error?.trim();
    setState(() => _error = message == null || message.isEmpty
        ? 'E-posta ya da şifre hatalı. Kontrol edip tekrar dene.'
        : message);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      onBack: context.canPop() ? () => context.pop() : null,
      header: const AuthBrandHeader(
        title: 'Tekrar hoş geldin',
        subtitle: 'Siparişlerine, favorilerine ve sana özel fırsatlara kaldığın yerden devam et.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFormCard(
            child: Form(
              key: _formKey,
              autovalidateMode:
                  _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      controller: _emailController,
                      label: 'E-posta adresi',
                      hint: 'ornek@email.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: _clearError,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'E-posta adresini yaz';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                          return 'Geçerli bir e-posta adresi yaz (ör. ad@mail.com)';
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
                      onChanged: _clearError,
                      onSubmitted: _login,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Şifreni yaz';
                        if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      AuthErrorNotice(message: _error!),
                    ],
                    const SizedBox(height: 22),
                    Consumer<AuthViewModel>(
                      builder: (context, auth, _) => AuthPrimaryButton(
                        label: 'Giriş yap',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: auth.isLoading,
                        onPressed: _login,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Henüz hesabın yok mu?', style: MarketText.caption(size: 13)),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
                            textStyle: MarketText.label(size: 13, weight: FontWeight.w800),
                          ),
                          child: const Text('Kayıt ol'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.go('/home'),
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.greenDark,
              minimumSize: const Size.fromHeight(MarketSize.tapTarget),
            ),
            icon: const Icon(Icons.explore_outlined, size: 19),
            label: const Text('Giriş yapmadan ürünleri keşfet'),
          ),
        ],
      ),
    );
  }
}
