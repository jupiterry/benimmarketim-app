import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/app_logger.dart';
import '../services/image_url.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/delivery_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/account_actions.dart';
import 'widgets/auth_ui.dart';
import 'widgets/delivery_zones_info.dart';
import 'widgets/market_ui.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (auth.isLoggedIn && (user == null || user.name.isEmpty)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.updateProfile();
          });
        }

        return Scaffold(
          backgroundColor: MarketPalette.canvas,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (auth.isLoggedIn && user != null)
                _ProfileHeader(user: user)
              else if (auth.isLoggedIn)
                MarketHeader(
                  title: 'Hesabım',
                  subtitle: 'Bilgilerin yükleniyor…',
                  icon: Icons.person_rounded,
                  showBack: false,
                  actions: [_settingsButton(context)],
                )
              else
                MarketHeader(
                  title: 'Hesabım',
                  subtitle: 'Siparişlerini ve tercihlerini yönet',
                  icon: Icons.person_rounded,
                  showBack: false,
                  actions: [_settingsButton(context)],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: auth.isLoggedIn
                    ? _LoggedInContent(auth: auth)
                    : const _GuestContent(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Başlıktaki dişli: bildirim tercihleri, gizlilik ve yasal metinler.
Widget _settingsButton(BuildContext context) => MarketHeaderButton(
      icon: Icons.settings_outlined,
      tooltip: 'Ayarlar',
      onTap: () => context.push('/settings'),
    );

// ---------------------------------------------------------------------------
// Giriş yapılmış
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatefulWidget {
  final User user;

  const _ProfileHeader({required this.user});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _busy = false;

  static String _initialsOf(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.characters.first.toUpperCase())
      .join();

  Future<void> _showPhotoSheet() async {
    final hasAvatar = widget.user.avatar != null;
    final action = await showMarketSheet<String>(
      context,
      builder: (sheetContext) => MarketSheetScaffold(
        header: const MarketSheetHeader(title: 'Profil fotoğrafı'),
        body: MarketMenuGroup(
          children: [
            MarketMenuTile(
              icon: Icons.photo_camera_outlined,
              title: 'Fotoğraf çek',
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            MarketMenuTile(
              icon: Icons.photo_library_outlined,
              title: 'Galeriden seç',
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasAvatar)
              MarketMenuTile(
                icon: Icons.delete_outline_rounded,
                title: 'Fotoğrafı kaldır',
                destructive: true,
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removePhoto();
    } else {
      await _pickAndUpload(
        action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 80,
      );
    } catch (e) {
      AppLogger.debug('Fotoğraf seçilemedi: $e');
      if (mounted) {
        showMarketSnack(
          context,
          'Fotoğraf seçilemedi. Kamera/galeri iznini kontrol et.',
          error: true,
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          showMarketSnack(context, 'Fotoğraf en fazla 5 MB olabilir.',
              error: true);
        }
        return;
      }
      if (!mounted) return;
      final error = await context.read<AuthViewModel>().uploadProfilePhoto(bytes);
      if (!mounted) return;
      if (error == null) {
        showMarketSnack(context, 'Profil fotoğrafın güncellendi.');
      } else {
        showMarketSnack(context, error, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      final error = await context.read<AuthViewModel>().removeProfilePhoto();
      if (!mounted) return;
      if (error == null) {
        showMarketSnack(context, 'Profil fotoğrafın kaldırıldı.');
      } else {
        showMarketSnack(context, error, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = user.name.trim().isEmpty ? 'Kullanıcı' : user.name.trim();
    final initials = _initialsOf(name);
    final avatar = user.avatar;

    return MarketHeader(
      title: name,
      // Uzun adres satıra sığmazsa "@" işaretinden bölünür (harf ortasından değil)
      subtitle: user.email.replaceFirst('@', '\u200B@'),
      showBack: false,
      actions: [_settingsButton(context)],
      leading: Semantics(
        button: true,
        label: 'Profil fotoğrafını değiştir',
        child: GestureDetector(
          onTap: _busy ? null : _showPhotoSheet,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: MarketPalette.lime,
                    foregroundImage: avatar == null
                        ? null
                        : NetworkImage(
                            optimizedImageUrl(avatar, width: MarketImageSize.thumb),
                          ),
                    onForegroundImageError: avatar == null ? null : (_, __) {},
                    child: Text(
                      initials,
                      style: MarketText.title(color: MarketPalette.greenDeep, size: 22),
                    ),
                  ),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: MarketPalette.greenDeep,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: MarketPalette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: MarketPalette.line),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: MarketPalette.greenDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedInContent extends StatelessWidget {
  final AuthViewModel auth;

  const _LoggedInContent({required this.auth});

  @override
  Widget build(BuildContext context) {
    final favoriteCount =
        context.select<FavoritesViewModel, int>((f) => f.favoritesCount);
    final unreadCount =
        context.select<ChatViewModel, int>((c) => c.totalUnreadCount);
    final phone = (auth.user?.phone ?? '').trim();
    // Adreslerim yalnızca adrese teslimat bu kullanıcıya açıkken görünür
    final canOrderToAddress = context.select<DeliveryViewModel?, bool>(
        (d) => d?.canOrderToAddress ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Satırdaki kartlar en uzun etikete göre aynı boyda kalır
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Siparişlerim',
                  color: MarketPalette.greenDark,
                  background: MarketPalette.greenSoft,
                  onTap: () => context.push('/orders'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.favorite_rounded,
                  label: 'Favorilerim',
                  color: MarketPalette.pink,
                  background: MarketPalette.pinkSoft,
                  badgeCount: favoriteCount,
                  badgeLabel: '$favoriteCount ürün',
                  onTap: () => context.push('/favorites'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.support_agent_rounded,
                  label: 'Destek',
                  color: MarketPalette.blue,
                  background: MarketPalette.blueSoft,
                  badgeCount: unreadCount,
                  badgeLabel: '$unreadCount okunmamış mesaj',
                  onTap: () => context.push('/chat'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InviteBanner(onTap: () => context.push('/referral')),
        const SizedBox(height: 24),
        MarketMenuGroup(
          title: 'Alışveriş',
          children: [
            MarketMenuTile(
              icon: Icons.bookmarks_outlined,
              title: 'Favori sepetlerim',
              subtitle: 'Kaydettiğin listeleri tek dokunuşla sepete ekle',
              onTap: () => context.push('/saved-carts'),
            ),
            MarketMenuTile(
              icon: Icons.print_outlined,
              title: 'Fotokopi hizmeti',
              subtitle: 'Belge yükle, isteklerini takip et',
              iconColor: MarketPalette.blue,
              iconBackground: MarketPalette.blueSoft,
              onTap: () => context.push('/photocopy-upload'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        MarketMenuGroup(
          title: 'Hesap',
          children: [
            if (canOrderToAddress)
              MarketMenuTile(
                icon: Icons.location_on_outlined,
                title: 'Adreslerim',
                subtitle: 'Teslimat adreslerini yönet',
                onTap: () => context.push('/addresses'),
              ),
            MarketMenuTile(
              icon: Icons.phone_outlined,
              title: 'Telefon numarası',
              subtitle: phone.isEmpty ? 'Siparişlerin için numaranı ekle' : formatPhoneTr(phone),
              onTap: () => _editPhone(context),
            ),
            MarketMenuTile(
              icon: Icons.settings_outlined,
              title: 'Ayarlar',
              subtitle: 'Bildirimler, gizlilik ve yasal metinler',
              onTap: () => context.push('/settings'),
            ),
            MarketMenuTile(
              icon: Icons.rate_review_outlined,
              title: 'Geri bildirim gönder',
              subtitle: 'Görüş ve önerilerini bekliyoruz',
              onTap: () => context.push('/feedback'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _StoreInfoGroup(),
        const SizedBox(height: 24),
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
        const SizedBox(height: 20),
        const _VersionFooter(),
      ],
    );
  }

  Future<void> _editPhone(BuildContext context) async {
    // Kayıtta başında 0 olmadan yazılmış numaralar da (5XX…) düzenlenebilsin
    var digits = (auth.user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('5')) digits = '0$digits';
    final controller = TextEditingController(text: TrPhoneInputFormatter.group(digits));
    String? validationError;
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void save() {
            final error = validateTrMobile(controller.text);
            if (error != null) {
              setDialogState(() => validationError = error);
              return;
            }
            final value = controller.text.replaceAll(RegExp(r'\D'), '');
            Navigator.pop(dialogContext, value.startsWith('0') ? value : '0$value');
          }

          return AlertDialog(
            title: const Text('Telefon numarası'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: const [TrPhoneInputFormatter()],
              style: MarketText.body(size: 16, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '05XX XXX XX XX',
                prefixIcon: const Icon(Icons.phone_outlined, color: MarketPalette.green, size: 21),
                errorText: validationError,
                errorMaxLines: 2,
                fillColor: MarketPalette.canvas,
              ),
              onChanged: (_) {
                if (validationError != null) {
                  setDialogState(() => validationError = null);
                }
              },
              onSubmitted: (_) => save(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: save,
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
    // Diyalog kapanış animasyonu bitince kontrolcü serbest bırakılır
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (phone == null || !context.mounted) return;
    final error = await auth.updatePhone(phone);
    if (!context.mounted) return;
    if (error == null) {
      showMarketSnack(context, 'Telefon numaran güncellendi.');
    } else {
      showMarketSnack(context, error, error: true);
    }
  }
}

/// Hesabım'daki üç kısayol. Sayı varsa simgenin köşesinde rozet çıkar.
class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final int badgeCount;

  /// Rozetin ekran okuyucudaki karşılığı ("12 ürün").
  final String? badgeLabel;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    return Semantics(
      button: true,
      label: hasBadge && badgeLabel != null ? '$label, $badgeLabel' : label,
      excludeSemantics: true,
      child: MarketCard(
        shadow: false,
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        radius: MarketRadius.lg,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MarketIconTile(icon: icon, size: 42, background: background, foreground: color),
                if (hasBadge)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: MarketCountBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: MarketText.label(size: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _InviteBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MarketPalette.greenDark, MarketPalette.green],
            ),
            borderRadius: BorderRadius.circular(MarketRadius.lg),
          ),
          child: Row(
            children: [
              const MarketIconTile(
                icon: Icons.card_giftcard_rounded,
                size: 46,
                background: MarketPalette.lime,
                foreground: MarketPalette.greenDeep,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arkadaşını getir, birlikte kazanın',
                      style: MarketText.heading(color: Colors.white, size: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Davet kodunu paylaş, ilk siparişte indirim kazan.',
                      style: MarketText.caption(color: Colors.white.withValues(alpha: .8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Giriş yapılmamış
// ---------------------------------------------------------------------------

class _GuestContent extends StatelessWidget {
  const _GuestContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hesabına giriş yap', style: MarketText.title(size: 22)),
              const SizedBox(height: 6),
              Text(
                'Giriş yaparak alışverişini kolaylaştır:',
                style: MarketText.body(color: MarketPalette.muted, size: 14),
              ),
              const SizedBox(height: 14),
              const _Benefit(
                icon: Icons.local_shipping_outlined,
                text: 'Siparişlerini anlık takip et',
              ),
              const _Benefit(
                icon: Icons.favorite_border_rounded,
                text: 'Favori ürünlerini kaydet',
              ),
              const _Benefit(
                icon: Icons.local_activity_outlined,
                text: 'Sana özel kupon ve fırsatlar kazan',
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Giriş yap'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.push('/register'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Yeni hesap oluştur'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        MarketMenuGroup(
          title: 'Uygulama',
          children: [
            MarketMenuTile(
              icon: Icons.settings_outlined,
              title: 'Ayarlar',
              subtitle: 'Gizlilik tercihleri ve yasal metinler',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _StoreInfoGroup(),
        const SizedBox(height: 22),
        const _VersionFooter(),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Benefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          MarketIconTile(icon: icon, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: MarketText.label(size: 14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak
// ---------------------------------------------------------------------------

class _StoreInfoGroup extends StatefulWidget {
  const _StoreInfoGroup();

  @override
  State<_StoreInfoGroup> createState() => _StoreInfoGroupState();
}

class _StoreInfoGroupState extends State<_StoreInfoGroup> {
  @override
  void initState() {
    super.initState();
    // Bölge listesi giriş gerektirmez; misafir de görür.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeliveryViewModel?>()?.loadZones();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    String hhmm(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    // 00:00 – 00:00, yönetim panelinde 24 saat açık demektir (ana sayfadaki
    // "7/24 açık" ile aynı kural).
    final allDay = settings.orderStartHour == 0 &&
        settings.orderStartMinute == 0 &&
        settings.orderEndHour == 0 &&
        settings.orderEndMinute == 0;
    final opensAt = hhmm(settings.orderStartHour, settings.orderStartMinute);
    final hours = '$opensAt – ${hhmm(settings.orderEndHour, settings.orderEndMinute)}';
    final open = settings.isWithinOrderHours;

    final String hoursText;
    final Widget status;
    if (allDay) {
      hoursText = 'Günün her saati sipariş verebilirsin';
      status = const MarketPill(label: '7/24 açık');
    } else if (open) {
      hoursText = 'Her gün $hours';
      status = const MarketPill(label: 'Açık');
    } else {
      hoursText = 'Açılış $opensAt • Her gün $hours';
      status = const MarketPill(
        label: 'Kapalı',
        background: MarketPalette.redSoft,
        foreground: MarketPalette.red,
      );
    }

    return MarketMenuGroup(
      title: 'Mağaza bilgileri',
      children: [
        MarketMenuTile(
          icon: Icons.schedule_rounded,
          title: 'Sipariş saatleri',
          subtitle: hoursText,
          trailing: status,
        ),
        MarketMenuTile(
          icon: Icons.shopping_basket_outlined,
          title: 'Minimum sepet tutarı',
          trailing: Text(
            formatTlShort(settings.minimumOrderAmount),
            style: MarketText.label(size: 14),
          ),
        ),
        ..._deliveryTiles(context, settings),
      ],
    );
  }

  /// Teslimat bölgeleri (`GET /delivery/zones`): az bölge varsa tek tek,
  /// çoksa özet + "Tüm teslimat bölgeleri" alt sayfası. Liste alınamazsa
  /// ayarlardaki yurt adlarına düşülür.
  List<Widget> _deliveryTiles(BuildContext context, SettingsViewModel settings) {
    final delivery = context.watch<DeliveryViewModel?>();
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);
    final dormNames = [
      if (settings.girlsDormEnabled) settings.girlsDormName,
      if (settings.boysDormEnabled) settings.boysDormName,
    ];
    Widget dormFallback({Widget? trailing}) => MarketMenuTile(
          icon: Icons.location_on_outlined,
          title: 'Teslimat noktaları',
          subtitle: dormNames.isEmpty
              ? 'Teslimat bölgeleri yüklenemedi'
              : dormNames.join(' • '),
          trailing: trailing,
        );

    if (delivery == null) return [dormFallback()];

    if (!delivery.zonesLoaded) {
      if (delivery.zonesError != null && !delivery.zonesLoading) {
        return [
          dormFallback(
            trailing: IconButton(
              onPressed: () => delivery.loadZones(force: true),
              tooltip: 'Teslimat bölgelerini yeniden yükle',
              color: MarketPalette.greenDark,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ];
      }
      return const [
        MarketMenuTile(
          icon: Icons.location_on_outlined,
          title: 'Teslimat bölgeleri',
          subtitle: 'Yükleniyor…',
          trailing: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: MarketPalette.green),
          ),
        ),
      ];
    }

    // Adrese teslimat bu kullanıcıya kapalıysa yalnızca yurtlar gösterilir
    // (sipariş verebileceği yerler). Misafir tüm açık bölgeleri görür.
    final zones = loggedIn && !delivery.canOrderToAddress
        ? delivery.zones.where((z) => z.isDorm).toList()
        : delivery.zones;
    final campaign = delivery.freeDeliveryEverywhere;

    if (zones.isEmpty) {
      return const [
        MarketMenuTile(
          icon: Icons.location_off_outlined,
          title: 'Teslimat bölgeleri',
          subtitle: 'Şu an teslimat yapılmıyor',
        ),
      ];
    }

    final onlyDorms = zones.every((z) => z.isDorm);
    final title = onlyDorms ? 'Teslimat noktaları' : 'Teslimat bölgeleri';

    if (zones.length <= deliveryZonesInlineLimit) {
      return [
        MarketMenuTile(
          icon: Icons.location_on_outlined,
          title: title,
          subtitle: campaign
              ? freeDeliveryCampaignNote
              : 'Teslimat ücreti ve tahmini süre',
        ),
        for (final zone in zones) DeliveryZoneTile(zone: zone, campaign: campaign),
      ];
    }

    return [
      MarketMenuTile(
        icon: Icons.location_on_outlined,
        title: title,
        subtitle: [
          zoneCountsSummary(zones),
          campaign ? freeDeliveryCampaignNote : zoneFeeRangeSummary(zones),
        ].join('\n'),
      ),
      MarketMenuTile(
        icon: Icons.map_outlined,
        title: 'Tüm teslimat bölgeleri',
        subtitle: 'Ücret ve tahmini süreleri gör',
        onTap: () =>
            showDeliveryZonesSheet(context, zones: zones, campaign: campaign),
      ),
    ];
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(
          version == null ? 'Benim Marketim' : 'Benim Marketim • Sürüm $version',
          textAlign: TextAlign.center,
          style: MarketText.caption(),
        );
      },
    );
  }
}
