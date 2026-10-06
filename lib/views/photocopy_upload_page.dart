import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/app_logger.dart';
import '../services/photocopy_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/file_picker_widget.dart';
import 'widgets/market_ui.dart';

class PhotocopyUploadPage extends StatefulWidget {
  const PhotocopyUploadPage({super.key});

  @override
  State<PhotocopyUploadPage> createState() => _PhotocopyUploadPageState();
}

class _PhotocopyUploadPageState extends State<PhotocopyUploadPage> {
  final _notesController = TextEditingController();

  File? _selectedFile;
  int _copies = 1;
  String _selectedColor = 'black_white';
  String _selectedPaperSize = 'A4';
  bool _isUploading = false;
  Map<String, dynamic>? _pricing;

  static const _colorOptions = {
    'black_white': 'Siyah-beyaz',
    'color': 'Renkli',
  };

  static const _paperSizeOptions = ['A4', 'A3', 'A5', 'Letter'];

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final pricing = await PhotocopyService.getPhotocopyPricing();
      if (!mounted) return;
      setState(() {
        _pricing = pricing;
      });
    } catch (e) {
      // Fiyatlandırma yüklenemezse varsayılan değerler kullanılır
    }
  }

  double _calculatePrice() {
    final colorMultiplier = _selectedColor == 'color' ? 2.0 : 1.0;
    final basePrice = (_pricing?['basePrice'] as num?)?.toDouble() ?? 0.5;
    return _copies * basePrice * colorMultiplier;
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      showMarketSnack(context, 'Lütfen bir dosya seç', error: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final photocopy = await PhotocopyService.uploadFile(
        file: _selectedFile!,
        copies: _copies,
        color: _selectedColor,
        paperSize: _selectedPaperSize,
        notes: _notesController.text,
      );

      if (mounted) {
        showMarketSnack(context, 'Fotokopi isteğin alındı!');
        context.pop(photocopy);
      }
    } catch (e) {
      AppLogger.debug('Fotokopi yükleme hatası: $e');
      if (mounted) {
        showMarketSnack(
          context,
          'Dosya yüklenemedi. Bağlantını kontrol edip tekrar dene.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const MarketHeader(
                  title: 'Fotokopi hizmeti',
                  subtitle: 'Belgeni yükle, siparişinle birlikte hazırlayıp getirelim',
                  icon: Icons.print_rounded,
                  compact: true,
                ),
                if (!loggedIn)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: MarketEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Giriş yapman gerekiyor',
                      message: 'Fotokopi isteği oluşturmak için hesabına giriş yap.',
                      actionLabel: 'Giriş yap',
                      actionIcon: Icons.login_rounded,
                      onAction: () => context.push('/login'),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(
                          step: '1',
                          title: 'Belgeni ekle',
                          child: FilePickerWidget(
                            onFileSelected: (file) => setState(() => _selectedFile = file),
                            onFileRemoved: () => setState(() => _selectedFile = null),
                            selectedFileName: _selectedFile?.path.split('/').last,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _section(
                          step: '2',
                          title: 'Baskı ayarları',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Kopya sayısı',
                                        style: MarketText.label(size: 14, weight: FontWeight.w600)),
                                  ),
                                  MarketStepper(
                                    quantity: _copies,
                                    onMinus: () {
                                      if (_copies > 1) setState(() => _copies--);
                                    },
                                    onPlus: () {
                                      if (_copies < 100) setState(() => _copies++);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text('Renk', style: MarketText.label(size: 14, weight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: [
                                    for (final entry in _colorOptions.entries)
                                      ButtonSegment(
                                        value: entry.key,
                                        label: Text(entry.value),
                                        icon: Icon(entry.key == 'color'
                                            ? Icons.palette_outlined
                                            : Icons.contrast_rounded),
                                      ),
                                  ],
                                  selected: {_selectedColor},
                                  onSelectionChanged: (value) =>
                                      setState(() => _selectedColor = value.first),
                                  style: SegmentedButton.styleFrom(
                                    selectedBackgroundColor: MarketPalette.greenSoft,
                                    selectedForegroundColor: MarketPalette.greenDeep,
                                    side: const BorderSide(color: MarketPalette.line),
                                    textStyle: MarketText.label(size: 13, weight: FontWeight.w600),
                                    minimumSize: const Size(0, 46),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text('Kağıt boyutu', style: MarketText.label(size: 14, weight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final size in _paperSizeOptions)
                                    ChoiceChip(
                                      label: Text(size),
                                      selected: _selectedPaperSize == size,
                                      showCheckmark: false,
                                      onSelected: (_) =>
                                          setState(() => _selectedPaperSize = size),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _section(
                          step: '3',
                          title: 'Not ekle (isteğe bağlı)',
                          child: TextField(
                            controller: _notesController,
                            style: MarketText.body(size: 14),
                            decoration: const InputDecoration(
                              hintText: 'Örn. çift taraflı, zımbalı olsun',
                              fillColor: MarketPalette.canvas,
                            ),
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 200,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const MarketNotice(
                          icon: Icons.info_outline_rounded,
                          text: 'Siyah-beyaz ₺0,50 / kopya • Renkli ₺1,00 / kopya. Kesin tutar hazırlandığında netleşir.',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (loggedIn)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: MarketPalette.line)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Tahmini tutar', style: MarketText.caption()),
                        Text(formatTl(_calculatePrice()), style: MarketText.price(size: 22)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isUploading ? null : _uploadFile,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(_isUploading ? 'Yükleniyor…' : 'İsteği gönder'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required String step,
    required String title,
    required Widget child,
  }) {
    return MarketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MarketPalette.greenDeep,
                  shape: BoxShape.circle,
                ),
                child: Text(step, style: MarketText.label(color: Colors.white, size: 12)),
              ),
              const SizedBox(width: 10),
              Text(title, style: MarketText.heading(size: 16)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
