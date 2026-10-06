import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/review_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/legal_links.dart';
import 'widgets/market_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _apiService = ApiService();
  // Sunucudan gelene kadar varsayılan: hepsi açık
  Map<String, bool> _preferences = {
    'orders': true,
    'messages': true,
    'campaigns': true,
  };
  bool _preferencesLoaded = false;
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreferences());
  }

  Future<void> _loadPreferences() async {
    if (!mounted || !context.read<AuthViewModel>().isLoggedIn) return;
    final preferences = await _apiService.getNotificationPreferences();
    if (!mounted || preferences == null) return;
    setState(() {
      _preferences = preferences;
      _preferencesLoaded = true;
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    final previous = _preferences[key] ?? true;
    setState(() => _preferences = {..._preferences, key: value});
    final saved = await _apiService.updateNotificationPreferences({key: value});
    if (!mounted) return;
    if (saved == null) {
      setState(() => _preferences = {..._preferences, key: previous});
      showMarketSnack(context, 'Tercih kaydedilemedi. Lütfen tekrar dene.',
          error: true);
    } else {
      setState(() => _preferences = saved);
    }
  }

  Widget _preferenceTile({
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return MarketMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: _preferences[keyName] ?? true,
        onChanged: _preferencesLoaded
            ? (value) => _setPreference(keyName, value)
            : null,
      ),
    );
  }

  Widget _soon() => const MarketPill(label: 'Yakında');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const MarketHeader(
            title: 'Ayarlar',
            subtitle: 'Uygulama ve hesap tercihlerin',
            icon: Icons.settings_rounded,
            compact: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (context.watch<AuthViewModel>().isLoggedIn) ...[
                  MarketMenuGroup(
                    title: 'Bildirimler',
                    children: [
                      _preferenceTile(
                        keyName: 'orders',
                        icon: Icons.local_shipping_outlined,
                        title: 'Sipariş bildirimleri',
                        subtitle: 'Hazırlanıyor, yolda ve teslim edildi',
                      ),
                      _preferenceTile(
                        keyName: 'messages',
                        icon: Icons.support_agent_rounded,
                        title: 'Destek mesajları',
                        subtitle: 'Destek ekibi yanıt yazdığında',
                      ),
                      _preferenceTile(
                        keyName: 'campaigns',
                        icon: Icons.local_offer_outlined,
                        title: 'Kampanya ve hatırlatmalar',
                        subtitle: 'Fırsatlar, kuponlar ve sepet hatırlatması',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                MarketMenuGroup(
                  title: 'Uygulama',
                  children: [
                    MarketMenuTile(
                      icon: Icons.language_rounded,
                      title: 'Dil',
                      trailing: Text('Türkçe', style: MarketText.label(color: MarketPalette.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                MarketMenuGroup(
                  title: 'Hesap',
                  children: [
                    MarketMenuTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Şifre değiştir',
                      trailing: _soon(),
                    ),
                    MarketMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Adreslerim',
                      trailing: _soon(),
                    ),
                    MarketMenuTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Hesabımı sil',
                      destructive: true,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                MarketMenuGroup(
                  title: 'Diğer',
                  children: [
                    MarketMenuTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Yardım ve destek',
                      onTap: () => context.push('/chat'),
                    ),
                    MarketMenuTile(
                      icon: Icons.rate_review_outlined,
                      title: 'Geri bildirim gönder',
                      onTap: () => context.push('/feedback'),
                    ),
                    MarketMenuTile(
                      icon: Icons.star_outline_rounded,
                      title: 'Uygulamayı değerlendir',
                      subtitle: 'Mağazada puan ver, yorum yaz',
                      onTap: () => ReviewService.instance.openStoreListing(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                MarketMenuGroup(
                  title: 'Yasal',
                  children: [
                    MarketMenuTile(
                      icon: Icons.shield_outlined,
                      title: 'KVKK Aydınlatma Metni',
                      onTap: () => LegalLinks.open(context, LegalLinks.kvkk),
                    ),
                    MarketMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Gizlilik Politikası',
                      onTap: () => LegalLinks.open(context, LegalLinks.privacy),
                    ),
                    MarketMenuTile(
                      icon: Icons.description_outlined,
                      title: 'Kullanım Koşulları',
                      onTap: () => LegalLinks.open(context, LegalLinks.terms),
                    ),
                    MarketMenuTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Mesafeli Satış Sözleşmesi',
                      onTap: () =>
                          LegalLinks.open(context, LegalLinks.distanceSales),
                    ),
                    MarketMenuTile(
                      icon: Icons.assignment_return_outlined,
                      title: 'İade Politikası',
                      onTap: () =>
                          LegalLinks.open(context, LegalLinks.returnPolicy),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Consumer<AuthViewModel>(
                  builder: (context, authViewModel, child) {
                    if (!authViewModel.isLoggedIn) return const SizedBox.shrink();
                    return OutlinedButton.icon(
                      onPressed: () async {
                        await authViewModel.logout();
                        if (context.mounted) context.pop();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Çıkış yap'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MarketPalette.red,
                        side: const BorderSide(color: MarketPalette.redLine),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FutureBuilder<PackageInfo>(
                  future: _info,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData ? 'Sürüm ${snapshot.data!.version}' : '',
                    textAlign: TextAlign.center,
                    style: MarketText.caption(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.warning_amber_rounded,
          size: 52,
          background: MarketPalette.redSoft,
          foreground: MarketPalette.red,
        ),
        title: const Text('Hesabını silmek istiyor musun?', textAlign: TextAlign.center),
        content: const Text(
          'Hesabını sildiğinde tüm verilerin kalıcı olarak silinir. Bu işlem geri alınamaz.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MarketPalette.red),
            onPressed: () async {
              // Dialogu kapat
              dialogContext.pop();

              // Loading göster
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: MarketPalette.red),
                ),
              );

              final authViewModel = context.read<AuthViewModel>();
              final success = await authViewModel.deleteAccount();

              // Loading kapat
              if (context.mounted) {
                context.pop();
              }

              if (success && context.mounted) {
                showMarketSnack(context, 'Hesabın silindi.');
                context.go('/');
              } else if (context.mounted) {
                showMarketSnack(
                  context,
                  authViewModel.error ?? 'Hesap silinirken bir hata oluştu.',
                  error: true,
                );
              }
            },
            child: const Text('Hesabımı sil'),
          ),
        ],
      ),
    );
  }
}
