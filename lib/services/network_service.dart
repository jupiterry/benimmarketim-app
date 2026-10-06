import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';

class NetworkService {
  // HTTP isteği ile internet kontrolü
  static Future<bool> checkInternetWithHttp() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      
      final request = await client.getUrl(Uri.parse('https://httpbin.org/status/200'));
      final response = await request.close();
      
      client.close();
      
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.debug('HTTP internet kontrolü başarısız: $e');
      return false;
    }
  }

  // Ping benzeri kontrol
  static Future<bool> checkInternetWithPing() async {
    try {
      final result = await Process.run('ping', ['-c', '1', '8.8.8.8']);
      return result.exitCode == 0;
    } catch (e) {
      AppLogger.debug('Ping internet kontrolü başarısız: $e');
      return false;
    }
  }

  // Çoklu kontrol yöntemi
  static Future<bool> hasInternetConnection() async {
    try {
      // 1. DNS lookup kontrolü
      final dnsResult = await InternetAddress.lookup('google.com');
      if (dnsResult.isNotEmpty) {
        AppLogger.debug('DNS lookup başarılı');
        return true;
      }
    } catch (e) {
      AppLogger.debug('DNS lookup başarısız: $e');
    }

    try {
      // 2. HTTP isteği kontrolü
      final httpResult = await checkInternetWithHttp();
      if (httpResult) {
        AppLogger.debug('HTTP kontrolü başarılı');
        return true;
      }
    } catch (e) {
      AppLogger.debug('HTTP kontrolü başarısız: $e');
    }

    try {
      // 3. IP adresi kontrolü
      final ipResult = await InternetAddress.lookup('8.8.8.8');
      if (ipResult.isNotEmpty) {
        AppLogger.debug('IP adresi kontrolü başarılı');
        return true;
      }
    } catch (e) {
      AppLogger.debug('IP adresi kontrolü başarısız: $e');
    }

    AppLogger.debug('Tüm internet kontrol yöntemleri başarısız');
    return false;
  }
}
