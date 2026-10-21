import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photocopy.dart';
import '../services/api_service.dart';
import '../services/app_logger.dart';
import '../services/photocopy_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/market_ui.dart';

class PhotocopyHistoryPage extends StatefulWidget {
  const PhotocopyHistoryPage({super.key});

  @override
  State<PhotocopyHistoryPage> createState() => _PhotocopyHistoryPageState();
}

class _PhotocopyHistoryPageState extends State<PhotocopyHistoryPage> {
  List<Photocopy> _photocopies = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadPhotocopyHistory();
  }

  Future<void> _loadPhotocopyHistory() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });

    try {
      final photocopies = await PhotocopyService.getPhotocopyHistory();
      if (!mounted) return;
      setState(() {
        _photocopies = photocopies;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.debug('Fotokopi geçmişi yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    await _loadPhotocopyHistory();
  }

  Future<void> _cancelPhotocopy(Photocopy photocopy) async {
    final confirmed = await showMarketConfirm(
      context,
      icon: Icons.close_rounded,
      title: 'İstek iptal edilsin mi?',
      message: '"${photocopy.originalName}" için fotokopi isteği iptal edilecek.',
      confirmLabel: 'İsteği iptal et',
      tone: MarketTone.danger,
    );
    if (!confirmed || !mounted) return;
    try {
      await runWithMarketProgress<void>(
        context,
        message: 'İstek iptal ediliyor…',
        task: () => PhotocopyService.cancelPhotocopy(photocopy.id),
      );
      if (!mounted) return;
      showMarketSnack(context, 'Fotokopi isteği iptal edildi');
      _refreshHistory();
    } catch (e) {
      AppLogger.debug('Fotokopi iptal hatası: $e');
      if (!mounted) return;
      showMarketSnack(
        context,
        e is ApiException ? e.message : 'İstek iptal edilemedi. Lütfen tekrar dene.',
        error: true,
      );
    }
  }

  Future<void> _downloadPhotocopy(Photocopy photocopy) async {
    try {
      final filePath = await runWithMarketProgress(
        context,
        message: 'Dosya indiriliyor…',
        task: () => PhotocopyService.downloadPhotocopy(photocopy),
      );
      if (!mounted) return;
      // Dosya uygulamanın kendi klasörüne kaydedilir; kullanıcı onu
      // paylaşarak (Dosyalar'a kaydet, WhatsApp…) dışarı alır.
      showMarketSnack(
        context,
        'Dosya indirildi',
        icon: Icons.download_done_rounded,
        actionLabel: 'Paylaş',
        onAction: () => Share.shareXFiles([XFile(filePath)]),
      );
    } catch (e) {
      AppLogger.debug('Fotokopi indirme hatası: $e');
      if (!mounted) return;
      showMarketSnack(
        context,
        e is ApiException ? e.message : 'Dosya indirilemedi. Lütfen tekrar dene.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Column(
        children: [
          MarketHeader(
            title: 'Fotokopi geçmişi',
            subtitle: 'İsteklerinin durumunu buradan takip et',
            icon: Icons.history_rounded,
            compact: true,
            actions: [
              if (loggedIn)
                MarketHeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Yenile',
                  onTap: _refreshHistory,
                ),
            ],
          ),
          Expanded(child: _buildBody(loggedIn)),
        ],
      ),
      floatingActionButton: loggedIn
          ? FloatingActionButton.extended(
              onPressed: () {
                context
                    .push<Photocopy>('/photocopy-upload')
                    .then((_) => _refreshHistory());
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni istek'),
            )
          : null,
    );
  }

  Widget _buildBody(bool loggedIn) {
    if (!loggedIn) {
      return MarketEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Giriş yapman gerekiyor',
        message: 'Fotokopi isteklerini görmek için hesabına giriş yap.',
        actionLabel: 'Giriş yap',
        actionIcon: Icons.login_rounded,
        onAction: () => context.push('/login'),
      );
    }

    if (_isLoading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: MarketListSkeleton(),
      );
    }

    if (_failed) {
      return MarketEmptyState.error(
        title: 'Geçmiş yüklenemedi',
        onRetry: _refreshHistory,
      );
    }

    if (_photocopies.isEmpty) {
      return MarketEmptyState(
        icon: Icons.print_outlined,
        title: 'Henüz fotokopi isteğin yok',
        message: 'Belgeni yükle, siparişinle birlikte hazırlayıp getirelim.',
        actionLabel: 'İlk isteği oluştur',
        actionIcon: Icons.upload_file_rounded,
        onAction: () => context
            .push<Photocopy>('/photocopy-upload')
            .then((_) => _refreshHistory()),
        tint: MarketPalette.blue,
        tintSoft: MarketPalette.blueSoft,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.separated(
        // Alttaki "Yeni istek" butonu son kartı örtmesin
        padding: EdgeInsets.fromLTRB(
          MarketSpace.gutterOf(context),
          20,
          MarketSpace.gutterOf(context),
          110,
        ),
        itemCount: _photocopies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildPhotocopyCard(_photocopies[index]),
      ),
    );
  }

  Widget _buildPhotocopyCard(Photocopy photocopy) {
    final dateText = formatTrDateTime(photocopy.createdAt, withTime: false);

    return MarketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MarketIconTile(
                icon: _getFileIcon(photocopy.fileKind),
                size: 44,
                background: MarketPalette.blueSoft,
                foreground: MarketPalette.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photocopy.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.label(size: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${photocopy.fileSizeText.replaceAll('.', ',')} • $dateText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(photocopy.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MarketPill(
                icon: Icons.copy_all_rounded,
                label: '${photocopy.copies} kopya',
                background: MarketPalette.surfaceMuted,
                foreground: MarketPalette.inkSoft,
              ),
              MarketPill(
                icon: Icons.palette_outlined,
                // Cümle düzeninde etiket (modeldeki metin değişmez)
                label: photocopy.color == 'color' ? 'Renkli' : 'Siyah-beyaz',
                background: MarketPalette.surfaceMuted,
                foreground: MarketPalette.inkSoft,
              ),
              MarketPill(
                icon: Icons.description_outlined,
                label: photocopy.paperSize,
                background: MarketPalette.surfaceMuted,
                foreground: MarketPalette.inkSoft,
              ),
              if (photocopy.price != null)
                MarketPill(
                  icon: Icons.sell_outlined,
                  label: photocopy.isPaid
                      ? '${formatTl(photocopy.price!)} • Ödendi'
                      : formatTl(photocopy.price!),
                ),
            ],
          ),
          if (photocopy.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            MarketNotice(
              icon: Icons.sticky_note_2_outlined,
              text: 'Notun: ${photocopy.notes}',
              background: MarketPalette.surfaceMuted,
              foreground: MarketPalette.inkSoft,
            ),
          ],
          if (photocopy.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            MarketNotice(
              icon: Icons.storefront_outlined,
              text: 'Market notu: ${photocopy.adminNotes}',
            ),
          ],
          _buildActionButtons(photocopy),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final (Color fg, Color bg, String text) = switch (status) {
      'pending' => (MarketPalette.orangeInk, MarketPalette.orangeSoft, 'Beklemede'),
      'processing' => (MarketPalette.blue, MarketPalette.blueSoft, 'Hazırlanıyor'),
      'ready' => (MarketPalette.greenDark, MarketPalette.greenSoft, 'Hazır'),
      'completed' => (MarketPalette.greenDark, MarketPalette.greenSoft, 'Tamamlandı'),
      'failed' => (MarketPalette.red, MarketPalette.redSoft, 'Başarısız'),
      _ => (MarketPalette.muted, MarketPalette.surfaceMuted, 'Bilinmiyor'),
    };
    return MarketPill(label: text, background: bg, foreground: fg);
  }

  Widget _buildActionButtons(Photocopy photocopy) {
    if (photocopy.status == 'pending') {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: OutlinedButton.icon(
          onPressed: () => _cancelPhotocopy(photocopy),
          icon: const Icon(Icons.close_rounded, size: 19),
          label: const Text('İsteği iptal et'),
          style: OutlinedButton.styleFrom(
            foregroundColor: MarketPalette.red,
            side: const BorderSide(color: MarketPalette.redLine),
            minimumSize: const Size.fromHeight(MarketSize.tapTarget),
          ),
        ),
      );
    }

    if (photocopy.status == 'ready' || photocopy.status == 'completed') {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: FilledButton.icon(
          onPressed: () => _downloadPhotocopy(photocopy),
          icon: const Icon(Icons.download_rounded, size: 19),
          label: const Text('Dosyayı indir'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.tapTarget)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getFileIcon(String fileKind) {
    switch (fileKind) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
        return Icons.description_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
