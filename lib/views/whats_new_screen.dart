import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';

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
      title: 'Canlı Destek',
      description: 'Siparişinizle ilgili soru mu var? Tek tıkla destek ekibimize ulaşın! Sipariş durumu, teslimat saati veya özel istekleriniz için 7/24 yanınızdayız.',
      color: Colors.blue,
    ),
    WhatsNewItem(
      emoji: '🎁',
      title: 'Akıllı Kupon Sistemi',
      description: 'Kazandığınız kuponlar artık sepetinizde otomatik görünüyor! Hangi kuponu kullanacağınızı seçin, indiriminizi anında görün. Hiçbir fırsat kaçmaz!',
      color: Colors.purple,
    ),
    WhatsNewItem(
      emoji: '👥',
      title: 'Arkadaşını Getir, Kazan',
      description: 'Arkadaşınızı davet edin, o %5 hoş geldin indirimi kazansın, siz de %5 ödül kuponu alın! Paylaştıkça kazanın, dostluk büyüsün.',
      color: Colors.orange,
    ),
    WhatsNewItem(
      emoji: '✨',
      title: 'Yepyeni Tasarım',
      description: 'Daha hızlı, daha akıcı, göze daha hoş! Tüm sayfalar baştan aşağı yenilendi. Alışveriş deneyiminiz artık çok daha keyifli.',
      color: AppColors.successGreen,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Geç',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildPage(item);
                },
              ),
            ),

            // Page Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
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
                          ? _items[_currentPage].color
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Next/Complete Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _items[_currentPage].color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _items.length - 1 ? 'Başla!' : 'Sonraki',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
          // Emoji with animated background
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        item.color.withOpacity(0.2),
                        item.color.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            item.title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            item.description,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
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

  WhatsNewItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
