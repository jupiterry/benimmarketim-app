import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_dialog.dart';
import 'market_ui.dart';
import '../../services/app_logger.dart';

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
        title: 'Yeni sürüm hazır',
        message: isMandatory
            ? 'Uygulamayı kullanmaya devam etmek için yeni sürümü (v$latestVersion) yüklemen gerekiyor.'
            : 'Yeni sürüm (v$latestVersion) yayında. Daha hızlı ve sorunsuz bir deneyim için güncellemeni öneririz.',
        confirmButtonText: 'Şimdi güncelle',
        cancelButtonText: 'Daha sonra',
        showCancelButton: !isMandatory, // Zorunluysa iptal butonu gizli
        icon: Icons.system_update_rounded,
        onConfirm: () => _launchStore(context),
      ),
    );
  }

  Future<void> _launchStore(BuildContext context) async {
    if (storeUrl.isEmpty) return;
    // İsteğe bağlı güncellemede pencere kapanır; kullanıcı mağazadan
    // döndüğünde karşısına yeniden çıkmaz. Zorunluysa açık kalır.
    final messengerContext = Navigator.of(context, rootNavigator: true).context;
    if (!isMandatory) Navigator.of(context).pop();

    try {
      final Uri uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (messengerContext.mounted) {
          _showError(messengerContext);
        }
      }
    } catch (e) {
      AppLogger.debug('Error launching store: $e');
      if (messengerContext.mounted) {
        _showError(messengerContext);
      }
    }
  }

  void _showError(BuildContext context) {
    showMarketSnack(
      context,
      'Mağaza açılamadı. Uygulamayı mağazadan elle güncelleyebilirsin.',
      error: true,
    );
  }
}

void showUpdateDialog(
  BuildContext context, {
  required bool isMandatory,
  required String storeUrl,
  required String latestVersion,
}) {
  showMarketDialog<void>(
    context,
    barrierDismissible: !isMandatory, // Zorunluysa dışarı tıklayarak kapanmaz
    builder: (context) => UpdateDialog(
      isMandatory: isMandatory,
      storeUrl: storeUrl,
      latestVersion: latestVersion,
    ),
  );
}
