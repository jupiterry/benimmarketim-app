/**
 * Version Check Middleware for Express.js
 * 
 * Bu middleware, eski uygulama versiyonlarına güncelleme uyarısı döndürür.
 * Eski uygulamalar header'da versiyon bilgisi göndermediği için,
 * 426 hatası yerine 200 OK ile fake veri döndürülür.
 * 
 * Kullanım: app.use(versionCheckMiddleware);
 */

// Minimum desteklenen versiyon (bu versiyonun altındakiler güncelleme uyarısı alır)
const MINIMUM_SUPPORTED_VERSION = '2.1.1';

// Versiyon karşılaştırma fonksiyonu
// Örnek: '2.1.1' vs '2.0.0' => 1 (ilk büyük)
// Örnek: '2.0.0' vs '2.1.1' => -1 (ikinci büyük)
// Örnek: '2.1.1' vs '2.1.1' => 0 (eşit)
function compareVersions(v1, v2) {
  const parts1 = v1.split('.').map(Number);
  const parts2 = v2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const num1 = parts1[i] || 0;
    const num2 = parts2[i] || 0;
    
    if (num1 > num2) return 1;
    if (num1 < num2) return -1;
  }
  
  return 0;
}

// Endpoint'e göre fake güncelleme verisi döndür
function getFakeUpdateResponse(endpoint, method) {
  const updateMessage = {
    title: '🚀 Güncelleme Gerekli',
    message: 'Uygulamanızın yeni bir versiyonu mevcut. Devam etmek için lütfen güncelleyin.',
    updateUrl: {
      ios: 'https://apps.apple.com/app/benim-marketim/id123456789',
      android: 'https://play.google.com/store/apps/details?id=com.benimmarketim.app'
    },
    isForceUpdate: true
  };

  // Endpoint'e göre farklı fake response'lar
  const fakeResponses = {
    // Ürünler için fake response
    '/api/products': {
      success: true,
      products: [{
        _id: 'update-required',
        name: '🚀 Güncelleme Gerekli',
        description: 'Uygulamanızı güncelleyerek alışverişe devam edin!',
        price: 0,
        originalPrice: 0,
        actualPrice: 0,
        image: 'https://devrekbenimmarketim.com/images/update_banner.png',
        category: 'update',
        categoryId: 'update',
        isDiscounted: false,
        isOutOfStock: false,
        isFeatured: true,
        isHidden: false,
        order: 0,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }],
      pagination: { page: 1, limit: 20, total: 1, pages: 1 },
      _updateRequired: updateMessage
    },

    // Banner'lar için fake response
    '/api/banners': {
      success: true,
      banners: [{
        _id: 'update-banner',
        title: '🚀 Güncelleme Gerekli!',
        subtitle: 'Yeni özellikler sizi bekliyor',
        image: 'https://devrekbenimmarketim.com/images/update_banner.png',
        linkUrl: 'https://play.google.com/store/apps/details?id=com.benimmarketim.app',
        order: 0,
        isActive: true
      }],
      _updateRequired: updateMessage
    },

    // Kategoriler için fake response  
    '/api/categories': {
      success: true,
      categories: [{
        _id: 'update',
        name: '🚀 Güncelleme',
        description: 'Uygulamanızı güncelleyin',
        icon: 'update',
        order: 0,
        isActive: true
      }],
      _updateRequired: updateMessage
    },

    // Flash sale için fake response
    '/api/flash-sale': {
      success: true,
      flashSale: null,
      products: [],
      _updateRequired: updateMessage
    },

    // Profil için fake response
    '/api/auth/profile': {
      success: true,
      user: {
        _id: 'update-user',
        name: 'Güncelleme Gerekli',
        email: 'update@required.com',
        phone: '',
        role: 'user',
        createdAt: new Date().toISOString()
      },
      _updateRequired: updateMessage
    },

    // Siparişler için fake response
    '/api/orders': {
      success: true,
      orders: [],
      _updateRequired: updateMessage
    },

    // Ayarlar için fake response
    '/api/settings': {
      success: true,
      minimumOrderAmount: 999999, // Sipariş verememesi için çok yüksek
      orderStartHour: 0,
      orderStartMinute: 0,
      orderEndHour: 0,
      orderEndMinute: 0,
      maintenanceMode: true,
      maintenanceMessage: 'Uygulamanızı güncelleyiniz.',
      _updateRequired: updateMessage
    },

    // Referrals için fake response
    '/api/referrals/my-referrals': {
      success: true,
      referral: {
        code: 'GUNCELLE',
        link: 'https://play.google.com/store/apps/details?id=com.benimmarketim.app',
        totalReferrals: 0,
        successfulReferrals: 0,
        totalRewardsEarned: 0,
        referredUsers: []
      },
      _updateRequired: updateMessage
    },

    // Kuponlar için fake response
    '/api/coupons': {
      success: true,
      coupons: [],
      _updateRequired: updateMessage
    },

    // Default response - diğer tüm endpoint'ler için
    default: {
      success: true,
      data: null,
      message: 'Uygulamanızı güncelleyiniz.',
      _updateRequired: updateMessage
    }
  };

  // Endpoint'i normalize et (query string'i kaldır)
  const normalizedEndpoint = endpoint.split('?')[0];
  
  // Exact match dene
  if (fakeResponses[normalizedEndpoint]) {
    return fakeResponses[normalizedEndpoint];
  }
  
  // Partial match dene (örn: /api/products/123 -> /api/products)
  for (const key of Object.keys(fakeResponses)) {
    if (normalizedEndpoint.startsWith(key)) {
      return fakeResponses[key];
    }
  }
  
  return fakeResponses.default;
}

// Ana middleware fonksiyonu
const versionCheckMiddleware = (req, res, next) => {
  // Versiyon header'larını kontrol et
  // Flutter uygulaması şu header'ları gönderebilir:
  // - X-App-Version: '2.1.1'
  // - X-App-Build: '28'
  // - User-Agent: 'BenimMarketim/2.1.1 (Build 28)'
  
  const appVersion = req.headers['x-app-version'] || 
                     req.headers['x-app-ver'] ||
                     extractVersionFromUserAgent(req.headers['user-agent']);
  
  // Web panel veya admin istekleri için bypass
  const isWebRequest = req.headers['x-requested-with'] === 'XMLHttpRequest' ||
                       req.headers['origin']?.includes('admin') ||
                       req.path.startsWith('/admin');
  
  if (isWebRequest) {
    return next();
  }

  // Auth endpoint'leri için bypass (login, register, refresh-token)
  const authBypassPaths = [
    '/api/auth/login',
    '/api/auth/signup',
    '/api/auth/refresh-token',
    '/api/auth/forgot-password'
  ];
  
  if (authBypassPaths.some(path => req.path.startsWith(path))) {
    return next();
  }

  // Eğer versiyon header'ı YOKSA = eski uygulama
  if (!appVersion) {
    console.log(`[VERSION CHECK] Eski uygulama tespit edildi - No version header`);
    console.log(`[VERSION CHECK] Path: ${req.path}, Method: ${req.method}`);
    console.log(`[VERSION CHECK] User-Agent: ${req.headers['user-agent']}`);
    
    const fakeResponse = getFakeUpdateResponse(req.path, req.method);
    return res.status(200).json(fakeResponse);
  }

  // Versiyon kontrolü
  const versionComparison = compareVersions(appVersion, MINIMUM_SUPPORTED_VERSION);
  
  if (versionComparison < 0) {
    // Eski versiyon - güncelleme gerekli
    console.log(`[VERSION CHECK] Eski versiyon tespit edildi: ${appVersion} < ${MINIMUM_SUPPORTED_VERSION}`);
    
    const fakeResponse = getFakeUpdateResponse(req.path, req.method);
    return res.status(200).json(fakeResponse);
  }

  // Versiyon yeterli, devam et
  next();
};

// User-Agent'tan versiyon çıkar
// Örnek: "BenimMarketim/2.1.1 (Build 28)" -> "2.1.1"
function extractVersionFromUserAgent(userAgent) {
  if (!userAgent) return null;
  
  // Pattern: AppName/Version
  const match = userAgent.match(/BenimMarketim\/(\d+\.\d+\.\d+)/i);
  if (match) {
    return match[1];
  }
  
  // Pattern: Version/X.X.X
  const altMatch = userAgent.match(/Version\/(\d+\.\d+\.\d+)/i);
  if (altMatch) {
    return altMatch[1];
  }
  
  return null;
}

// Express router için alternatif kullanım
const createVersionCheckRouter = (options = {}) => {
  const router = require('express').Router();
  
  const config = {
    minimumVersion: options.minimumVersion || MINIMUM_SUPPORTED_VERSION,
    bypassPaths: options.bypassPaths || [],
    updateUrls: options.updateUrls || {
      ios: 'https://apps.apple.com/app/benim-marketim/id123456789',
      android: 'https://play.google.com/store/apps/details?id=com.benimmarketim.app'
    },
    ...options
  };

  router.use((req, res, next) => {
    // Custom bypass paths
    if (config.bypassPaths.some(path => req.path.startsWith(path))) {
      return next();
    }
    
    versionCheckMiddleware(req, res, next);
  });

  return router;
};

module.exports = {
  versionCheckMiddleware,
  createVersionCheckRouter,
  compareVersions,
  getFakeUpdateResponse,
  MINIMUM_SUPPORTED_VERSION
};


/*
==========================================================
KULLANIM ÖRNEKLERİ
==========================================================

1. Basit kullanım (tüm route'lara uygula):
------------------------------------------
const { versionCheckMiddleware } = require('./middleware/versionCheck');
app.use(versionCheckMiddleware);


2. Sadece API route'larına uygula:
------------------------------------------
const { versionCheckMiddleware } = require('./middleware/versionCheck');
app.use('/api', versionCheckMiddleware);


3. Custom ayarlarla kullan:
------------------------------------------
const { createVersionCheckRouter } = require('./middleware/versionCheck');

const versionRouter = createVersionCheckRouter({
  minimumVersion: '2.2.0',
  bypassPaths: ['/api/health', '/api/version'],
  updateUrls: {
    ios: 'https://apps.apple.com/your-app',
    android: 'https://play.google.com/your-app'
  }
});

app.use(versionRouter);


4. Flutter tarafında header ekleme (yeni versiyonlar için):
------------------------------------------
// api_service.dart içinde Dio interceptor ekleyin:

_dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Versiyon bilgisini ekle
      final packageInfo = await PackageInfo.fromPlatform();
      options.headers['X-App-Version'] = packageInfo.version;
      options.headers['X-App-Build'] = packageInfo.buildNumber;
      handler.next(options);
    },
  ),
);


5. Flutter tarafında _updateRequired kontrolü:
------------------------------------------
// API response'unda _updateRequired varsa dialog göster:

if (response.data['_updateRequired'] != null) {
  showUpdateDialog(
    title: response.data['_updateRequired']['title'],
    message: response.data['_updateRequired']['message'],
    updateUrl: Platform.isIOS 
      ? response.data['_updateRequired']['updateUrl']['ios']
      : response.data['_updateRequired']['updateUrl']['android'],
  );
}

==========================================================
*/
