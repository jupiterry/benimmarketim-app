import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/meta_app_events_service.dart';
import '../services/review_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/account_actions.dart';
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
  bool _preferencesFailed = false;
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  final MetaAppEventsService _metaEvents = MetaAppEventsService.instance;
  bool? _metaConsentGranted; // Yüklenene kadar null
  bool _metaConsentSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreferences());
    _loadMetaConsent();
  }

  Future<void> _loadMetaConsent() async {
    if (!_metaEvents.isSupported) return;
    await _metaEvents.init();
    if (!mounted) return;
    setState(() => _metaConsentGranted =
        _metaEvents.consent == MetaTrackingConsent.granted);
  }

  Future<void> _setMetaConsent(bool granted) async {
    setState(() {
      _metaConsentGranted = granted;
      _metaConsentSaving = true;
    });
    final active = await _metaEvents.setConsent(granted);
    if (!mounted) return;
    setState(() {
      _metaConsentGranted =
          _metaEvents.consent == MetaTrackingConsent.granted;
      _metaConsentSaving = false;
    });
    if (granted && !active && _metaEvents.isIos) {
      await _explainIosTrackingOff();
    }
  }

  /// iOS'ta izleme izni sistem tarafından kapalıysa uygulama yeniden
  /// soramaz; kullanıcı iPhone Ayarlar'dan açabilir.
  Future<void> _explainIosTrackingOff() async {
    final status = await _metaEvents.trackingStatus();
    if (!mounted) return;
    final restricted = status == TrackingStatus.restricted;
    showMarketSnack(
      context,
      restricted
          ? 'Bu iPhone\'da uygulamaların izleme yapması kısıtlanmış.'
          : 'iPhone\'da izleme izni kapalı. Ayarlar > Benim Marketim > '
              '"İzlemeye İzin Ver" seçeneğini açabilirsin.',
      icon: Icons.info_outline_rounded,
      actionLabel: restricted ? null : 'Ayarlar',
      onAction: restricted ? null : () => _metaEvents.openTrackingSettings(),
    );
  }

  Future<void> _loadPreferences() async {
    if (!mounted || !context.read<AuthViewModel>().isLoggedIn) return;
    if (_preferencesFailed) setState(() => _preferencesFailed = false);
    final preferences = await _apiService.getNotificationPreferences();
    if (!mounted) return;
    setState(() {
      if (preferences == null) {
        // Yüklenemezse anahtarlar pasif kalır; üstte "Tekrar dene" çıkar
        _preferencesFailed = true;
      } else {
        _preferences = preferences;
        _preferencesLoaded = true;
      }
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    final previous = _preferences[key] ?? true;
    setState(() => _preferences = {..._preferences, key: value});
    final saved = await _apiService.updateNotificationPreferences({key: value});
    if (!mounted) return;
    if (saved == null) {
      setState(() => _preferences = {..._preferences, key: previous});
      showMarketSnack(context, 'Tercih kaydedilemedi. Tekrar dene.', error: true);
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
    return _SwitchTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: _preferences[keyName] ?? true,
      loading: !_preferencesLoaded && !_preferencesFailed,
      onChanged: _preferencesLoaded ? (value) => _setPreference(keyName, value) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthViewModel>().isLoggedIn;
    final gutter = MarketSpace.gutterOf(context);
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          MarketHeader(
            title: 'Ayarlar',
            subtitle: loggedIn
                ? 'Bildirim, gizlilik ve hesap tercihlerin'
                : 'Gizlilik tercihlerin ve yasal metinler',
            icon: Icons.settings_rounded,
            compact: true,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 32 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loggedIn) ...[
                  if (_preferencesFailed) ...[
                    MarketNotice.warning(
                      icon: Icons.wifi_off_rounded,
                      text: 'Bildirim tercihlerin yüklenemedi.',
                      trailing: TextButton(
                        onPressed: _loadPreferences,
                        style: TextButton.styleFrom(
                          foregroundColor: MarketPalette.orangeInk,
                          minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
                          textStyle: MarketText.label(size: 13),
                        ),
                        child: const Text('Tekrar dene'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                if (_metaEvents.isSupported) ...[
                  MarketMenuGroup(
                    title: 'Gizlilik',
                    children: [
                      _SwitchTile(
                        icon: Icons.insights_outlined,
                        title: 'Reklam ölçümü (Meta)',
                        subtitle:
                            'Açılış, sepete ekleme ve sipariş bilgilerini reklam ölçümü için Meta ile paylaş',
                        value: _metaConsentGranted ?? false,
                        loading: _metaConsentGranted == null,
                        onChanged: _metaConsentGranted == null || _metaConsentSaving
                            ? null
                            : _setMetaConsent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                MarketMenuGroup(
                  title: 'Yardım',
                  children: [
                    // Destek ve geri bildirim hesap ister; misafire gösterilmez
                    if (loggedIn) ...[
                      MarketMenuTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Yardım ve destek',
                        subtitle: 'Destek ekibine yaz',
                        onTap: () => context.push('/chat'),
                      ),
                      MarketMenuTile(
                        icon: Icons.rate_review_outlined,
                        title: 'Geri bildirim gönder',
                        subtitle: 'Görüş ve önerilerini bekliyoruz',
                        onTap: () => context.push('/feedback'),
                      ),
                    ],
                    MarketMenuTile(
                      icon: Icons.star_outline_rounded,
                      title: 'Uygulamayı değerlendir',
                      subtitle: ReviewService.isIos
                          ? "App Store'da puan ver, yorum yaz"
                          : "Google Play'de puan ver, yorum yaz",
                      // Uygulamadan çıkıp mağazayı açar (sayfa içi geçiş değil)
                      trailing: const Icon(Icons.open_in_new_rounded,
                          size: 18, color: MarketPalette.subtle),
                      onTap: () async {
                        final opened = await ReviewService.instance.openStoreListing();
                        if (!opened && context.mounted) {
                          showMarketSnack(context,
                              'Mağaza açılamadı. Lütfen daha sonra tekrar dene.',
                              error: true);
                        }
                      },
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
                if (loggedIn) ...[
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Çıkış yap'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MarketPalette.inkSoft,
                      backgroundColor: MarketPalette.surface,
                      side: const BorderSide(color: MarketPalette.lineStrong),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Geri alınamaz eylem diğerlerinden ayrı, en altta durur
                  MarketMenuGroup(
                    children: [
                      MarketMenuTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Hesabımı sil',
                        subtitle: 'Tüm verilerin kalıcı olarak silinir',
                        destructive: true,
                        onTap: () => confirmDeleteAccount(context),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FutureBuilder<PackageInfo>(
                  future: _info,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData ? 'Benim Marketim • Sürüm ${snapshot.data!.version}' : '',
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
}

/// Anahtarlı ayar satırı: satırın tamamı dokunulabilir, ekran okuyucu başlığı
/// ve anahtarın durumunu birlikte okur. Yüklenirken anahtar yerine iskelet
/// görünür.
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool loading;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              MarketIconTile(icon: icon, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MarketText.label(size: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: MarketText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const MarketSkeletonPulse(
                  semanticLabel: 'Tercih yükleniyor',
                  child: MarketSkeleton(width: 51, height: 31, radius: MarketRadius.pill),
                )
              else
                // Kaydedilemeyen / yüklenemeyen tercih soluk görünür
                Opacity(
                  opacity: enabled ? 1 : .45,
                  child: Switch.adaptive(value: value, onChanged: onChanged),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
