import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photocopy.dart';
import 'token_manager.dart';

class PhotocopyService {
  static const String baseUrl = 'https://www.devrekbenimmarketim.com/api';
  static final Dio _dio = Dio();

  static Future<List<Photocopy>> getPhotocopyHistory() async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await _dio.get(
        '$baseUrl/photocopy/my-files',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // API yanıtı dizi ya da { data: [] } olabilir
        final dynamic raw = response.data;
        final List<dynamic> data = raw is List
            ? raw
            : (raw is Map && raw['data'] is List)
                ? raw['data']
                : <dynamic>[];
        return data.map((json) => Photocopy.fromJson(json)).toList();
      } else {
        throw Exception('Fotokopi geçmişi alınamadı: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Fotokopi geçmişi alınırken hata oluştu: $e');
    }
  }

  static Future<Photocopy> uploadFile({
    required File file,
    required int copies,
    required String color,
    required String paperSize,
    String notes = '',
  }) async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      // Dosya adını al
      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();

      // Desteklenen dosya türlerini kontrol et
      if (!['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'tiff', 'bmp'].contains(fileExtension)) {
        throw Exception('Desteklenmeyen dosya türü: $fileExtension');
      }

      // Dosya boyutunu kontrol et (50MB limit)
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Dosya boyutu çok büyük. Maksimum 50MB olmalıdır.');
      }

      // FormData oluştur
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'copies': copies,
        'color': color,
        'paperSize': paperSize,
        'notes': notes,
      });

      final response = await _dio.post(
        '$baseUrl/photocopy/upload',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(minutes: 5), // 5 dakika timeout
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Photocopy.fromJson(response.data['data']);
      } else {
        throw Exception('Dosya yüklenemedi: ${response.statusMessage}');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          throw Exception('Bağlantı zaman aşımı. Lütfen tekrar deneyin.');
        } else if (e.type == DioExceptionType.receiveTimeout) {
          throw Exception('Sunucu yanıt vermiyor. Lütfen tekrar deneyin.');
        } else if (e.response?.statusCode == 413) {
          throw Exception('Dosya boyutu çok büyük.');
        } else if (e.response?.statusCode == 415) {
          throw Exception('Desteklenmeyen dosya türü.');
        }
      }
      throw Exception('Dosya yüklenirken hata oluştu: $e');
    }
  }

  static Future<Photocopy> getPhotocopyDetails(String id) async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await _dio.get(
        '$baseUrl/photocopy/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return Photocopy.fromJson(response.data['data']);
      } else {
        throw Exception('Fotokopi detayları alınamadı: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Fotokopi detayları alınırken hata oluştu: $e');
    }
  }

  static Future<void> cancelPhotocopy(String id) async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await _dio.delete(
        '$baseUrl/photocopy/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Fotokopi iptal edilemedi: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Fotokopi iptal edilirken hata oluştu: $e');
    }
  }

  static Future<String> downloadPhotocopy(String id) async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await _dio.get(
        '$baseUrl/photocopy/download/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200) {
        // Dosyayı yerel depolamaya kaydet
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/photocopy_$id.pdf';
        final file = File(filePath);
        await file.writeAsBytes(response.data);
        return filePath;
      } else {
        throw Exception('Dosya indirilemedi: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Dosya indirilirken hata oluştu: $e');
    }
  }

  static Future<Map<String, dynamic>> getPhotocopyPricing() async {
    try {
      final response = await _dio.get('$baseUrl/photocopy/pricing');
      
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Fiyatlandırma bilgileri alınamadı: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Fiyatlandırma bilgileri alınırken hata oluştu: $e');
    }
  }

  static Future<bool> checkPhotocopyStatus(String id) async {
    try {
      final token = await TokenManager.getAccessToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await _dio.get(
        '$baseUrl/photocopy/$id/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data']['isCompleted'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
