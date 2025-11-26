# App Store Metadata Düzenleme Rehberi

## 📱 App Store Connect'te Görüntüleme ve Düzenleme

### 1. App Store Connect'e Giriş
1. https://appstoreconnect.apple.com adresine gidin
2. Apple Developer hesabınızla giriş yapın
3. "My Apps" bölümüne tıklayın
4. Uygulamanızı seçin

### 2. App Information (Uygulama Bilgileri)
**Konum:** Sol menüden "App Information"

#### Düzenlenebilir Öğeler:
- **Name** (Uygulama Adı): App Store'da görünen isim
- **Subtitle** (Alt Başlık): İsim altında görünen kısa açıklama
- **Primary Language** (Ana Dil)
- **Bundle ID**: Değiştirilemez (com.jupi.benimmarketim)
- **SKU**: Benzersiz tanımlayıcı
- **User Access**: Test kullanıcı erişimi ayarları

### 3. Pricing and Availability (Fiyatlandırma)
**Konum:** Sol menüden "Pricing and Availability"

- Fiyatlandırma modeli
- Ülke/bölge kullanılabilirliği
- Eğitim indirimleri

### 4. App Store (Ana Sayfa Görünümü)
**Konum:** Sol menüden "App Store" → Versiyon seçin

#### A. App Icon (Uygulama Simgesi)
- **Boyut:** 1024x1024 piksel
- **Format:** PNG, opak (alfa kanalı olmamalı)
- **Şu anki kaynak:** `assets/logo.png`
- **Değiştirmek için:** 
  1. Yeni simgeyi `assets/logo.png` olarak kaydedin
  2. `flutter pub run flutter_launcher_icons` komutunu çalıştırın
  3. Yeni build yükleyin
  4. App Store Connect'te "App Icon" bölümünden yükleyin

#### B. Screenshots (Ekran Görüntüleri)
**Gerekli Boyutlar:**
- **iPhone 6.7" (iPhone 14 Pro Max):** 1290 x 2796 piksel
- **iPhone 6.5" (iPhone 11 Pro Max):** 1242 x 2688 piksel
- **iPhone 5.5" (iPhone 8 Plus):** 1242 x 2208 piksel
- **iPad Pro 12.9":** 2048 x 2732 piksel
- **iPad Pro 11":** 1668 x 2388 piksel

**Nasıl Eklenir:**
1. Uygulamanızı simülatörde veya gerçek cihazda çalıştırın
2. Ekran görüntüsü alın (Cmd+Shift+4 veya cihaz ekran görüntüsü)
3. App Store Connect'te "Screenshots" bölümüne yükleyin
4. Her cihaz boyutu için en az 1, en fazla 10 ekran görüntüsü

#### C. App Preview Videos (Video Önizlemeler)
- **Süre:** 15-30 saniye
- **Format:** MP4, MOV
- **Boyut:** Screenshot boyutlarıyla aynı
- **Opsiyonel:** Zorunlu değil ama önerilir

#### D. Description (Açıklama)
- **Maksimum:** 4000 karakter
- **Önerilen:** 2-3 paragraf, net ve açıklayıcı
- **İçerik:**
  - Uygulamanın ne yaptığı
  - Ana özellikler
  - Kullanıcı faydaları
  - Call-to-action

#### E. Keywords (Anahtar Kelimeler)
- **Maksimum:** 100 karakter
- **Format:** Virgülle ayrılmış (boşluklar önemli değil)
- **Örnek:** "market, alışveriş, e-ticaret, ürün, satış"
- **İpuçları:**
  - Rakip uygulamaların anahtar kelimelerini araştırın
  - Marka adı kullanmayın
  - Tekil/çoğul formları ayrı ayrı ekleyin

#### F. Support URL
- Destek sayfası URL'i
- Zorunlu alan
- Örnek: https://benimmarketim.com/support

#### G. Marketing URL (Opsiyonel)
- Pazarlama sayfası URL'i
- Opsiyonel

#### H. Privacy Policy URL
- Gizlilik politikası sayfası
- **Zorunlu:** GDPR ve App Store gereksinimleri için

#### I. Category (Kategori)
- **Primary Category:** Ana kategori (zorunlu)
- **Secondary Category:** İkincil kategori (opsiyonel)
- Örnekler: Business, Shopping, Food & Drink

#### J. Age Rating
- İçerik derecelendirmesi
- Soruları yanıtlayarak otomatik belirlenir

### 5. Preview (Önizleme)
**Konum:** App Store sayfasının sağ üst köşesinde "Preview" butonu

- Tüm değişikliklerinizi yayınlamadan önce nasıl göründüğünü görebilirsiniz
- Farklı cihaz boyutlarında önizleme yapabilirsiniz
- Gerçek zamanlı önizleme

## 🔄 Değişiklik Yapma Süreci

### Senaryo 1: Sadece Metadata Değişikliği (Logo, Açıklama, vb.)
1. App Store Connect'te değişiklikleri yapın
2. "Save" butonuna tıklayın
3. "Submit for Review" butonuna tıklayın
4. **Yeni build gerekmez!** Sadece metadata değişikliği

### Senaryo 2: App Icon Değişikliği (Kodda)
1. Yeni simgeyi `assets/logo.png` olarak kaydedin
2. Projede: `flutter pub run flutter_launcher_icons`
3. Yeni build oluşturun ve yükleyin
4. App Store Connect'te yeni build'i seçin
5. Submit for Review

### Senaryo 3: Screenshot Değişikliği
1. Yeni ekran görüntülerini hazırlayın
2. App Store Connect'te "Screenshots" bölümüne yükleyin
3. Eski görüntüleri silin veya yenileriyle değiştirin
4. "Save" → "Submit for Review"
5. **Yeni build gerekmez!**

## ⚠️ Önemli Notlar

1. **Yayınlamadan Önce:**
   - Tüm metadata'yı kontrol edin
   - Preview ile görünümü test edin
   - Screenshot'ların güncel olduğundan emin olun
   - Privacy Policy URL'inin çalıştığını kontrol edin

2. **Review Süreci:**
   - İlk yayın: 1-3 gün
   - Güncellemeler: 24-48 saat
   - Metadata değişiklikleri: 24 saat içinde

3. **Yayınlama:**
   - "Submit for Review" butonuna tıklayınca Apple incelemeye alır
   - "Ready for Sale" durumuna gelince App Store'da görünür
   - Otomatik yayınlama veya manuel yayınlama seçeneği var

## 📋 Checklist

Yayınlamadan önce kontrol edin:
- [ ] App Icon yüklendi ve doğru görünüyor
- [ ] Screenshot'lar tüm gerekli cihaz boyutları için mevcut
- [ ] Description yazıldı ve hata yok
- [ ] Keywords eklendi
- [ ] Support URL çalışıyor
- [ ] Privacy Policy URL çalışıyor ve güncel
- [ ] Category seçildi
- [ ] Age Rating tamamlandı
- [ ] Preview'da her şey doğru görünüyor
- [ ] Build başarıyla yüklendi ve "Ready to Submit" durumunda

## 🎨 Logo/Simge Değiştirme (Kodda)

### Adım 1: Yeni Simgeyi Hazırlayın
- Boyut: En az 1024x1024 piksel
- Format: PNG
- **Önemli:** Alfa kanalı olmamalı (opak olmalı)
- Arka plan: Beyaz veya uygulamanızın ana rengi

### Adım 2: Projeye Ekleyin
```bash
# Yeni simgeyi assets/logo.png olarak kaydedin
# (Eski dosyanın üzerine yazabilirsiniz)
```

### Adım 3: Simgeleri Yeniden Oluşturun
```bash
flutter pub run flutter_launcher_icons
```

### Adım 4: Build ve Yükleme
```bash
flutter clean
flutter build ipa
# Codemagic veya manuel olarak App Store Connect'e yükleyin
```

### Adım 5: App Store Connect'te Güncelleme
1. App Store Connect → Uygulamanız → App Store
2. "App Icon" bölümüne gidin
3. Yeni build'i seçtiğinizde otomatik olarak yeni simge yüklenecek
4. Veya manuel olarak 1024x1024 simgeyi yükleyebilirsiniz

## 🔗 Yararlı Linkler

- App Store Connect: https://appstoreconnect.apple.com
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Screenshot Boyutları: https://help.apple.com/app-store-connect/#/devd274dd925

