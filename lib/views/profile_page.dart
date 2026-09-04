import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/theme_service.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/modern_ui.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = ApiService().getSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(context),

            // Profile Content
            Expanded(
              child: Consumer<AuthViewModel>(
                builder: (context, authViewModel, child) {
                  if (!authViewModel.isLoggedIn) {
                    return _buildNotLoggedInView(context);
                  }

                  if (authViewModel.user == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      authViewModel.updateProfile();
                    });
                    return const Center(child: CircularProgressIndicator());
                  }

                  final user = authViewModel.user!;
                  if (user.name.isEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      authViewModel.updateProfile();
                    });
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildProfileHeader(user),
                        const SizedBox(height: 30),
                        _buildSectionHeader('Hesabım'),
                        _buildMenuOption(
                          context,
                          icon: Icons.shopping_bag_outlined,
                          title: 'Siparişlerim',
                          onTap: () => context.push('/orders'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.favorite_outline,
                          title: 'Favorilerim',
                          onTap: () => context.push('/favorites'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.card_giftcard_outlined,
                          title: 'Arkadaşını Getir',
                          onTap: () => context.push('/referral'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.print_outlined,
                          title: 'Fotokopi Hizmeti',
                          onTap: () => context.push('/photocopy-upload'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.history,
                          title: 'Fotokopi Geçmişi',
                          onTap: () => context.push('/photocopy-history'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.chat_bubble_outline,
                          title: 'Canlı Destek',
                          onTap: () => context.push('/chat'),
                        ),
                        _buildMenuOption(
                          context,
                          icon: Icons.delete_outline_rounded,
                          title: 'Hesabımı Sil',
                          onTap: () => _showDeleteAccountDialog(context),
                          isDestructive: true,
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Sistem Ayarları'),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _settingsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Ayarlar yüklenemedi',
                                style: GoogleFonts.poppins(color: Colors.red),
                              );
                            }
                            final settings = snapshot.data ?? {};
                            final minAmount =
                                settings['minimumOrderAmount'] ?? 0;
                            final startHour = settings['orderStartHour'] ?? 0;
                            final startMinute =
                                settings['orderStartMinute'] ?? 0;
                            final endHour = settings['orderEndHour'] ?? 0;
                            final endMinute = settings['orderEndMinute'] ?? 0;

                            return Column(
                              children: [
                                _buildInfoTile(
                                  icon: Icons.monetization_on_outlined,
                                  title: 'Minimum Sipariş Tutarı',
                                  value: '₺$minAmount',
                                ),
                                _buildInfoTile(
                                  icon: Icons.access_time,
                                  title: 'Sipariş Saatleri',
                                  value:
                                      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        _buildLogoutButton(context, authViewModel),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123D24), Color(0xFF087F35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: AppColors.successGreen.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hesabım',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                Text('Siparişlerini ve tercihlerini yönet',
                    style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.more_horiz_rounded,
              color: Colors.white.withOpacity(.75), size: 25),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Column(
      children: [
        ModernSoftCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.successGreen, Color(0xFF8DE8A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen.withOpacity(.25),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded,
                    size: 35, color: Colors.white),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hoş geldin 👋',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.successGreenDark,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(user.name.isNotEmpty ? user.name : 'Kullanıcı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17221B))),
                    Text(user.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDestructive
                  ? AppColors.errorRed.withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isDestructive ? AppColors.errorRed : Colors.black87,
                size: 22),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDestructive ? AppColors.errorRed : Colors.black87,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[300],
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthViewModel authViewModel) {
    return TextButton(
      onPressed: () async {
        // Instant logout without dialog
        await authViewModel.logout();
        if (context.mounted) {
          context.go('/login');
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.red[50],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: Colors.red[400], size: 20),
          const SizedBox(width: 10),
          Text(
            'Çıkış Yap',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[400],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    CustomDialog.show(
      context: context,
      title: 'Hesabınızı Silmek İstiyor musunuz?',
      message:
          'Hesabınızı sildiğinizde tüm verileriniz kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
      confirmButtonText: 'Hesabımı Sil',
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
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.errorRed),
            ),
          ),
        );

        final authViewModel = context.read<AuthViewModel>();
        final success = await authViewModel.deleteAccount();

        // Loading kapat
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Hesabınız başarıyla silindi.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.successGreen,
            ),
          );
          context.go('/');
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authViewModel.error ?? 'Hesap silinirken bir hata oluştu.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      },
    );
  }

  Widget _buildNotLoggedInView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Giriş Yapın',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Siparişlerinizi takip etmek ve size özel fırsatlardan yararlanmak için giriş yapın.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.push('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Giriş Yap',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sistem Ayarları',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _settingsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Ayarlar yüklenemedi',
                            style: GoogleFonts.poppins(color: Colors.red),
                          );
                        }
                        final settings = snapshot.data ?? {};
                        final minAmount = settings['minimumOrderAmount'] ?? 0;
                        final startHour = settings['orderStartHour'] ?? 0;
                        final startMinute = settings['orderStartMinute'] ?? 0;
                        final endHour = settings['orderEndHour'] ?? 0;
                        final endMinute = settings['orderEndMinute'] ?? 0;

                        return Column(
                          children: [
                            _buildInfoTile(
                              icon: Icons.monetization_on_outlined,
                              title: 'Minimum Sipariş Tutarı',
                              value: '₺$minAmount',
                            ),
                            _buildInfoTile(
                              icon: Icons.access_time,
                              title: 'Sipariş Saatleri',
                              value:
                                  '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          trailing: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
