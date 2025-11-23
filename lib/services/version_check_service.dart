import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Firebase Remote Config kullanarak uygulama versiyonunu kontrol eden servis
class VersionCheckService {
  // Singleton pattern
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  // Sabitler
  static const String appPackageName = 'com.jupi.benimapp.benimmarketim';
  static const String minVersionKey = 'android_min_version_code';

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
          minimumFetchInterval: const Duration(hours: 1), // Canlıda 1 saat
        ),
      );

      // Default değerler
      await _remoteConfig!.setDefaults({
        minVersionKey: 10, // Mevcut minimum versiyon
      });

      _isInitialized = true;
      print('VersionCheckService initialized');
    } catch (e) {
      print('VersionCheckService initialization error: $e');
      // Hata olsa bile uygulama çalışmaya devam etsin
    }
  }

  /// Versiyon kontrolü yap
  /// Returns: true = güncelleme gerekli, false = güncel, null = kontrol yapılamadı
  Future<bool?> checkVersion() async {
    try {
      // Firebase'i başlat
      if (!_isInitialized) {
        await initialize();
      }

      if (_remoteConfig == null) {
        print('Remote Config not initialized');
        return null;
      }

      // Mevcut uygulama versiyonunu al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      print('Current build number: $currentBuildNumber');

      // Firebase'den değerleri çek ve aktif et
      await _remoteConfig!.fetchAndActivate();

      // Minimum gerekli versiyonu al
      final minRequiredVersion = _remoteConfig!.getInt(minVersionKey);
      print('Minimum required version: $minRequiredVersion');

      // Karşılaştır
      if (currentBuildNumber < minRequiredVersion) {
        print('Update required: $currentBuildNumber < $minRequiredVersion');
        return true; // Güncelleme gerekli
      } else {
        print('App is up to date');
        return false; // Güncel
      }
    } catch (e) {
      print('Version check error: $e');
      // Hata durumunda kullanıcıyı engelleme
      return null;
    }
  }

  /// Play Store URL'ini al
  String getPlayStoreUrl() {
    if (Platform.isAndroid) {
      return 'market://details?id=$appPackageName';
    } else if (Platform.isIOS) {
      // iOS için App Store ID'si gerekirse buraya eklenebilir
      return 'https://apps.apple.com/app/id0000000000';
    }
    return 'https://play.google.com/store/apps/details?id=$appPackageName';
  }

  /// Web Play Store URL'ini al (market:// açılmazsa)
  String getWebPlayStoreUrl() {
    return 'https://play.google.com/store/apps/details?id=$appPackageName';
  }
}
