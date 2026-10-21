import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/app_logger.dart';
import '../services/image_url.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/favorites_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/custom_dialog.dart';
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
                const MarketHeader(
                  title: 'Hesabım',
                  subtitle: 'Bilgilerin yükleniyor…',
                  icon: Icons.person_rounded,
                  showBack: false,
                )
              else
                const MarketHeader(
                  title: 'Hesabım',
                  subtitle: 'Siparişlerini ve tercihlerini yönet',
                  icon: Icons.person_rounded,
                  showBack: false,
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
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MarketPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              MarketSpace.xl, MarketSpace.lg, MarketSpace.xl, MarketSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Profil fotoğrafı', style: MarketText.heading(size: 17)),
              const SizedBox(height: MarketSpace.sm),
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
          aboveNavigation: true,
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
              error: true, aboveNavigation: true);
        }
        return;
      }
      if (!mounted) return;
      final error = await context.read<AuthViewModel>().uploadProfilePhoto(bytes);
      if (!mounted) return;
      if (error == null) {
        showMarketSnack(context, 'Profil fotoğrafın güncellendi.',
            aboveNavigation: true);
      } else {
        showMarketSnack(context, error, error: true, aboveNavigation: true);
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
        showMarketSnack(context, 'Profil fotoğrafın kaldırıldı.',
            aboveNavigation: true);
      } else {
        showMarketSnack(context, error, error: true, aboveNavigation: true);
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
      subtitle: user.email,
      showBack: false,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                label: favoriteCount > 0 ? 'Favoriler ($favoriteCount)' : 'Favoriler',
                color: MarketPalette.pink,
                background: MarketPalette.pinkSoft,
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
                onTap: () => context.push('/chat'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InviteBanner(onTap: () => context.push('/referral')),
        const SizedBox(height: 24),
        MarketMenuGroup(
          title: 'Hesap bilgileri',
          children: [
            MarketMenuTile(
              icon: Icons.phone_outlined,
              title: 'Telefon numarası',
              subtitle: (auth.user?.phone ?? '').trim().isEmpty
                  ? 'Siparişlerin için numaranı ekle'
                  : auth.user!.phone!.trim(),
              onTap: () => _editPhone(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        MarketMenuGroup(
          title: 'Hizmetler',
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
              subtitle: 'Belgeni yükle, siparişinle gelsin',
              iconColor: MarketPalette.blue,
              iconBackground: MarketPalette.blueSoft,
              onTap: () => context.push('/photocopy-upload'),
            ),
            MarketMenuTile(
              icon: Icons.history_rounded,
              title: 'Fotokopi geçmişi',
              iconColor: MarketPalette.blue,
              iconBackground: MarketPalette.blueSoft,
              onTap: () => context.push('/photocopy-history'),
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
        MarketMenuGroup(
          title: 'Hesap',
          children: [
            MarketMenuTile(
              icon: Icons.logout_rounded,
              title: 'Çıkış yap',
              iconColor: MarketPalette.inkSoft,
              iconBackground: MarketPalette.surfaceMuted,
              onTap: () => _confirmLogout(context),
            ),
            MarketMenuTile(
              icon: Icons.delete_outline_rounded,
              title: 'Hesabımı sil',
              subtitle: 'Tüm verilerin kalıcı olarak silinir',
              destructive: true,
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _VersionFooter(),
      ],
    );
  }

  static final RegExp _phonePattern = RegExp(r'^05\d{9}$');

  Future<void> _editPhone(BuildContext context) async {
    final controller = TextEditingController(
      text: (auth.user?.phone ?? '').replaceAll(RegExp(r'\D'), ''),
    );
    String? validationError;
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Telefon numarası'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            style: MarketText.body(size: 15),
            decoration: InputDecoration(
              hintText: '05XXXXXXXXX',
              counterText: '',
              errorText: validationError,
              fillColor: MarketPalette.canvas,
            ),
            onChanged: (_) {
              if (validationError != null) {
                setDialogState(() => validationError = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.replaceAll(RegExp(r'\D'), '');
                if (!_phonePattern.hasMatch(value)) {
                  setDialogState(() => validationError =
                      'Numara 05 ile başlamalı ve 11 haneli olmalı');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    // Diyalog kapanış animasyonu bitince kontrolcü serbest bırakılır
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (phone == null || !context.mounted) return;
    final error = await auth.updatePhone(phone);
    if (!context.mounted) return;
    if (error == null) {
      showMarketSnack(context, 'Telefon numaran güncellendi.', aboveNavigation: true);
    } else {
      showMarketSnack(context, error, error: true, aboveNavigation: true);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const MarketIconTile(
          icon: Icons.logout_rounded,
          size: 52,
          background: MarketPalette.surfaceMuted,
          foreground: MarketPalette.inkSoft,
        ),
        title: const Text('Çıkış yapılsın mı?', textAlign: TextAlign.center),
        content: const Text(
          'Sepetin bu cihazda saklanmaya devam eder.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await auth.logout();
    if (context.mounted) context.go('/login');
  }

  void _showDeleteAccountDialog(BuildContext context) {
    CustomDialog.show(
      context: context,
      title: 'Hesabını silmek istiyor musun?',
      message:
          'Hesabını sildiğinde tüm verilerin kalıcı olarak silinir. Bu işlem geri alınamaz.',
      confirmButtonText: 'Hesabımı sil',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
      onConfirm: () async {
        // Dialogu kapat
        Navigator.of(context, rootNavigator: true).pop();

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
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (success && context.mounted) {
          showMarketSnack(context, 'Hesabın silindi.');
          context.go('/');
        } else if (context.mounted) {
          showMarketSnack(
            context,
            authViewModel.error ?? 'Hesap silinirken bir hata oluştu.',
            error: true,
            aboveNavigation: true,
          );
        }
      },
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MarketCard(
      shadow: false,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      radius: MarketRadius.lg,
      onTap: onTap,
      child: Column(
        children: [
          MarketIconTile(icon: icon, size: 42, background: background, foreground: color),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MarketText.label(size: 12),
          ),
        ],
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

class _StoreInfoGroup extends StatelessWidget {
  const _StoreInfoGroup();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    String hhmm(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final hours =
        '${hhmm(settings.orderStartHour, settings.orderStartMinute)} – ${hhmm(settings.orderEndHour, settings.orderEndMinute)}';
    final points = [
      if (settings.girlsDormEnabled) settings.girlsDormName,
      if (settings.boysDormEnabled) settings.boysDormName,
    ];

    Widget value(String text) => Text(text, style: MarketText.label(size: 14));

    return MarketMenuGroup(
      title: 'Mağaza bilgileri',
      children: [
        MarketMenuTile(
          icon: Icons.schedule_rounded,
          title: 'Sipariş saatleri',
          subtitle: settings.isWithinOrderHours ? 'Şu an açık' : 'Şu an kapalı',
          trailing: value(hours),
        ),
        MarketMenuTile(
          icon: Icons.shopping_basket_outlined,
          title: 'Minimum sepet tutarı',
          trailing: value(formatTlShort(settings.minimumOrderAmount)),
        ),
        MarketMenuTile(
          icon: Icons.location_on_outlined,
          title: 'Teslimat noktaları',
          subtitle: points.isEmpty ? 'Şu an teslimat yapılmıyor' : points.join(' • '),
        ),
      ],
    );
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
