import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import 'custom_dialog.dart';
import 'market_ui.dart';

// ---------------------------------------------------------------------------
// Hesap eylemleri: Hesabım ve Ayarlar aynı çıkış / hesap silme akışını
// kullanır (aynı onay penceresi, aynı bekleme kartı, aynı sonuç).
// ---------------------------------------------------------------------------

/// Onay alır, çıkış yapar ve giriş ekranına götürür. Sepet cihazda kalır.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showMarketConfirm(
    context,
    icon: Icons.logout_rounded,
    title: 'Çıkış yapılsın mı?',
    message: 'Sepetin bu cihazda saklanmaya devam eder.',
    confirmLabel: 'Çıkış yap',
  );
  if (!confirmed || !context.mounted) return;

  // Çıkıştan sonra Hesabım misafir görünümüne geçer ve bu bağlam ağaçtan
  // kalkabilir; yönlendirici önceden alınır.
  final router = GoRouter.of(context);
  final auth = context.read<AuthViewModel>();
  await runWithMarketProgress<void>(
    context,
    message: 'Çıkış yapılıyor…',
    task: auth.logout,
  );
  router.go('/login');
}

/// Geri alınamaz hesap silme: kırmızı onay, "Hesabın siliniyor…" bekleme
/// kartı; başarılıysa ana sayfaya döner.
Future<void> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showMarketConfirm(
    context,
    icon: Icons.warning_amber_rounded,
    title: 'Hesabın silinsin mi?',
    message: 'Hesabını sildiğinde tüm verilerin kalıcı olarak silinir. '
        'Bu işlem geri alınamaz.',
    confirmLabel: 'Hesabımı sil',
    tone: MarketTone.danger,
  );
  if (!confirmed || !context.mounted) return;

  final router = GoRouter.of(context);
  final auth = context.read<AuthViewModel>();
  // Bildirim çubuğu sayfa değişse de görünsün diye kök gezginin bağlamı
  // kullanılır (bu sayfa birazdan kapanır).
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final success = await runWithMarketProgress<bool>(
    context,
    message: 'Hesabın siliniyor…',
    task: auth.deleteAccount,
  );
  if (!rootContext.mounted) return;
  if (success) {
    showMarketSnack(rootContext, 'Hesabın silindi.');
    router.go('/');
  } else {
    final error = auth.error?.replaceAll('Exception: ', '').trim();
    showMarketSnack(
      rootContext,
      error == null || error.isEmpty
          ? 'Hesabın silinemedi. Bağlantını kontrol edip tekrar dene.'
          : error,
      error: true,
    );
  }
}
