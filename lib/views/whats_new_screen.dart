import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/market_ui.dart';

class WhatsNewScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final String currentVersion;

  const WhatsNewScreen({
    super.key,
    required this.onComplete,
    required this.currentVersion,
  });

  /// Aşağıdaki sayfaların anlattığı sürüm (ana.ara). Yeni bir "Yenilikler"
  /// içeriği eklendiğinde bu da güncellenir; yama sürümlerinde (6.0.1)
  /// ekran yeniden çıkmaz.
  static const String contentVersion = '6.0';

  /// "6.0.1" → (6, 0); okunamayan parça 0 sayılır.
  static (int, int) _majorMinor(String version) {
    final parts = version.split('.');
    int part(int i) => i < parts.length ? int.tryParse(parts[i].trim()) ?? 0 : 0;
    return (part(0), part(1));
  }

  /// Bu versiyon için What's New gösterilmeli mi kontrol et
  static Future<bool> shouldShow(String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString('last_seen_version');

    // Hiç görülmemişse ya da en son içerikten eski bir sürümde görüldüyse
    // göster. Yama sürümleri (6.0.1) ekranı yeniden açmaz; yeni kullanıcılar
    // için tanıtım ekranı bu değeri yazar.
    if (lastSeenVersion == null) return true;
    final (seenMajor, seenMinor) = _majorMinor(lastSeenVersion);
    final (major, minor) = _majorMinor(contentVersion);
    return seenMajor < major || (seenMajor == major && seenMinor < minor);
  }

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WhatsNewItem> _items = const [
    WhatsNewItem(
      emoji: '🛒',
      title: 'Sepet asistanın hazır',
      description:
          'Ne almak istediğini ve bütçeni yaz; sepet asistanı marketteki ürünlerden sana bir alışveriş listesi önersin.',
      background: MarketPalette.blueSoft,
    ),
    WhatsNewItem(
      emoji: '🎁',
      title: 'Görevleri tamamla, ödül kazan',
      description:
          'Aktif görevleri ana sayfadan takip et. Görev koşullarını tamamlayarak ödül kuponu kazan.',
      background: MarketPalette.orangeSoft,
    ),
    WhatsNewItem(
      emoji: '🧺',
      title: 'Favori sepetlerin hep yanında',
      description:
          'Sık aldığın ürünleri bir sepet olarak kaydet, sonraki alışverişinde kolayca yeniden kullan.',
      background: MarketPalette.pinkSoft,
    ),
    WhatsNewItem(
      emoji: '✨',
      title: 'Yepyeni tasarım',
      description:
          'Daha okunaklı, daha hızlı ve daha tutarlı. Sepetten hesabına kadar tüm ekranlar baştan yenilendi.',
      background: MarketPalette.greenSoft,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pageController.jumpToPage(_currentPage + 1);
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_version', widget.currentVersion);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final last = _currentPage == _items.length - 1;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MarketPill(
                        label: 'Sürüm ${widget.currentVersion} ile gelenler',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!last)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: MarketPalette.muted,
                        minimumSize: const Size(MarketSize.tapTarget, MarketSize.tapTarget),
                      ),
                      child: const Text('Atla'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _items.length,
                itemBuilder: (context, index) => _buildPage(_items[index]),
              ),
            ),
            Semantics(
              label: 'Sayfa ${_currentPage + 1} / ${_items.length}',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? MarketPalette.green
                            : MarketPalette.lineStrong,
                        borderRadius: BorderRadius.circular(MarketRadius.xs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(last ? 'Alışverişe başla' : 'Devam'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(WhatsNewItem item) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final tile = narrow ? 120.0 : 140.0;
    // Küçük ekranda / büyük yazıda içerik kayar; taşmaz
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: item.background,
                  borderRadius: BorderRadius.circular(MarketRadius.xl),
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(item.emoji, style: MarketText.emoji(tile * .46)),
                  ),
                ),
              ),
            ),
            SizedBox(height: narrow ? 28 : 40),
            Semantics(
              header: true,
              child: Text(
                item.title,
                style: narrow ? MarketText.title(size: 24) : MarketText.display(),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.description,
              style: MarketText.body(color: MarketPalette.muted, size: narrow ? 15 : 16, height: 1.55),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class WhatsNewItem {
  final String emoji;
  final String title;
  final String description;
  final Color background;

  const WhatsNewItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.background,
  });
}
