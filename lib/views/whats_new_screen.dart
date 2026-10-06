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

  /// Bu versiyon için What's New gösterilmeli mi kontrol et
  static Future<bool> shouldShow(String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString('last_seen_version');

    // Eğer daha önce hiç görülmemişse veya versiyon farklıysa göster
    return lastSeenVersion != currentVersion;
  }

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WhatsNewItem> _items = [
    WhatsNewItem(
      emoji: '💬',
      title: 'Canlı destek',
      description:
          'Siparişinle ilgili bir sorun mu var? Sipariş saatlerinde tek dokunuşla destek ekibimize yaz, hemen ilgilenelim.',
      color: MarketPalette.blue,
      background: MarketPalette.blueSoft,
    ),
    WhatsNewItem(
      emoji: '🎁',
      title: 'Akıllı kupon sistemi',
      description:
          'Kazandığın kuponlar sepetinde otomatik görünür. Sepetine en uygun kuponu öneriyoruz, indirimini anında görürsün.',
      color: MarketPalette.orangeInk,
      background: MarketPalette.orangeSoft,
    ),
    WhatsNewItem(
      emoji: '👥',
      title: 'Arkadaşını getir, kazan',
      description:
          'Davet kodunu paylaş; arkadaşın ilk siparişinde indirim kazansın, sen de ödül kuponu al.',
      color: MarketPalette.pink,
      background: MarketPalette.pinkSoft,
    ),
    WhatsNewItem(
      emoji: '✨',
      title: 'Yepyeni tasarım',
      description:
          'Daha okunaklı, daha hızlı ve daha tutarlı. Sepetten hesabına kadar tüm ekranlar baştan yenilendi.',
      color: MarketPalette.greenDark,
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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  MarketPill(
                    label: 'Sürüm ${widget.currentVersion} ile gelenler',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(foregroundColor: MarketPalette.muted),
                    child: const Text('Geç'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? MarketPalette.green
                        : MarketPalette.lineStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(last ? 'Alışverişe başla' : 'Sonraki'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: item.background,
                borderRadius: BorderRadius.circular(MarketRadius.xl),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 64)),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            item.title,
            style: MarketText.display(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            style: MarketText.body(color: MarketPalette.muted, size: 16, height: 1.55),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class WhatsNewItem {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final Color background;

  WhatsNewItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.background,
  });
}
