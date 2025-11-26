# Windows'ta iOS Debug Rehberi (Xcode Olmadan)

Xcode'unuz olmadığı için iOS simülasyonu yapamıyoruz, ancak sorunları tespit etmek için alternatif yöntemler var.

## 🔍 Yapılabilecek Kontroller

### 1. **Kod Analizi (Yapıldı ✅)**
```bash
flutter analyze
```
- ✅ Kritik hata yok
- ⚠️ Sadece uyarılar var (print kullanımı, deprecated metodlar)

### 2. **Startup Test Script (Oluşturuldu ✅)**
```bash
dart test_startup.dart
```
Bu script şunları kontrol eder:
- Gerekli dosyaların varlığı
- Bağımlılıkların yüklü olması
- Error handling'in doğru yapılandırılması
- Info.plist ayarları
- Router yapılandırması

### 3. **Android'de Test (iOS'a Benzer Davranış)**
```bash
flutter run
```
Android'de çalıştırarak benzer sorunları tespit edebilirsiniz:
- Firebase initialization
- Network hataları
- Asset yükleme sorunları

## 🛠️ Codemagic'te Remote Debug

### Yöntem 1: Codemagic Build Logları

1. **Codemagic Dashboard'a gidin**
2. **Son build'i seçin**
3. **"Build logs" sekmesine tıklayın**
4. **Şu logları arayın:**
   ```
   ✅ Firebase initialized
   ✅ TokenManager initialized
   ⚠️ Version check timeout
   ❌ Flutter Error:
   ```

### Yöntem 2: TestFlight Console Logları

TestFlight'tan indirilen uygulamada log görmek için:

**Mac gerektirir, ancak alternatif:**

1. **Codemagic'te Debug Build Oluşturun:**
   ```yaml
   # codemagic.yaml'a ekleyin
   scripts:
     - name: Build debug IPA
       script: |
         flutter build ios --debug --no-codesign
   ```

2. **Logları Dosyaya Kaydedin:**
   `main.dart`'a log dosyasına yazma ekleyin (production'da kaldırın)

## 📱 TestFlight'tan Log Alma (iPhone ile)

### Yöntem 1: Xcode Organizer (Mac Gerektirir)
- Xcode → Window → Organizer
- Crashes sekmesi
- Son crash'leri görüntüle

### Yöntem 2: Console App (Mac Gerektirir)
- Mac'te Console uygulamasını açın
- iPhone'u bağlayın
- Logları izleyin

### Yöntem 3: TestFlight Feedback
- TestFlight'ta "Send Feedback" kullanın
- Kullanıcılar hata raporu gönderebilir

## 🔧 Kod Seviyesinde Debug

### 1. **Log Dosyasına Yazma (Geçici)**

`main.dart`'a ekleyin (production'da kaldırın):

```dart
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Log dosyasına yaz (sadece debug için)
  if (kDebugMode) {
    final logFile = File('startup_log.txt');
    logFile.writeAsStringSync('=== Startup Log ===\n');
    
    // Her log'u dosyaya yaz
    debugPrint = (String? message, {int? wrapWidth}) {
      logFile.writeAsStringSync('$message\n', mode: FileMode.append);
      print(message);
    };
  }
  
  // ... rest of code
}
```

### 2. **Firebase Crashlytics (Önerilen)**

Production'da hataları görmek için:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Crashlytics'i başlat
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // ... rest of code
}
```

Sonra Firebase Console'dan hataları görüntüleyin.

## 🎯 Potansiyel Sorunlar ve Çözümleri

### Sorun 1: Firebase GoogleService-Info.plist Eksik

**Kontrol:**
```bash
# Windows PowerShell
Test-Path "ios/Runner/GoogleService-Info.plist"
```

**Çözüm:**
1. Firebase Console'dan dosyayı indirin
2. `ios/Runner/` klasörüne koyun
3. Codemagic'te environment variable olarak ekleyin

### Sorun 2: Asset Eksikliği

**Kontrol:**
```bash
Test-Path "assets/logo.png"
```

**Çözüm:**
1. `pubspec.yaml`'da asset tanımlı mı kontrol edin
2. `flutter pub get` çalıştırın
3. `flutter clean` yapın

### Sorun 3: Network Timeout

**Kontrol:**
- `lib/services/version_check_service.dart`'ta timeout var mı? ✅ Var
- `lib/main.dart`'ta version check timeout var mı? ✅ Var

**Çözüm:**
- Timeout değerlerini artırın (15 saniye → 30 saniye)

### Sorun 4: Info.plist ATS Ayarları

**Kontrol:**
- `NSAppTransportSecurity` var mı? ✅ Var
- `NSExceptionDomains` doğru mu? ✅ Doğru

## 📊 Codemagic Build Log Analizi

Codemagic'te build loglarında şunları arayın:

### ✅ Başarılı Build İşaretleri:
```
✓ Built build/ios/ipa/benimmarketim_app.ipa
✓ Successfully generated launcher icons
✓ Pod installation complete
```

### ❌ Hata İşaretleri:
```
✗ Error: GoogleService-Info.plist not found
✗ Error: Asset not found: assets/logo.png
✗ Error: Pod install failed
✗ Error: Code signing failed
```

## 🚀 Hızlı Test Adımları

### 1. Lokal Test (Android)
```bash
flutter clean
flutter pub get
flutter run
```

### 2. Codemagic'te Test Build
```bash
# codemagic.yaml'da test workflow'u çalıştır
```

### 3. TestFlight'ta Test
1. Yeni build yükleyin
2. Uygulamayı açın
3. Hata varsa Firebase Crashlytics'i kontrol edin

## 💡 Öneriler

### 1. **Firebase Crashlytics Ekleyin**
Production hatalarını görmek için en iyi yöntem.

### 2. **Remote Config ile Debug Mode**
Uygulama açılışında debug bilgilerini gösterin:
```dart
if (kDebugMode || RemoteConfig.getBool('show_debug_info')) {
  // Debug bilgilerini göster
}
```

### 3. **TestFlight Beta Testers**
Beta test kullanıcılarından feedback alın.

### 4. **Codemagic'te Debug Build**
Debug build oluşturup logları inceleyin.

## 📝 Checklist

Yeni build öncesi kontrol edin:

- [ ] `flutter analyze` - Hata var mı?
- [ ] `dart test_startup.dart` - Tüm kontroller geçti mi?
- [ ] `assets/logo.png` var mı?
- [ ] `ios/Runner/GoogleService-Info.plist` var mı?
- [ ] `Info.plist` ATS ayarları doğru mu?
- [ ] `main.dart` error handling var mı?
- [ ] Version check timeout var mı?

## 🔗 Yararlı Linkler

- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)
- [Codemagic Docs](https://docs.codemagic.io/)
- [Flutter Debugging](https://docs.flutter.dev/testing/debugging)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

## 🆘 Hala Sorun Varsa

1. **Codemagic build loglarını paylaşın**
2. **Firebase Crashlytics'teki hataları paylaşın**
3. **TestFlight feedback'lerini paylaşın**
4. **Android'de test edip sonuçları paylaşın**

Bu bilgilerle sorunu daha iyi tespit edebiliriz!

