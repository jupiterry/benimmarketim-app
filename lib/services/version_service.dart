import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

class VersionService {
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.jupi.benimapp.benimmarketim_app';

  // Backend'den gelen minimum sürüm bilgisi
  static String? _minimumVersion;
  static String? _currentVersion;
  static String? _latestVersion;
  static String? _updateMessage;
  static String? _storeUrl;
  static bool _forceUpdate = false;

  // Uygulama sürümünü kontrol et
  static Future<bool> checkVersion() async {
    try {
      // Mevcut uygulama sürümünü al
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      print('Mevcut sürüm: $_currentVersion');

      // Backend'den minimum sürüm bilgisini al
      await _fetchVersionInfo();

      if (_minimumVersion == null) {
        print('Sürüm bilgisi alınamadı, uygulama çalışmaya devam ediyor');
        return true; // Sürüm kontrolü yapılamadı, uygulamaya izin ver
      }

      // Sürüm karşılaştırması
      final isSupported = _isVersionSupported(
        _currentVersion!,
        _minimumVersion!,
      );

      // Eğer forceUpdate flag'i true ise ve versiyon desteklenmiyorsa false dön
      if (_forceUpdate && !isSupported) {
        return false;
      }

      // Sadece versiyon kontrolü (eski mantık)
      return isSupported;
    } catch (e) {
      print('Sürüm kontrolü hatası: $e');
      return true; // Hata durumunda uygulamaya izin ver
    }
  }

  // Backend'den sürüm bilgilerini al
  static Future<void> _fetchVersionInfo() async {
    try {
      // Backend API'den sürüm bilgilerini al
      final dio = Dio();
      // Platform kontrolü (Android/iOS)
      final platform = Platform.isAndroid ? 'android' : 'ios';

      // Timeout ekle
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);

      final response = await dio.get(
        'https://devrekbenimmarketim.com/api/app/version',
        queryParameters: {'platform': platform},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _minimumVersion = data['minimumVersion'];
        _latestVersion = data['latestVersion'];
        _forceUpdate = data['forceUpdate'] ?? false;
        _updateMessage = data['updateMessage'];
        _storeUrl = data['storeUrl'];

        print('Backend\'den sürüm bilgileri alındı:');
        print('Minimum sürüm: $_minimumVersion');
        print('En son sürüm: $_latestVersion');
        print('Zorunlu güncelleme: $_forceUpdate');
      } else {
        throw Exception('Sürüm bilgisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Backend sürüm kontrolü hatası: $e');
      // API henüz hazır değilse veya hata varsa varsayılan değerler
      // Bu kısım API hazır olduğunda kaldırılabilir veya loglanabilir
    }
  }

  // Sürüm karşılaştırması
  static bool _isVersionSupported(
    String currentVersion,
    String minimumVersion,
  ) {
    try {
      final current = _parseVersion(currentVersion);
      final minimum = _parseVersion(minimumVersion);

      // Major.Minor.Patch formatında karşılaştırma
      for (int i = 0; i < 3; i++) {
        if (current[i] > minimum[i]) {
          return true; // Mevcut sürüm daha yeni
        } else if (current[i] < minimum[i]) {
          return false; // Mevcut sürüm daha eski
        }
      }

      return true; // Sürümler eşit
    } catch (e) {
      print('Versiyon karşılaştırma hatası: $e');
      return true; // Hata durumunda destekleniyor say
    }
  }

  // Sürüm string'ini parse et (1.0.0 -> [1, 0, 0])
  static List<int> _parseVersion(String version) {
    return version.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  }

  // Güncelleme gerekli mi kontrol et
  static bool get isUpdateRequired {
    if (_currentVersion == null || _minimumVersion == null) return false;
    return !_isVersionSupported(_currentVersion!, _minimumVersion!);
  }

  // En son sürüm mevcut mu kontrol et
  static bool get isLatestVersion {
    if (_currentVersion == null || _latestVersion == null) return true;
    return _isVersionSupported(_currentVersion!, _latestVersion!);
  }

  // Google Play Store'a yönlendir
  static Future<void> openPlayStore() async {
    try {
      final url = _storeUrl != null && _storeUrl!.isNotEmpty
          ? _storeUrl!
          : _playStoreUrl;

      // URL'yi clipboard'a kopyala
      await Clipboard.setData(ClipboardData(text: url));

      // Kullanıcıya bilgi ver
      print('Play Store URL\'si clipboard\'a kopyalandı: $url');
    } catch (e) {
      print('Play Store URL kopyalama hatası: $e');
    }
  }

  // Sürüm kontrol dialog'u göster
  static void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Kullanıcı dialog'u kapatamaz
      builder: (context) => PopScope(
        canPop: false, // Geri tuşunu engelle
        child: AlertDialog(
          title: Text(
            'Güncelleme Gerekli',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update, size: 64, color: Colors.orange[600]),
              const SizedBox(height: 16),
              Text(
                _updateMessage ??
                    'Uygulamanızın yeni sürümü mevcut. En iyi deneyim için lütfen güncelleyin.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mevcut Sürüm:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _currentVersion ?? 'Bilinmiyor',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gerekli Sürüm:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _minimumVersion ?? 'Bilinmiyor',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Uygulamayı kapat (Android)
                if (Platform.isAndroid) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              },
              child: Text(
                'Çıkış',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await openPlayStore();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Play Store URL\'si kopyalandı. Lütfen tarayıcıda açın.',
                      ),
                      backgroundColor: Colors.green[600],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Güncelle',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Güncelleme önerisi dialog'u göster
  static void showUpdateSuggestionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Güncelleme Mevcut',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.update, size: 64, color: Colors.blue[600]),
            const SizedBox(height: 16),
            Text(
              'Uygulamanızın yeni sürümü ($_latestVersion) mevcut. Güncellemek ister misiniz?',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Daha Sonra',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              context.pop();
              await openPlayStore();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Play Store URL\'si kopyalandı.'),
                    backgroundColor: Colors.blue[600],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Güncelle',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
