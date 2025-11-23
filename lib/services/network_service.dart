import 'dart:io';
import 'package:flutter/foundation.dart';

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
      print('HTTP internet kontrolü başarısız: $e');
      return false;
    }
  }

  // Ping benzeri kontrol
  static Future<bool> checkInternetWithPing() async {
    try {
      final result = await Process.run('ping', ['-c', '1', '8.8.8.8']);
      return result.exitCode == 0;
    } catch (e) {
      print('Ping internet kontrolü başarısız: $e');
      return false;
    }
  }

  // Çoklu kontrol yöntemi
  static Future<bool> hasInternetConnection() async {
    try {
      // 1. DNS lookup kontrolü
      final dnsResult = await InternetAddress.lookup('google.com');
      if (dnsResult.isNotEmpty) {
        print('DNS lookup başarılı');
        return true;
      }
    } catch (e) {
      print('DNS lookup başarısız: $e');
    }

    try {
      // 2. HTTP isteği kontrolü
      final httpResult = await checkInternetWithHttp();
      if (httpResult) {
        print('HTTP kontrolü başarılı');
        return true;
      }
    } catch (e) {
      print('HTTP kontrolü başarısız: $e');
    }

    try {
      // 3. IP adresi kontrolü
      final ipResult = await InternetAddress.lookup('8.8.8.8');
      if (ipResult.isNotEmpty) {
        print('IP adresi kontrolü başarılı');
        return true;
      }
    } catch (e) {
      print('IP adresi kontrolü başarısız: $e');
    }

    print('Tüm internet kontrol yöntemleri başarısız');
    return false;
  }
}
