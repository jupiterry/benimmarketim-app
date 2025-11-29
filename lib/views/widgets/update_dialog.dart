import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/version_check_service.dart';
import '../../services/theme_service.dart';
import 'custom_dialog.dart';

/// Zorunlu güncelleme dialog'u
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: CustomDialog(
        title: 'Güncelleme Gerekiyor',
        message:
            'Uygulamanın yeni ve geliştirilmiş bir sürümü yayınlandı. Devam etmek için lütfen güncelleyin.',
        confirmButtonText: 'Şimdi Güncelle',
        cancelButtonText: '',
        showCancelButton: false,
        icon: Icons.system_update_rounded,
        onConfirm: () => _launchPlayStore(context),
      ),
    );
  }

  /// Mağazayı aç
  Future<void> _launchPlayStore(BuildContext context) async {
    final versionService = VersionCheckService();
    final storeUrl = versionService.getStoreUrl();

    if (storeUrl.isEmpty) return;

    try {
      final Uri uri = Uri.parse(storeUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showError(context);
        }
      }
    } catch (e) {
      debugPrint('Mağaza açılırken hata: $e');
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
