import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/version_check_service.dart';
import '../../services/theme_service.dart';

/// Zorunlu güncelleme dialog'u
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Geri tuşu ile kapatılamaz
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İkon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 64,
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(height: 24),

              // Başlık
              Text(
                'Güncelleme Gerekiyor',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Açıklama
              Text(
                'Uygulamanın yeni ve geliştirilmiş bir sürümü yayınlandı. Devam etmek için lütfen güncelleyin.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Güncelle Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _launchPlayStore(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.successGreen.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Şimdi Güncelle',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Play Store'u aç
  Future<void> _launchPlayStore(BuildContext context) async {
    final versionService = VersionCheckService();
    final playStoreUrl = versionService.getPlayStoreUrl();
    final webPlayStoreUrl = versionService.getWebPlayStoreUrl();

    try {
      final Uri uri = Uri.parse(playStoreUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // market:// açılmazsa web URL'ini dene
        final Uri webUri = Uri.parse(webPlayStoreUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            _showError(context);
          }
        }
      }
    } catch (e) {
      print('Play Store açılırken hata: $e');
      if (context.mounted) {
        _showError(context);
      }
    }
  }

  /// Hata mesajı göster
  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Play Store açılamadı. Lütfen manuel olarak güncelleyin.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Güncelleme dialog'unu göster
void showUpdateDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Dışarı tıklayarak kapatılamaz
    builder: (context) => const UpdateDialog(),
  );
}
