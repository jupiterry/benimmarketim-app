import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';
import 'app_logger.dart';

class VersionCheckResult {
  final bool isUpdateRequired;
  final bool isMandatory;
  final String storeUrl;
  final String latestVersion;
  final String currentVersion;

  VersionCheckResult({
    required this.isUpdateRequired,
    required this.isMandatory,
    required this.storeUrl,
    required this.latestVersion,
    required this.currentVersion,
  });
}

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  final Dio _dio = Dio();
  // API Endpoint - Bu adres sunucunuzda tanımlı olmalı
  static const String _apiUrl = 'https://devrekbenimmarketim.com/api/version-check';

  Future<VersionCheckResult?> checkVersion() async {
    try {
      // 1. Mevcut sürümü al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;
      final currentVersion = Version.parse(currentVersionStr);

      AppLogger.debug('Current App Version: $currentVersionStr');

      // 2. API'den en son sürüm bilgisini çek
      // Platform'a göre parametre gönderiyoruz (ios/android)
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      Map<String, dynamic> data;
      try {
         final response = await _dio.get(
          _apiUrl,
          queryParameters: {'platform': platform},
          options: Options(
            responseType: ResponseType.json, 
            sendTimeout: const Duration(seconds: 10), // Timeout biraz artırıldı
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        data = response.data;
      } catch (e) {
        AppLogger.debug('API Error: $e');
        // API hatası durumunda (internetsiz vs) null dönerek uygulamanın açılmasını engellemeyelim
        return null;
      }

      final latestVersionStr = data['latest_version'] as String;
      final minVersionStr = data['minimum_version'] as String;
      final storeUrl = data['url'] as String;

      final latestVersion = Version.parse(latestVersionStr);
      final minVersion = Version.parse(minVersionStr);

      AppLogger.debug('Latest Version: $latestVersionStr');
      AppLogger.debug('Min Version: $minVersionStr');

      // 3. Karşılaştırma Mantığı
      bool isUpdateRequired = false;
      bool isMandatory = false;

      if (currentVersion < minVersion) {
        // Mevcut sürüm minimum sürümden küçük -> ZORUNLU GÜNCELLEME
        isUpdateRequired = true;
        isMandatory = true;
        AppLogger.debug('Status: Mandatory Update Required');
      } else if (currentVersion < latestVersion) {
        // Mevcut sürüm son sürümden küçük -> KULLANICI İSTEĞİ: HER GÜNCELLEME ZORUNLU
        isUpdateRequired = true;
        isMandatory = true; // Artık hepsi zorunlu
        AppLogger.debug('Status: Update Available (Mandatory)');
      } else {
        AppLogger.debug('Status: App is Up to Date');
      }

      return VersionCheckResult(
        isUpdateRequired: isUpdateRequired,
        isMandatory: isMandatory,
        storeUrl: storeUrl,
        latestVersion: latestVersionStr,
        currentVersion: currentVersionStr,
      );

    } catch (e) {
      AppLogger.debug('Version Check Error: $e');
      return null;
    }
  }
}
