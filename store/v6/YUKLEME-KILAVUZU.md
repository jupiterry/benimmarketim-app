# Benim Marketim 6.0.0 (46) — yükleme kılavuzu

6 Ekim 2026. Android ve iOS sürümünün tek kaynağı pubspec.yaml: 6.0.0+46.
Açılış, profil, ayarlar ve yenilikler ekranı paket sürümünü kullanır.
Eski store/v5 belgeleri geçmiş sürüm kaydıdır; yeni teslim store/v6 klasöründedir.

## Google Play
1. Mevcut Benim Marketim uygulamasını açın: com.jupi.benimapp.benimmarketim_app.
2. Önce dahili test kanalına benimmarketim-6.0.0-build46.aab yükleyin.
3. Sürüm adı 6.0.0, versionCode 46 olmalı. 46 mağazada daha önce kullanıldıysa yeniden derleme gerekir.
4. release-notes-tr.txt içeriğini sürüm notuna ekleyin.
5. Test cihazında giriş, sepet asistanı, kayıtlı sepetler, sipariş, görevler, bildirimler ve hesap silmeyi sınayın. Siparişler canlı sisteme kaydolur; mağazayla koordine edin.
6. Veri güvenliği ve uygulama erişimi bilgilerini kontrol edin, sonra üretim incelemesine gönderin.
7. APK dosyası doğrudan cihaz testi içindir; Play yüklemesinde AAB kullanın.

## iOS / Codemagic
- GitHub: jupiterry/benimmarketim-app, main dalı, ios-release iş akışı.
- Bundle ID: com.jupi.benimmarketim. Apple ID: 6755792336.
- Apple bağlantısı: CodeMagic2; mevcut sertifika ve profilleri kullanın.
- ios-release iş akışı pubspec.yaml'dan 6.0.0 (46) alır; imzalı IPA üretip App Store Connect'e yükler.
- IPA: Codemagic artifacts içindeki build/ios/ipa/*.ipa.
- Bu Windows bilgisayarında IPA üretilemez. Codemagic derlemesi ayrıca başlatılmalıdır; yerel Android derlemesinin başarılı olması iOS doğrulaması değildir.
- Önceki yüklemede Apple paketi kabul etmiş, dış test başvurusu eksik iletişim alanları nedeniyle durmuştu. https://appstoreconnect.apple.com/apps/6755792336/testflight/test-info adresinde Feedback Email, First Name, Last Name, Phone Number ve Email alanlarını doldurun. Not metnine yazmak bu alanların yerini tutmaz.
- App Store Connect'te 6.0.0 sürümünü oluşturun, işlenen build 46'yı seçin. Çalışan inceleme hesabı, güncel ekran görüntüleri, gizlilik ve yaş derecelendirmesi bilgilerini tamamlayın.
- TestFlight'ta fiziksel iPhone testi sonrası incelemeye gönderin. Mağaza yayını bu hazırlık sırasında yapılmadı.

## Bağlantılar
- Gizlilik: https://devrekbenimmarketim.com/privacy
- Hesap silme: https://devrekbenimmarketim.com/account-deletion
- Destek: https://devrekbenimmarketim.com/contact

## Sürüm kontrolü — şimdilik değiştirmeyin
Canlı latestVersion, minimumVersion ve forceUpdate değerlerine bu yayında dokunulmadı.
Yeni mobil sürüm 6.0.0, derleme 46'dır. Sunucu sürüm alanına ileride **6.0.0** yazılır; **6.0.0+46** yazılmaz.
Her iki mağazada yayın tamamlanınca latestVersion=6.0.0 değerlendirilebilir.
minimumVersion=6.0.0 eski sürümleri engeller; ayrı karar verilmelidir.
Mevcut mobil kontrol latestVersion artışını da zorunlu güncelleme sayar; mağazalarda erişilebilir olmadan artırmayın.

## İmzalama ve kalan kontroller
Android için mevcut anahtar korunur; android/key.properties ve keystore Git'e gönderilmez.
Mağaza ekran görüntüleri, gerçek cihaz testi, gizlilik beyanları ve inceleme hesabının çalışması yükleme öncesi doğrulanmalıdır.
Görev kartının görünmesi panelde aktif ve tarihleri geçerli bir görev bulunmasına bağlıdır.

Resmî kaynaklar:
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
