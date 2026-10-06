# Benim Marketim 5.0.0 — mağaza yükleme paketi

Hazırlanma: 6 Ekim 2026

## Sürüm
- Görünen sürüm: **5.0.0**
- Android versionCode / iOS build: **45**
- Önceki yerel sürüm: 4.0.3 (44).
- Mağazalarda 45 veya daha yüksek bir derleme kullanılmışsa, yüklemeden önce en yüksek numara + 1 ile yeniden derleyin.
- Canlı güncelleme ayarları değiştirilmedi: latestVersion=4.0.3, minimumVersion=4.0.3, forceUpdate=true.
- 5.0.0 her iki mağazada kullanıcılara açıldıktan sonra latestVersion=5.0.0 düşünülebilir. Minimum sürümü 5.0.0 yapmak eski uygulamaları engeller; ayrıca karar verilmelidir. Mevcut mobil sürüm kontrolü latestVersion artışını da zorunlu güncelleme olarak ele alıyor. Bu nedenle mağaza yayını tamamlanmadan sunucu sürümünü artırmayın.

## Google Play
1. Mevcut Benim Marketim uygulamasını açın; yeni uygulama kaydı oluşturmayın.
2. Paket kimliği: com.jupi.benimapp.benimmarketim_app.
3. Önce dahili test kanalına releases/benimmarketim-5.0.0-build45.aab yükleyin.
4. Play Console imza anahtarı, versionCode, hedef API ve 16 KB sayfa uyumluluğu doğrulamalarını kontrol edin.
5. Gerçek cihazda giriş, kayıt, ürün arama, sepet, sipariş, bildirim tercihleri, fotokopi yükleme ve hesap silme akışlarını deneyin. Gerçek sipariş testini mağazayla koordine edin.
6. Türkçe sürüm notunu release-notes-tr.txt dosyasından ekleyin.
7. Veri güvenliği, uygulama erişimi, reklam, içerik derecelendirmesi ve hedef kitle formlarını güncel işleyişe göre tamamlayın.
8. Mevcut mağaza ekran görüntüleri yeni arayüzü yansıtmıyorsa gerçek cihazdan yenileyin.
9. Testten sonra üretim sürümü oluşturup incelemeye gönderin. Mağaza onayı ayrıca gerekir.

Gizlilik: https://devrekbenimmarketim.com/privacy
Hesap silme: https://devrekbenimmarketim.com/account-deletion
Destek: https://devrekbenimmarketim.com/contact

## iOS / App Store Connect
Windows ortamında imzalı IPA üretilemez; mevcut Codemagic ios-release iş akışı kullanılmalıdır.
- GitHub deposu: jupiterry/benimmarketim-app, dal: main.
- Sürüm: 5.0.0 (45).
- Bundle ID: com.jupi.benimmarketim.
- App Store Apple ID: 6755792336.
- Codemagic Apple bağlantısı: CodeMagic2.
- Ortam grubu: app_store_credentials.
- Team settings > Code signing identities altında bu Bundle ID ile eşleşen geçerli Apple Distribution sertifikası ve App Store provisioning profile bulunmalıdır.
- ios-release akışını başlatın. Akış testleri çalıştırır, imzalı IPA oluşturur ve mevcut ayarıyla TestFlight'a yükler.
- Xcode latest seçili; kullanılan sürüm en az Xcode 26 / iOS 26 SDK olmalı.
- IPA çıktısı: build/ios/ipa/*.ipa. Codemagic artifacts bölümünden indirilebilir.
- İmzasız ios-test-build çıktısı .app dosyasıdır; App Store'a yüklenemez.
- App Store Connect'te 5.0.0 sürümünü oluşturun, işlenen build 45'i seçin, sürüm notlarını ve inceleme bilgilerini ekleyin.
- İnceleme için çalışan müşteri test hesabı ve Devrek hizmet bölgesi açıklaması sağlayın. Bu hazırlıkta yeni hesap oluşturulmadı.
- Güncel yaş derecelendirme sorularını ve App Privacy beyanlarını tamamlayın; TestFlight'ta gerçek iPhone üzerinde sınayın.
- App Store incelemesine gönderme/yayınlama bu görevde yapılmadı.

## Veri beyanı için koddan görülen alanlar
Bu liste nihai mağaza beyanı değildir; servis sağlayıcılarının gerçek ayarlarıyla doğrulayın.
- Kimlik/iletişim: ad, e-posta, telefon, teslimat adresi, hesap kimliği.
- Satın alma: sipariş ve satın alma geçmişi.
- Kullanıcı içeriği: destek mesajları, yüklenen fotoğraf/belgeler.
- Bildirimler: OneSignal kullanıcı/abonelik ve cihaz tanımlayıcıları.
- Amaçlar: hesap yönetimi, sipariş/teslimat, destek, bildirimler.
- Sunucu, dosya saklama, bildirim ve varsa ödeme sağlayıcılarının veri işlemesini beyanlara dahil edin.
- Takip/reklam/konum/analitik alanlarını varsayımla doldurmayın; aktif SDK ve sağlayıcı ayarlarını doğrulayın.
- Hesap silme uygulamada profil/ayarlar üzerinden sunuluyor. Web bağlantısı da mevcut.

## İmzalama
Mevcut Android anahtarı korunmuştur. Parolalar android/key.properties içinde yereldir ve Git'e eklenmez.
Örnek dosya: android/key.properties.example.
Mevcut uygulama için yeni anahtar üretmeyin. Git geçmişinde eski imzalama parolası bulunabileceğinden anahtarın güvenliğini ayrıca değerlendirin; bu işlemde geçmiş yeniden yazılmadı ve anahtar değiştirilmedi.

## Kaynaklar
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/guide/practices/page-sizes
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- https://developer.apple.com/app-store/app-privacy-details/
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
