# Benim Marketim - temizlik scripti (Claude, 21 Ekim 2026)
# Kullanilmayan kaynak dosyalari, Telegram/n8n kalintilarini ve depo kokundeki ilgisiz
# klasor/arsivleri siler. Once listeyi gosterir, onay ister.
# Calistirma: PowerShell'de  ->  powershell -ExecutionPolicy Bypass -File .\temizlik.ps1

$web = "C:\Users\PcUser\Downloads\benimmarketim-final-v2\benimmarketim-main"
$app = "C:\Users\PcUser\Downloads\benimmarketim-app-main\benimmarketim-app-main"

$webFiles = @(
    "backend\controllers\n8n.controller.js",
    "backend\controllers\productController.js",
    "backend\lib\stripe.js",
    "backend\routes\n8n.route.js",
    "backend\routes\orders.routes.js",
    "backend\routes\productRoutes.js",
    "backend\routes\telegram.route.js",
    "backend\services\n8n.service.js",
    "backend\services\telegram.helpers.js",
    "backend\test-db.js",
    "backend\tests\telegram.integration.mjs",
    "backend\tests\telegram.test.js",
    "backend\workers\TELEGRAM.md",
    "backend\workers\telegram.run.js",
    "backend\workers\telegram.worker.js",
    "frontend\src\components\AppDownloadModal.jsx",
    "frontend\src\components\AppScreenshots.jsx",
    "frontend\src\components\BulkActionsToolbar.jsx",
    "frontend\src\components\CancelOrderModal.jsx",
    "frontend\src\components\CartItem.jsx",
    "frontend\src\components\CategoryItem.jsx",
    "frontend\src\components\FeaturedProducts.jsx",
    "frontend\src\components\FeedbackTab.jsx",
    "frontend\src\components\GiftCouponCard.jsx",
    "frontend\src\components\OrderList.jsx",
    "frontend\src\components\OrderSummary.jsx",
    "frontend\src\components\OrdersTab.jsx",
    "frontend\src\components\PeopleAlsoBought.jsx",
    "frontend\src\components\ProductCard.jsx",
    "frontend\src\components\SalesHeatmap.jsx",
    "frontend\src\components\SearchBar.jsx",
    "frontend\src\components\TelegramNotificationsCard.jsx",
    "frontend\src\components\WeeklyProducts.jsx",
    "frontend\src\components\ui\tabs.jsx",
    "frontend\src\constants\categories.js",
    "frontend\src\data\cities.js",
    "frontend\src\lib\orderHours.js",
    "frontend\src\pages\CartPage.jsx",
    "frontend\src\pages\CategoryPage.jsx",
    "frontend\src\pages\DashboardPage.jsx",
    "frontend\src\pages\OrderCreated.jsx",
    "frontend\src\pages\PurchaseCancelPage.jsx",
    "frontend\src\pages\PurchaseSuccessPage.jsx",
    "frontend\src\pages\SearchResultsPage.jsx",
    "frontend\src\pages\UserOrders.jsx",
    "frontend\src\stores\useCartStore.js",
    "frontend\src\stores\useOrderStore.js"
)
$webExtra = @(
    "aliz-motorent",
    ".codex-ai-deploy",
    "artifacts",
    "benimmarketim-support-windows.rar",
    "benimmarketim-web.zip",
    "benimmarketim-web-latest.zip"
)
$appFiles = @(
    "lib\models\feedback.dart",
    "lib\services\cache_service.dart",
    "lib\services\connectivity_service.dart",
    "lib\services\network_service.dart",
    "lib\services\version_service.dart",
    "lib\services\websocket_service.dart",
    "lib\views\auth\login_page.dart",
    "lib\views\auth\register_page.dart",
    "lib\views\categories_page.dart",
    "lib\views\home_page_backup.dart",
    "lib\views\search_page.dart",
    "lib\views\widgets\animated_shopping_button.dart",
    "lib\views\widgets\cart_badge.dart",
    "lib\views\widgets\category_card.dart",
    "lib\views\widgets\modern_ui.dart",
    "lib\views\widgets\product_card.dart",
    "lib\views\widgets\promotion_banner.dart",
    "lib\views\widgets\skeleton_widgets.dart",
    "lib\views\widgets\special_products.dart"
)

$targets = @()
foreach ($f in $webFiles + $webExtra) { $targets += (Join-Path $web $f) }
foreach ($f in $appFiles) { $targets += (Join-Path $app $f) }

$existing = $targets | Where-Object { Test-Path -LiteralPath $_ }
$missing  = $targets | Where-Object { -not (Test-Path -LiteralPath $_) }

Write-Host "Silinecekler ($($existing.Count)):" -ForegroundColor Yellow
$existing | ForEach-Object { Write-Host "  $_" }
if ($missing.Count -gt 0) {
  Write-Host "Zaten yok ($($missing.Count)):" -ForegroundColor DarkGray
  $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
}

$answer = Read-Host "Devam edilsin mi? (E/H)"
if ($answer -notmatch '^[Ee]') { Write-Host "Iptal edildi."; exit 0 }

foreach ($t in $existing) {
  Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Continue
  Write-Host "Silindi: $t" -ForegroundColor Green
}

Write-Host ""
Write-Host "Git kullaniyorsan simdi:" -ForegroundColor Cyan
Write-Host "  cd `"$web`"; git add -A; git status"
Write-Host "  cd `"$app`"; git add -A; git status"
Write-Host "Mobil projede: flutter pub get; flutter analyze; flutter test"
