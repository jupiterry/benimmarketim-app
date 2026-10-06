# Doğrulama — 6 Ekim 2026

- Flutter 3.47.2 / Dart 3.13.2.
- Android release AAB derlemesi başarılı.
- Sürüm 5.0.0, derleme 45, hedef Android API 36.
- JAR imzası doğrulandı. Sertifika SHA-256 önceki 4.0.3 (44) AAB ile aynı:
  14:86:64:46:9A:C3:1F:14:3B:7C:01:5C:4F:19:91:EC:8B:A4:F7:26:F1:69:1A:17:1C:A7:0F:E1:10:6C:12:CE
- AAB SHA-256: 824E914E6B9F4F1FA2F130A09D671138C0EA5FDA1FA75E048773F940AE30CB89.
- arm64-v8a ve x86_64 içindeki 6 yerel kütüphanenin ELF LOAD hizalamaları en az 16 KB. Gerçek 16 KB cihaz ve Play Console testi yapılmadı.
- 11 Flutter testi başarılı.
- Statik analiz: 0 hata, 13 uyarı, 114 bilgi düzeyi bulgu. Analiz tamamen temiz değildir.
- Android derleme araçları ileride AGP/Kotlin yükseltmesi öneriyor; bu derleme başarıyla tamamlandı.
- iOS imzalı derlemesi bu Windows ortamında çalıştırılmadı; IPA teslim edilmiş değildir. Mevcut Codemagic ios-release akışı kullanılmalıdır.
- Kullanıcı Codemagic Apple bağlantısı/sertifikalarının aktif olduğunu bildirdi; hesap üzerinde bağımsız doğrulama yapılmadı.
- Gerçek cihaz, mağaza incelemesi, ekran görüntüsü ve uçtan uca sipariş testi yapılmadı.
- Güncelleme kontrol mantığı ve canlı sürüm ayarları bu çalışmada değiştirilmedi; önceden yapılmış mobil günlükleme/görsel değişiklikleri sürüme dahil edildi.
