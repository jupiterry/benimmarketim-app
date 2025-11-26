# Build Number Hatası Çözümü

## ❌ Hata Mesajı
```
The provided entity includes an attribute with a value that has already been used
Failed to publish benimmarketim_app.ipa to App Store Connect
```

## 🔍 Sorunun Nedeni

Bu hata, **build number'ın (CFBundleVersion) daha önce kullanılmış olmasından** kaynaklanır.

Apple'ın kuralları:
- Her yeni build için build number **mutlaka artırılmalıdır**
- Aynı build number ile iki kez yükleme yapılamaz
- Build number sadece artırılabilir, azaltılamaz

## ✅ Çözüm

### 1. Build Number'ı Artırın

`pubspec.yaml` dosyasında:
```yaml
version: 2.0.6+16  # +16 build number (önceki: +15)
```

**Format:** `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- `2.0.6` = Version (CFBundleShortVersionString)
- `16` = Build Number (CFBundleVersion)

### 2. Build Number Artırma Kuralları

- ✅ **Her build için +1 artırın**
- ✅ **Aynı version için bile artırılmalı** (örn: 2.0.6+16, 2.0.6+17, 2.0.6+18)
- ❌ **Asla azaltmayın** (Apple reddeder)
- ❌ **Aynı build number'ı tekrar kullanmayın**

### 3. Otomatik Build Number Artırma (Önerilen)

Codemagic'te otomatik artırma için `codemagic.yaml`'a ekleyin:

```yaml
scripts:
  - name: Increment build number
    script: |
      # Mevcut build number'ı al
      CURRENT_BUILD=$(grep -oP 'version: \K[0-9]+\.[0-9]+\.[0-9]+\+\K[0-9]+' pubspec.yaml)
      NEW_BUILD=$((CURRENT_BUILD + 1))
      
      # Build number'ı güncelle
      sed -i "s/version: 2.0.6+[0-9]*/version: 2.0.6+$NEW_BUILD/" pubspec.yaml
      
      echo "Build number updated to $NEW_BUILD"
```

## 📋 Version ve Build Number Açıklaması

### Version (CFBundleShortVersionString)
- Kullanıcıya gösterilen versiyon
- Format: `MAJOR.MINOR.PATCH` (örn: `2.0.6`)
- Örnek: `2.0.6` → `2.0.7` (yeni özellik)
- Örnek: `2.0.6` → `2.1.0` (minor güncelleme)
- Örnek: `2.0.6` → `3.0.0` (major güncelleme)

### Build Number (CFBundleVersion)
- Apple'ın internal tracking için kullandığı numara
- Format: Sadece sayı (örn: `16`)
- **Her build için mutlaka artırılmalı**
- Örnek: `15` → `16` → `17` → `18`

## 🎯 Örnek Senaryolar

### Senaryo 1: Aynı Version, Farklı Build
```
İlk yükleme:  2.0.6+15
Hata düzeltme: 2.0.6+16  ✅ (Build number artırıldı)
Başka düzeltme: 2.0.6+17 ✅ (Build number artırıldı)
```

### Senaryo 2: Yeni Version
```
Önceki: 2.0.6+20
Yeni özellik: 2.0.7+21 ✅ (Hem version hem build artırıldı)
```

### Senaryo 3: Major Update
```
Önceki: 2.0.6+25
Büyük güncelleme: 3.0.0+26 ✅ (Version ve build artırıldı)
```

## ⚠️ Yaygın Hatalar

### ❌ Hata 1: Build Number'ı Unutmak
```yaml
# YANLIŞ
version: 2.0.6+15  # İlk build
version: 2.0.6+15  # İkinci build (HATA!)
```

### ❌ Hata 2: Build Number'ı Azaltmak
```yaml
# YANLIŞ
version: 2.0.6+20
version: 2.0.6+19  # Apple reddeder!
```

### ✅ Doğru Kullanım
```yaml
# DOĞRU
version: 2.0.6+15  # İlk build
version: 2.0.6+16  # İkinci build
version: 2.0.6+17  # Üçüncü build
```

## 🔧 Codemagic'te Otomatikleştirme

### Yöntem 1: Script ile Otomatik Artırma

`codemagic.yaml`'a ekleyin:

```yaml
scripts:
  - name: Auto-increment build number
    script: |
      # pubspec.yaml'dan mevcut build number'ı al
      VERSION_LINE=$(grep "version:" pubspec.yaml)
      CURRENT_BUILD=$(echo $VERSION_LINE | grep -oP '\+\K[0-9]+')
      NEW_BUILD=$((CURRENT_BUILD + 1))
      
      # Yeni build number ile güncelle
      sed -i "s/version: 2.0.6+[0-9]*/version: 2.0.6+$NEW_BUILD/" pubspec.yaml
      
      echo "✅ Build number: $CURRENT_BUILD → $NEW_BUILD"
```

### Yöntem 2: Environment Variable ile

Codemagic'te environment variable tanımlayın:
- `BUILD_NUMBER` = 16

Sonra script'te kullanın:
```yaml
scripts:
  - name: Set build number
    script: |
      sed -i "s/version: 2.0.6+[0-9]*/version: 2.0.6+$BUILD_NUMBER/" pubspec.yaml
```

## 📊 App Store Connect'te Kontrol

1. **App Store Connect'e gidin**
2. **My Apps → Uygulamanız → TestFlight**
3. **Builds sekmesine bakın**
4. **En son build number'ı kontrol edin**
5. **Yeni build number bunun üzerinde olmalı**

## ✅ Şu An Yapılan

- ✅ Build number `15` → `16` olarak güncellendi
- ✅ Yeni build'i Codemagic'te çalıştırabilirsiniz

## 🚀 Sonraki Adımlar

1. **Değişiklikleri commit edin:**
   ```bash
   git add pubspec.yaml
   git commit -m "Bump build number to 16"
   git push
   ```

2. **Codemagic'te yeni build çalıştırın**

3. **Başarılı olursa, bir sonraki build için +17 kullanın**

## 💡 İpucu

Her build'den önce build number'ı artırmayı unutmayın. Otomatik script kullanmak en iyisidir!

