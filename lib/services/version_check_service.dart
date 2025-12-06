import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config kullanarak uygulama versiyonunu kontrol eden servis
class VersionCheckService {
  // Singleton pattern
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  // Sabitler
  static const String appPackageName = 'com.jupi.benimapp.benimmarketim_app';
  static const String androidMinVersionKey = 'android_min_version_code';
  static const String iosMinVersionKey = 'ios_min_version_code';

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;

  /// Firebase Remote Config'i başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Remote Config ayarları
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero, // Test için anlık fetch
        ),
      );

      // Default değerler
      await _remoteConfig!.setDefaults({
        androidMinVersionKey: 1,
        iosMinVersionKey: 1,
      });

      _isInitialized = true;
      debugPrint('VersionCheckService initialized');
    } catch (e) {
      debugPrint('VersionCheckService initialization error: $e');
    }
  }

  /// Versiyon kontrolü yap
  /// Returns: true = güncelleme gerekli, false = güncel, null = kontrol yapılamadı
  Future<bool?> checkVersion() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_remoteConfig == null) {
        return null;
      }

      // Mevcut uygulama versiyonunu al
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint('Package Info - Version: ${packageInfo.version}, BuildNumber: ${packageInfo.buildNumber}');
      
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      debugPrint('Parsed Current Build Number: $currentBuildNumber');

      // Firebase'den değerleri çek ve aktif et - timeout ile
      try {
        debugPrint('Fetching remote config...');
        await _remoteConfig!.fetchAndActivate().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Version check timeout - using defaults');
            return false; // Timeout durumunda default değerleri kullan
          },
        );
        debugPrint('Remote config fetch completed.');
      } catch (e) {
        debugPrint('Version check fetch error: $e - using defaults');
        // Hata durumunda default değerleri kullan, uygulama çalışmaya devam etsin
      }

      // Platforma göre minimum gerekli versiyonu al
      String configKey =
          Platform.isIOS ? iosMinVersionKey : androidMinVersionKey;
      final minRequiredVersion = _remoteConfig!.getInt(configKey);

      debugPrint('Config Key: $configKey');
      debugPrint('Minimum required version from Remote Config: $minRequiredVersion');

      // Karşılaştır
      if (currentBuildNumber < minRequiredVersion) {
        debugPrint(
            'Update required: $currentBuildNumber < $minRequiredVersion');
        return true; // Güncelleme gerekli
      } else {
        debugPrint('App is up to date (Current: $currentBuildNumber >= Min: $minRequiredVersion)');
        return false; // Güncel
      }
    } catch (e) {
      debugPrint('Version check error: $e');
      return null;
    }
  }

  /// Mağaza URL'ini al
  String getStoreUrl() {
    if (Platform.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=$appPackageName';
    } else if (Platform.isIOS) {
      // App Store ID'nizi buraya ekleyin
      // Örnek: https://apps.apple.com/app/id123456789
      return 'https://apps.apple.com/app/id6738341165';
    }
    return '';
  }
}
