# Backend Sürüm Kontrol API Endpoint'i

## Endpoint: GET /api/app/version

### Request Headers:
```
Content-Type: application/json
```

### Response Format:
```json
{
  "success": true,
  "minimumVersion": "1.0.1",
  "latestVersion": "1.0.2",
  "forceUpdate": false,
  "updateMessage": "Yeni özellikler ve hata düzeltmeleri ile güncellenmiş sürüm mevcut.",
  "playStoreUrl": "https://play.google.com/store/apps/details?id=com.jupi.benimapp.benimmarketim_app"
}
```

### Response Fields:
- `minimumVersion`: Uygulamanın çalışması için gereken minimum sürüm
- `latestVersion`: En son mevcut sürüm
- `forceUpdate`: Zorunlu güncelleme gerekli mi (true/false)
- `updateMessage`: Kullanıcıya gösterilecek güncelleme mesajı
- `playStoreUrl`: Google Play Store linki

### Backend Implementation (Node.js/Express):
```javascript
// routes/app.js
const express = require('express');
const router = express.Router();

// Sürüm kontrol endpoint'i
router.get('/version', (req, res) => {
  try {
    const versionInfo = {
      success: true,
      minimumVersion: "1.0.1", // Bu değer veritabanından veya config'den alınabilir
      latestVersion: "1.0.2",   // Bu değer veritabanından veya config'den alınabilir
      forceUpdate: false,        // Kritik güncellemeler için true yapılabilir
      updateMessage: "Yeni özellikler ve hata düzeltmeleri ile güncellenmiş sürüm mevcut.",
      playStoreUrl: "https://play.google.com/store/apps/details?id=com.jupi.benimapp.benimmarketim_app"
    };
    
    res.json(versionInfo);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Sürüm bilgisi alınamadı"
    });
  }
});

module.exports = router;
```

### Veritabanı Tablosu (Opsiyonel):
```sql
CREATE TABLE app_versions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  minimum_version VARCHAR(20) NOT NULL,
  latest_version VARCHAR(20) NOT NULL,
  force_update BOOLEAN DEFAULT FALSE,
  update_message TEXT,
  play_store_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Örnek veri
INSERT INTO app_versions (minimum_version, latest_version, force_update, update_message, play_store_url) 
VALUES ('1.0.1', '1.0.2', FALSE, 'Yeni özellikler ve hata düzeltmeleri ile güncellenmiş sürüm mevcut.', 'https://play.google.com/store/apps/details?id=com.jupi.benimapp.benimmarketim_app');
```

### Sürüm Güncelleme Süreci:
1. **Yeni sürüm yayınlandığında:**
   - Backend'de `latest_version` güncellenir
   - Gerekirse `minimum_version` artırılır
   - `force_update` true yapılabilir (kritik güncellemeler için)

2. **Kullanıcı deneyimi:**
   - Uygulama açıldığında sürüm kontrolü yapılır
   - Eski sürüm kullanılıyorsa güncelleme dialog'u gösterilir
   - Zorunlu güncelleme varsa uygulama kullanılamaz
   - Opsiyonel güncelleme varsa kullanıcı seçim yapabilir

### Test Senaryoları:
1. **Normal kullanım:** Mevcut sürüm >= minimum sürüm
2. **Güncelleme gerekli:** Mevcut sürüm < minimum sürüm
3. **Zorunlu güncelleme:** force_update = true
4. **API hatası:** Backend erişilemez, uygulama çalışmaya devam eder
