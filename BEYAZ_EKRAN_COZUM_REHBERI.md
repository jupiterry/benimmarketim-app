# Beyaz Ekran Sorunu - Çözüm Rehberi

## ✅ Yapılan Düzeltmeler

### 1. **Info.plist - App Transport Security (ATS) Ayarları**
- ATS yapılandırması eklendi
- `devrekbenimmarketim.com` için özel domain ayarları
- Network izinleri eklendi

### 2. **main.dart - Gelişmiş Hata Yakalama**
- ✅ Tüm initialization işlemleri try-catch ile korundu
- ✅ Firebase, TokenManager, Analytics başlatma hataları yakalanıyor
- ✅ Global error handler eklendi (`FlutterError.onError`)
- ✅ Error widget builder eklendi (hata durumunda kullanıcı dostu ekran)
- ✅ Version check timeout eklendi (15 saniye)

### 3. **Version Check Service - Timeout Koruması**
- ✅ `fetchAndActivate()` için 10 saniye timeout
- ✅ Timeout durumunda default değerler kullanılıyor
- ✅ Hata durumunda uygulama çalışmaya devam ediyor

### 4. **Router - Fallback Route**
- ✅ Error builder eklendi
- ✅ Hata durumunda SplashScreen'e yönlendirme

## 🔍 Debug Yöntemleri

### Xcode ile Debug

1. **Xcode'da Projeyi Açın:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Debug Modda Çalıştırın:**
   - Xcode'da "Run" butonuna tıklayın
   - Console'u açın (View → Debug Area → Activate Console)
   - Logları kontrol edin

3. **Kontrol Edilecek Loglar:**
   - `✅ Firebase initialized` - Firebase başarılı mı?
   - `✅ TokenManager initialized` - TokenManager başarılı mı?
   - `⚠️ Version check timeout` - Version check timeout oldu mu?
   - `❌ Flutter Error:` - Herhangi bir Flutter hatası var mı?

### TestFlight'tan Debug

TestFlight'tan indirilen uygulamada log görmek için:

1. **Xcode → Window → Devices and Simulators**
2. Cihazınızı seçin
3. "Open Console" butonuna tıklayın
4. Uygulamayı açın ve logları izleyin

### Codemagic Build Logları

1. Codemagic dashboard'a gidin
2. Build detaylarına tıklayın
3. "Build logs" sekmesini kontrol edin
4. Şu uyarıları arayın:
   - Asset eksikliği
   - Pod install hataları
   - Code signing sorunları
   - Flutter build hataları

## 🛠️ Olası Sorunlar ve Çözümleri

### Sorun 1: Firebase Initialization Hatası

**Belirtiler:**
- Console'da `⚠️ Firebase initialization failed` görünüyor
- `GoogleService-Info.plist` eksik veya hatalı

**Çözüm:**
1. `ios/Runner/GoogleService-Info.plist` dosyasının varlığını kontrol edin
2. Firebase Console'dan doğru dosyayı indirin
3. Codemagic'te environment variable olarak ekleyin veya dosyayı repo'ya ekleyin

### Sorun 2: Network Timeout

**Belirtiler:**
- Version check timeout oluyor
- API çağrıları başarısız

**Çözüm:**
1. Info.plist'te ATS ayarlarını kontrol edin (✅ Yapıldı)
2. API base URL'inin doğru olduğundan emin olun
3. Network bağlantısını test edin

### Sorun 3: Asset Eksikliği

**Belirtiler:**
- `assets/logo.png` bulunamıyor hatası
- Splash screen görünmüyor

**Çözüm:**
1. `pubspec.yaml`'da asset'lerin tanımlı olduğundan emin olun
2. `flutter pub get` çalıştırın
3. `flutter clean` ve yeniden build edin

### Sorun 4: SSL Certificate Hatası

**Belirtiler:**
- API çağrıları SSL hatası veriyor
- `badCertificateCallback` çalışmıyor

**Çözüm:**
1. `lib/services/api_service.dart`'ta SSL pinning'i kontrol edin
2. Production'da sertifika değişmiş olabilir
3. Geçici olarak SSL pinning'i devre dışı bırakabilirsiniz (güvenlik riski!)

## 📋 Test Checklist

Yeni build'i test ederken kontrol edin:

- [ ] Uygulama açılıyor mu? (Beyaz ekran yok mu?)
- [ ] Splash screen görünüyor mu?
- [ ] Firebase başlatılıyor mu? (Console logları)
- [ ] Version check çalışıyor mu? (Timeout olmamalı)
- [ ] Ana sayfa yükleniyor mu?
- [ ] Network istekleri başarılı mı?

## 🚀 Yeni Build Oluşturma

### Codemagic'te:

1. **Değişiklikleri commit edin:**
   ```bash
   git add .
   git commit -m "Fix: Beyaz ekran sorunu düzeltmeleri"
   git push
   ```

2. **Codemagic'te yeni build başlatın:**
   - `ios-release` workflow'unu çalıştırın
   - Build loglarını izleyin

3. **TestFlight'a yüklendikten sonra:**
   - Uygulamayı silin ve yeniden yükleyin
   - Telefonu yeniden başlatın (opsiyonel)
   - Uygulamayı açın ve logları kontrol edin

### Lokal Test:

```bash
# Temizle
flutter clean

# Bağımlılıkları yükle
flutter pub get

# iOS build
flutter build ios --release

# Xcode'da aç ve test et
open ios/Runner.xcworkspace
```

## 📊 Log Analizi

### Başarılı Başlatma Logları:
```
✅ Firebase initialized
✅ TokenManager initialized
✅ Firebase Analytics initialized
✅ Firebase Performance initialized
Current build number: 15
App is up to date
```

### Hata Durumu Logları:
```
⚠️ Firebase initialization failed: [hata mesajı]
⚠️ Version check timeout - skipping
❌ Flutter Error: [hata detayları]
```

## 🔗 İlgili Dosyalar

- `lib/main.dart` - Ana başlatma kodu
- `ios/Runner/Info.plist` - iOS yapılandırması
- `lib/services/version_check_service.dart` - Versiyon kontrolü
- `lib/router/app_router.dart` - Router yapılandırması
- `codemagic.yaml` - CI/CD yapılandırması

## 💡 Ek Öneriler

1. **Crash Reporting:**
   - Firebase Crashlytics'i aktif edin
   - Production hatalarını takip edin

2. **Analytics:**
   - Firebase Analytics ile kullanıcı davranışlarını izleyin
   - Hangi ekranda takıldıklarını görün

3. **Remote Config:**
   - Kritik ayarları Remote Config'e taşıyın
   - Uygulama güncellemesi olmadan düzeltebilirsiniz

4. **Test Coverage:**
   - Unit testler ekleyin
   - Widget testleri yazın
   - Integration testleri yapın

## 🆘 Hala Sorun Varsa

1. **Xcode Console loglarını paylaşın**
2. **Codemagic build loglarını kontrol edin**
3. **TestFlight crash loglarını kontrol edin:**
   - Xcode → Window → Organizer
   - Crashes sekmesi

4. **Firebase Crashlytics'i kontrol edin:**
   - Firebase Console → Crashlytics
   - Son crash'leri inceleyin

