import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';

class ConnectivityService {
  static Future<bool> hasInternetConnection() async {
    try {
      // Birden fazla DNS sunucusunu dene
      final List<String> testHosts = [
        'google.com',
        'cloudflare.com',
        '1.1.1.1', // Cloudflare DNS
        '8.8.8.8', // Google DNS
      ];
      
      for (String host in testHosts) {
        try {
          final result = await InternetAddress.lookup(host);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            AppLogger.debug('İnternet bağlantısı başarılı: $host');
            return true;
          }
        } catch (e) {
          AppLogger.debug('İnternet test hatası ($host): $e');
          continue;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.debug('İnternet bağlantısı genel hatası: $e');
      return false;
    }
  }

  static Future<bool> checkApiConnection() async {
    try {
      // API sunucusunu kontrol et
      final result = await InternetAddress.lookup('devrekbenimmarketim.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        AppLogger.debug('API sunucusu erişilebilir: devrekbenimmarketim.com');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.debug('API sunucusu erişim hatası: $e');
      return false;
    }
  }

  // Daha esnek internet kontrolü
  static Future<bool> hasBasicInternet() async {
    try {
      // En basit kontrol - sadece DNS çözümleme
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty;
    } catch (e) {
      // DNS başarısız olursa, IP adresini dene
      try {
        final result = await InternetAddress.lookup('8.8.8.8');
        return result.isNotEmpty;
      } catch (e2) {
        AppLogger.debug('Temel internet kontrolü başarısız: $e2');
        return false;
      }
    }
  }
}
