import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photocopy.dart';
import 'api_service.dart';
import 'app_logger.dart';

/// Fotokopi uç noktaları (sunucu: routes/photocopy.route.js):
///   POST   /photocopy/upload        (multipart: file, copies, color, paperSize, notes)
///   GET    /photocopy/my-files      → { success, data: [...] }
///   GET    /photocopy/download/:id  → dosya
///   DELETE /photocopy/:id           → { success, message }
/// İstekler ApiService'in paylaşılan Dio'su üzerinden gider; böylece token
/// başlığı ve 401'de yenileme tek yerden yönetilir.
class PhotocopyService {
  static Dio get _dio => ApiService.sharedDio;

  /// Sunucunun kabul ettiği türler ve boyut sınırı (multer ayarıyla aynı)
  static const Set<String> allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'};
  static const int maxFileSizeBytes = 20 * 1024 * 1024;

  static ApiException _toApiException(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return ApiException(data['message'] as String, statusCode: e.response?.statusCode);
    }
    if (e.response?.statusCode == 401) {
      return const ApiException('Oturumunun süresi dolmuş. Lütfen tekrar giriş yap.', statusCode: 401);
    }
    if (e.response == null) {
      return const ApiException('Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.');
    }
    return ApiException(fallback, statusCode: e.response?.statusCode);
  }

  static Future<List<Photocopy>> getPhotocopyHistory() async {
    try {
      final response = await _dio.get('/photocopy/my-files');
      // API yanıtı dizi ya da { data: [] } olabilir
      final dynamic raw = response.data;
      final List<dynamic> data = raw is List
          ? raw
          : (raw is Map && raw['data'] is List)
              ? raw['data']
              : <dynamic>[];
      return data
          .whereType<Map>()
          .map((json) => Photocopy.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e, 'Fotokopi geçmişi alınamadı.');
    }
  }

  static Future<Photocopy> uploadFile({
    required File file,
    required int copies,
    required String color,
    required String paperSize,
    String notes = '',
  }) async {
    // Dosya adını al
    final fileName = file.path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();

    // Desteklenen dosya türlerini kontrol et (sunucuyla aynı liste)
    if (!allowedExtensions.contains(fileExtension)) {
      throw const ApiException('Yalnızca PDF, JPG, PNG, DOC ve DOCX yüklenebilir.');
    }

    // Dosya boyutunu kontrol et (sunucu sınırı 20 MB)
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      throw const ApiException('Dosya en fazla 20 MB olabilir.');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'copies': copies,
        'color': color,
        'paperSize': paperSize,
        'notes': notes,
      });

      final response = await _dio.post(
        '/photocopy/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      final data = response.data;
      final doc = data is Map ? (data['data'] ?? data) : null;
      if (doc is Map) {
        return Photocopy.fromJson(Map<String, dynamic>.from(doc));
      }
      throw const ApiException('Dosya yüklendi ama yanıt okunamadı.');
    } on DioException catch (e) {
      AppLogger.debug('Fotokopi yükleme hatası: $e');
      if (e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ApiException('Yükleme zaman aşımına uğradı. Lütfen tekrar dene.');
      }
      if (e.response?.statusCode == 413) {
        throw const ApiException('Dosya en fazla 20 MB olabilir.', statusCode: 413);
      }
      throw _toApiException(e, 'Dosya yüklenemedi. Lütfen tekrar dene.');
    }
  }

  /// İsteği siler (sunucu dosyayı da kaldırır).
  static Future<void> cancelPhotocopy(String id) async {
    try {
      await _dio.delete('/photocopy/$id');
    } on DioException catch (e) {
      throw _toApiException(e, 'Fotokopi isteği iptal edilemedi.');
    }
  }

  /// Yüklenen dosyayı uygulama belgeler klasörüne indirir; yolu döndürür.
  static Future<String> downloadPhotocopy(Photocopy photocopy) async {
    try {
      final response = await _dio.get<List<int>>(
        '/photocopy/download/${photocopy.id}',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final bytes = response.data;
      if (bytes == null) {
        throw const ApiException('Dosya indirilemedi.');
      }
      final directory = await getApplicationDocumentsDirectory();
      final safeName = photocopy.originalName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      final filePath =
          '${directory.path}/photocopy_${photocopy.id}${safeName.isEmpty ? '' : '_$safeName'}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } on DioException catch (e) {
      throw _toApiException(e, 'Dosya indirilemedi.');
    }
  }
}
