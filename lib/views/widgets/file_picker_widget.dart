import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class FilePickerWidget extends StatefulWidget {
  final Function(File) onFileSelected;
  final String? selectedFileName;
  final bool isEnabled;

  const FilePickerWidget({
    super.key,
    required this.onFileSelected,
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Dosya Seç',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSelectionButton(
                  icon: Icons.folder_open,
                  title: 'Dosya Seç',
                  subtitle: 'PDF, DOC, JPG, PNG',
                  onTap: _pickDocument,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectionButton(
                  icon: Icons.camera_alt,
                  title: 'Kamera',
                  subtitle: 'Fotoğraf Çek',
                  onTap: _pickImageFromCamera,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSelectionButton(
            icon: Icons.photo_library,
            title: 'Galeri',
            subtitle: 'Galeriden Seç',
            onTap: _pickImageFromGallery,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedFile != null ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _selectedFile != null
          ? _buildSelectedFileWidget()
          : _buildFilePickerWidget(),
    );
  }

  Widget _buildSelectedFileWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _getFileIcon(_selectedFileName ?? ''),
            color: Colors.green,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'Dosya seçildi',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedFile != null)
                  Text(
                    _getFileSizeText(_selectedFile!),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _removeFile,
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Dosyayı kaldır',
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerWidget() {
    return InkWell(
      onTap: widget.isEnabled ? _pickFile : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.upload_file,
              color: widget.isEnabled ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dosya Seç',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: widget.isEnabled ? Colors.black : Colors.grey,
                    ),
                  ),
                  Text(
                    'PDF, DOC, JPG, PNG dosyaları desteklenir',
                    style: TextStyle(
                      color: widget.isEnabled
                          ? Colors.grey.shade600
                          : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: widget.isEnabled ? Colors.grey : Colors.grey.shade300,
              size: 16,
            ),
          ],
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
