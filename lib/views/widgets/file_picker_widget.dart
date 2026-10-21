import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/app_logger.dart';
import 'market_ui.dart';

class FilePickerWidget extends StatefulWidget {
  final Function(File) onFileSelected;

  /// Kullanıcı seçili dosyayı kaldırdığında çağrılır; üst sayfa kendi
  /// seçimini de temizlemeli (aksi halde kaldırılan dosya yüklenir).
  final VoidCallback? onFileRemoved;
  final String? selectedFileName;
  final bool isEnabled;

  const FilePickerWidget({
    super.key,
    required this.onFileSelected,
    this.onFileRemoved,
    this.selectedFileName,
    this.isEnabled = true,
  });

  @override
  State<FilePickerWidget> createState() => _FilePickerWidgetState();
}

enum _PickSource { document, camera, gallery }

class _FilePickerWidgetState extends State<FilePickerWidget> {
  File? _selectedFile;
  String? _selectedFileName;

  // Kamera/galeriden gelen dosyanın adı anlamsızdır ("image_picker_3F2A…");
  // kullanıcıya "Fotoğraf" olarak gösterilir.
  bool _isPhoto = false;

  @override
  void initState() {
    super.initState();
    _selectedFileName = widget.selectedFileName;
  }

  Future<void> _pickFile() async {
    if (!widget.isEnabled) return;

    // Önce kaynak seçilir; seçici, alt sayfa kapandıktan sonra açılır (hata
    // olursa bildirim sayfanın üstünde görünür).
    final source = await showMarketSheet<_PickSource>(
      context,
      builder: (sheetContext) => MarketSheetScaffold(
        header: const MarketSheetHeader(title: 'Belgeni nereden ekleyelim?'),
        body: MarketMenuGroup(
          children: [
            MarketMenuTile(
              icon: Icons.folder_open_rounded,
              title: 'Dosyalardan seç',
              subtitle: 'PDF, DOC, DOCX, JPG, PNG',
              iconColor: MarketPalette.blue,
              iconBackground: MarketPalette.blueSoft,
              onTap: () => Navigator.pop(sheetContext, _PickSource.document),
            ),
            MarketMenuTile(
              icon: Icons.photo_camera_outlined,
              title: 'Fotoğrafını çek',
              subtitle: 'Kamerayla belgeni tara',
              onTap: () => Navigator.pop(sheetContext, _PickSource.camera),
            ),
            MarketMenuTile(
              icon: Icons.photo_library_outlined,
              title: 'Galeriden seç',
              iconColor: MarketPalette.pink,
              iconBackground: MarketPalette.pinkSoft,
              onTap: () => Navigator.pop(sheetContext, _PickSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = switch (source) {
      _PickSource.document => await _pickDocument(),
      _PickSource.camera => await _pickImage(ImageSource.camera),
      _PickSource.gallery => await _pickImage(ImageSource.gallery),
    };
    if (file == null || !mounted) return;
    setState(() {
      _selectedFile = file;
      _selectedFileName = file.path.split('/').last;
      _isPhoto = source != _PickSource.document;
    });
    widget.onFileSelected(file);
  }

  Future<File?> _pickDocument() async {
    try {
      // Dosya seçici kullan
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      return path == null ? null : File(path);
    } catch (e) {
      AppLogger.debug('Dosya seçilemedi: $e');
      _showErrorSnackBar('Dosya seçilemedi. Dosyalara erişim iznini kontrol et.');
      return null;
    }
  }

  Future<File?> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source, imageQuality: 85);
      return image == null ? null : File(image.path);
    } catch (e) {
      AppLogger.debug('Fotoğraf alınamadı: $e');
      _showErrorSnackBar(source == ImageSource.camera
          ? 'Kamera açılamadı. Kamera iznini kontrol et.'
          : 'Galeri açılamadı. Fotoğraf iznini kontrol et.');
      return null;
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _isPhoto = false;
    });
    widget.onFileRemoved?.call();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) showMarketSnack(context, message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return _selectedFile != null
        ? _buildSelectedFileWidget()
        : _buildFilePickerWidget();
  }

  Widget _buildSelectedFileWidget() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: MarketPalette.greenSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.greenLine),
      ),
      child: Row(
        children: [
          MarketIconTile(
            icon: _isPhoto ? Icons.image_rounded : _getFileIcon(_selectedFileName ?? ''),
            size: 44,
            background: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPhoto ? 'Fotoğraf' : (_selectedFileName ?? 'Dosya seçildi'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MarketText.label(size: 14),
                ),
                if (_selectedFile != null)
                  Text(
                    '${_getFileSizeText(_selectedFile!)} • Hazır',
                    style: MarketText.caption(color: MarketPalette.greenDark),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.isEnabled ? _removeFile : null,
            icon: const Icon(Icons.close_rounded, color: MarketPalette.red),
            tooltip: 'Dosyayı kaldır',
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerWidget() {
    return Material(
      color: MarketPalette.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.md),
        side: const BorderSide(color: MarketPalette.lineStrong, width: 1.5),
      ),
      child: InkWell(
        onTap: widget.isEnabled ? _pickFile : null,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          child: Column(
            children: [
              const MarketIconTile(
                icon: Icons.upload_file_rounded,
                size: 52,
                background: MarketPalette.blueSoft,
                foreground: MarketPalette.blue,
              ),
              const SizedBox(height: 10),
              Text('Belge seç veya fotoğrafını çek', style: MarketText.label(size: 14)),
              const SizedBox(height: 3),
              Text(
                'PDF, DOC, DOCX, JPG ve PNG desteklenir',
                style: MarketText.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'tiff':
      case 'bmp':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileSizeText(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
      }
    } catch (e) {
      return 'Boyut bilinmiyor';
    }
  }
}
