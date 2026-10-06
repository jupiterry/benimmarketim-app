import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

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

class _FilePickerWidgetState extends State<FilePickerWidget> {
  File? _selectedFile;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _selectedFileName = widget.selectedFileName;
  }

  Future<void> _pickFile() async {
    if (!widget.isEnabled) return;

    try {
      // Dosya seçimi için dialog göster
      final result = await showModalBottomSheet<File?>(
        context: context,
        builder: (context) => _buildFileSelectionSheet(),
      );

      if (result != null) {
        setState(() {
          _selectedFile = result;
          _selectedFileName = result.path.split('/').last;
        });
        widget.onFileSelected(result);
      }
    } catch (e) {
      _showErrorSnackBar('Dosya seçilirken hata oluştu: $e');
    }
  }

  Widget _buildFileSelectionSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: MarketPalette.lineStrong,
                  borderRadius: BorderRadius.circular(MarketRadius.sm),
                ),
              ),
            ),
            Text('Belgeni nereden ekleyelim?', style: MarketText.title(size: 22)),
            const SizedBox(height: 16),
            MarketMenuGroup(
              children: [
                MarketMenuTile(
                  icon: Icons.folder_open_rounded,
                  title: 'Dosyalardan seç',
                  subtitle: 'PDF, DOC, DOCX, JPG, PNG',
                  iconColor: MarketPalette.blue,
                  iconBackground: MarketPalette.blueSoft,
                  onTap: _pickDocument,
                ),
                MarketMenuTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Fotoğrafını çek',
                  subtitle: 'Kamerayla belgeni tara',
                  onTap: _pickImageFromCamera,
                ),
                MarketMenuTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Galeriden seç',
                  iconColor: MarketPalette.pink,
                  iconBackground: MarketPalette.pinkSoft,
                  onTap: _pickImageFromGallery,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      // Dosya seçici kullan
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (mounted) {
          context.pop(file);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Dosya seçilirken hata oluştu: $e');
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      // Kameradan fotoğraf çek
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (mounted) {
          context.pop(file);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Kamera kullanılırken hata oluştu: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // Galeriden fotoğraf seç
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (mounted) {
          context.pop(file);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Galeri kullanılırken hata oluştu: $e');
      }
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });
    widget.onFileRemoved?.call();
  }

  void _showErrorSnackBar(String message) {
    showMarketSnack(context, message, error: true);
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
            icon: _getFileIcon(_selectedFileName ?? ''),
            size: 44,
            background: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'Dosya seçildi',
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
            onPressed: _removeFile,
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
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Boyut bilinmiyor';
    }
  }
}
