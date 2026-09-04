import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/photocopy.dart';
import '../services/photocopy_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/theme_service.dart';
import 'package:go_router/go_router.dart';

class PhotocopyHistoryPage extends StatefulWidget {
  const PhotocopyHistoryPage({super.key});

  @override
  State<PhotocopyHistoryPage> createState() => _PhotocopyHistoryPageState();
}

class _PhotocopyHistoryPageState extends State<PhotocopyHistoryPage> {
  List<Photocopy> _photocopies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotocopyHistory();
  }

  Future<void> _loadPhotocopyHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final photocopies = await PhotocopyService.getPhotocopyHistory();
      setState(() {
        _photocopies = photocopies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    await _loadPhotocopyHistory();
  }

  Future<void> _cancelPhotocopy(Photocopy photocopy) async {
    try {
      await PhotocopyService.cancelPhotocopy(photocopy.id);
      _showSnackBar('Fotokopi iptal edildi', isError: false);
      _refreshHistory();
    } catch (e) {
      _showSnackBar('İptal hatası: $e', isError: true);
    }
  }

  Future<void> _downloadPhotocopy(Photocopy photocopy) async {
    try {
      final filePath = await PhotocopyService.downloadPhotocopy(photocopy.id);
      _showSnackBar('Dosya indirildi: $filePath', isError: false);
    } catch (e) {
      _showSnackBar('İndirme hatası: $e', isError: true);
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
          'Fotokopi Geçmişi',
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
        actions: [
          IconButton(
            onPressed: _refreshHistory,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Yenile',
          ),
        ],
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
                    'Fotokopi geçmişi için giriş yapmanız gerekiyor',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.successGreen,
                ),
              ),
            );
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.errorRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: $_error',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.errorRed,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshHistory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Tekrar Dene',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }

          if (_photocopies.isEmpty) {
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
                      Icons.history_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Henüz fotokopi isteğiniz bulunmuyor',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni bir fotokopi isteği oluşturmak için + butonuna basın',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshHistory,
            color: AppColors.successGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _photocopies.length,
              itemBuilder: (context, index) {
                final photocopy = _photocopies[index];
                return _buildPhotocopyCard(photocopy);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context
              .push<Photocopy>('/photocopy-upload')
              .then((_) => _refreshHistory());
        },
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
        tooltip: 'Yeni Fotokopi İsteği',
      ),
    );
  }

  Widget _buildPhotocopyCard(Photocopy photocopy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusChip(photocopy.status),
                const Spacer(),
                Text(
                  photocopy.createdAt.toString().split(' ')[0],
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFileIcon(photocopy.fileType),
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photocopy.originalName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        photocopy.fileSizeText,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Kopya Sayısı', '${photocopy.copies}'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Renk', photocopy.colorText),
                  const SizedBox(height: 8),
                  _buildInfoRow('Kağıt Boyutu', photocopy.paperSize),
                  if (photocopy.price != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Fiyat',
                      '₺${photocopy.price!.toStringAsFixed(2)}',
                      isPrice: true,
                    ),
                  ],
                ],
              ),
            ),
            if (photocopy.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      photocopy.notes,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(photocopy),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bgColor;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange[700]!;
        bgColor = Colors.orange[50]!;
        text = 'Beklemede';
        break;
      case 'processing':
        color = Colors.blue[700]!;
        bgColor = Colors.blue[50]!;
        text = 'İşleniyor';
        break;
      case 'completed':
        color = AppColors.successGreen;
        bgColor = AppColors.successGreen.withOpacity(0.1);
        text = 'Tamamlandı';
        break;
      case 'failed':
        color = AppColors.errorRed;
        bgColor = AppColors.errorRed.withOpacity(0.1);
        text = 'Başarısız';
        break;
      default:
        color = Colors.grey[700]!;
        bgColor = Colors.grey[100]!;
        text = 'Bilinmiyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPrice = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isPrice ? AppColors.successGreen : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Photocopy photocopy) {
    if (photocopy.status == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _cancelPhotocopy(photocopy),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: Text(
            'İptal Et',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.errorRed,
            side: const BorderSide(color: AppColors.errorRed),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (photocopy.status == 'completed') {
      final hasUrl = photocopy.downloadUrl != null;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _downloadPhotocopy(photocopy),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(
            'Dosyayı İndir',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasUrl ? AppColors.successGreen : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'tiff':
      case 'bmp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
