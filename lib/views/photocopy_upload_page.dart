import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/photocopy_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/file_picker_widget.dart';
import '../services/theme_service.dart';
import 'package:go_router/go_router.dart';

class PhotocopyUploadPage extends StatefulWidget {
  const PhotocopyUploadPage({super.key});

  @override
  State<PhotocopyUploadPage> createState() => _PhotocopyUploadPageState();
}

class _PhotocopyUploadPageState extends State<PhotocopyUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _copiesController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  File? _selectedFile;
  String _selectedColor = 'black_white';
  String _selectedPaperSize = 'A4';
  bool _isUploading = false;
  Map<String, dynamic>? _pricing;

  final List<Map<String, String>> _colorOptions = [
    {'value': 'black_white', 'label': 'Siyah-Beyaz'},
    {'value': 'color', 'label': 'Renkli'},
  ];

  final List<Map<String, String>> _paperSizeOptions = [
    {'value': 'A4', 'label': 'A4'},
    {'value': 'A3', 'label': 'A3'},
    {'value': 'A5', 'label': 'A5'},
    {'value': 'Letter', 'label': 'Letter'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  @override
  void dispose() {
    _copiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final pricing = await PhotocopyService.getPhotocopyPricing();
      setState(() {
        _pricing = pricing;
      });
    } catch (e) {
      // Fiyatlandırma yüklenemezse varsayılan değerler kullanılır
    }
  }

  void _onFileSelected(File file) {
    setState(() {
      _selectedFile = file;
    });
  }

  double _calculatePrice() {
    if (_pricing == null) return 0.0;

    final copies = int.tryParse(_copiesController.text) ?? 1;
    final colorMultiplier = _selectedColor == 'color' ? 2.0 : 1.0;
    final basePrice = _pricing!['basePrice'] ?? 0.5;

    return copies * basePrice * colorMultiplier;
  }

  Future<void> _uploadFile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      _showSnackBar('Lütfen bir dosya seçin', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final copies = int.parse(_copiesController.text);

      final photocopy = await PhotocopyService.uploadFile(
        file: _selectedFile!,
        copies: copies,
        color: _selectedColor,
        paperSize: _selectedPaperSize,
        notes: _notesController.text,
      );

      if (mounted) {
        _showSnackBar('Dosya başarıyla yüklendi!', isError: false);
        context.pop(photocopy);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Yükleme hatası: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        title: Text(
          'Fotokopi Hizmeti',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF075B39),
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
          if (!authViewModel.isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Giriş Yapın',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fotokopi hizmeti için giriş yapmanız gerekiyor',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceHero(),
                  const SizedBox(height: 20),
                  _buildFileSelectionCard(),
                  const SizedBox(height: 24),
                  _buildOptionsCard(),
                  const SizedBox(height: 24),
                  _buildNotesCard(),
                  const SizedBox(height: 24),
                  _buildPricingCard(),
                  const SizedBox(height: 32),
                  _buildUploadButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceHero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF063F2B), Color(0xFF0E7A4A)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFB9EB67),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.print_rounded,
                  color: Color(0xFF063F2B), size: 29),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dosyanı gönder, biz hazırlayalım',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      'PDF veya belgeni yükle; renk, boyut ve adet seçeneklerini belirle.',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 10, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildFileSelectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Dosya Seçimi',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilePickerWidget(
            onFileSelected: _onFileSelected,
            selectedFileName: _selectedFile?.path.split('/').last,
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dosya seçildi: ${_selectedFile!.path.split('/').last}',
                      style: GoogleFonts.poppins(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: Colors.orange[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Fotokopi Ayarları',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _copiesController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Kopya Sayısı',
              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.copy_rounded, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.successGreen),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Kopya sayısı gerekli';
              final copies = int.tryParse(value);
              if (copies == null || copies < 1 || copies > 100)
                return '1-100 arası bir sayı girin';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedColor,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Renk',
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.palette_rounded,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                items: _colorOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(option['label']!),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedColor = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaperSize,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Kağıt Boyutu',
                  labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.aspect_ratio_rounded,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                items: _paperSizeOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(option['label']!),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedPaperSize = value!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.note_alt_rounded,
                  color: Colors.purple[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Notlar (İsteğe Bağlı)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _notesController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Özel isteklerinizi buraya yazabilirsiniz...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.successGreen),
              ),
            ),
            maxLines: 3,
            maxLength: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    final price = _calculatePrice();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.successGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Fiyatlandırma',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.successGreen.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tahmini Tutar',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '₺${price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Siyah-beyaz: ₺0.50/kopya\n• Renkli: ₺1.00/kopya',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadFile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.successGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.successGreen.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_rounded),
                  const SizedBox(width: 12),
                  Text(
                    'Fotokopi İsteği Gönder',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
