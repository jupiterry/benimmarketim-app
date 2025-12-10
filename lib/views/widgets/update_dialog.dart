import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/theme_service.dart';
import 'custom_dialog.dart';

class UpdateDialog extends StatelessWidget {
  final bool isMandatory;
  final String storeUrl;
  final String latestVersion;

  const UpdateDialog({
    super.key,
    required this.isMandatory,
    required this.storeUrl,
    required this.latestVersion,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isMandatory, // Zorunluysa geri tuşu çalışmaz
      child: CustomDialog(
        title: 'Güncelleme Mevcut',
        message: isMandatory
            ? 'Uygulamayı kullanmaya devam etmek için kritik bir güncelleme (v$latestVersion) yapmanız gerekmektedir.'
            : 'Uygulamanın yeni bir sürümü (v$latestVersion) mevcut. Daha iyi bir deneyim için güncellemenizi öneririz.',
        confirmButtonText: 'Şimdi Güncelle',
        cancelButtonText: 'Daha Sonra',
        showCancelButton: !isMandatory, // Zorunluysa iptal butonu gizli
        icon: Icons.system_update_rounded,
        onConfirm: () => _launchStore(context),
      ),
    );
  }

  Future<void> _launchStore(BuildContext context) async {
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
      debugPrint('Error launching store: $e');
      if (context.mounted) {
        _showError(context);
      }
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mağaza açılamadı. Lütfen manuel olarak güncelleyin.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }
}

void showUpdateDialog(
  BuildContext context, {
  required bool isMandatory,
  required String storeUrl,
  required String latestVersion,
}) {
  showDialog(
    context: context,
    barrierDismissible: !isMandatory, // Zorunluysa dışarı tıklayarak kapanmaz
    builder: (context) => UpdateDialog(
      isMandatory: isMandatory,
      storeUrl: storeUrl,
      latestVersion: latestVersion,
    ),
  );
}
