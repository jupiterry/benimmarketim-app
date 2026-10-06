# 6.0.0 (46) doğrulama kaydı

- Web commit: 697d416; deploy dalı GitHub'a gönderildi ve canlıya alındı.
- Backend: 98 test başarılı. Web derlemesi ve 20 sayfalık SEO kontrolü başarılı.
- Mobil: 11 test başarılı. Statik analizde 0 hata, 13 uyarı ve 114 bilgi düzeyi bulgu; analiz tamamen temiz değildir.
- Release AAB başarılı: versionName 6.0.0, versionCode 46, targetSdk 36.
- AAB imzası doğrulandı; sertifika önceki sürümle aynı.
- Sertifika SHA256: 14:86:64:46:9A:C3:1F:14:3B:7C:01:5C:4F:19:91:EC:8B:A4:F7:26:F1:69:1A:17:1C:A7:0F:E1:10:6C:12:CE.
- AAB SHA256: DACA5D96B8ABED587C11A0CA24547FB06F2A0738699005AAB0F6C2DB46957E0D.
- Canlı ana sayfa ve ürün API'si 200. Kayıtlı sepetler, görevler ve asistan giriş yapılmadan beklenen 401 yanıtını veriyor; 404 yok.
- Canlı sürüm ayarlarının dağıtım öncesi/sonrası yanıtları birebir aynı: latest=4.0.3, minimum=4.0.3, force_update=true.
- Sürüm kontrol servislerinde değişiklik yapılmadı.
- iOS IPA bu Windows ortamında üretilmedi. Codemagic ios-release çalıştırılmalı.
- Fiziksel cihaz, Apple derlemesi ve mağaza kabulü henüz doğrulanmadı. 16 KB cihaz testi Play Console/dahili test aşamasında yapılmalı.
