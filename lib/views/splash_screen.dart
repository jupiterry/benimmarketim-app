import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/version_check_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/custom_dialog.dart'; // Added CustomDialog import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _circleScaleAnimation;

  String _version = '';

  @override
  void initState() {
    super.initState();
    _getVersionInfo();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // 1. Circle Expansion (Background reveal)
    _circleScaleAnimation = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // 2. Logo Pop-in
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.elasticOut),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.6, curve: Curves.easeIn),
      ),
    );

    // 3. Text Slide & Fade
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Navigate after checks
    _checkVersionAndNavigate();
  }

  Future<void> _getVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
      });
    }
  }

  Future<void> _checkVersionAndNavigate() async {
    try {
      final versionService = VersionCheckService();
      // Servisten null dönmesi hata/internet yok demektir.
      final result = await versionService.checkVersion();

      if (result == null) {
        // Hata durumu: İnternet yok veya sunucuya ulaşılamadı.
        // KULLANICI İSTEĞİ: "kullanıcının interneti yoksa içeriğe erişemesin"
        if (mounted) {
          await CustomDialog.show(
            context: context,
            title: 'Bağlantı Hatası',
            message: 'Uygulamayı kullanabilmek için internet bağlantısı ve sürüm kontrolü gereklidir. Lütfen internetinizi kontrol edip tekrar deneyin.',
            confirmButtonText: 'Tekrar Dene',
            showCancelButton: false, // Kapatılamaz
            icon: Icons.wifi_off_rounded,
            isDestructive: true,
            onConfirm: () {
              Navigator.pop(context); // Dialogu kapat
              _checkVersionAndNavigate(); // Tekrar dene
            },
          );
        }
        return; // Akışı durdur, auth kontrolüne geçme (Tekrar dene ile loop olur)
      }

      if (result.isUpdateRequired) {
        if (mounted) {
          showUpdateDialog(
            context,
            isMandatory: result.isMandatory && true,
            storeUrl: result.storeUrl,
            latestVersion: result.latestVersion,
          );
        }
        
        if (result.isMandatory) {
          return; 
        }
      }
      
      _checkAuthAndNavigate();
    } catch (e) {
      debugPrint('Sürüm kontrolü hatası: $e');
      // Beklenmedik hata (try-catch dışı) olsa bile güvenli tarafta kalıp tekrar ettirebiliriz
      // Ancak sonsuz döngüden kaçınmak için burada da dialog göstermek en iyisi.
      if (mounted) {
          await CustomDialog.show(
            context: context,
            title: 'Hata',
            message: 'Bir sorun oluştu. Lütfen tekrar deneyin.',
            confirmButtonText: 'Tekrar Dene',
            showCancelButton: false,
            icon: Icons.error_outline_rounded,
            isDestructive: true,
            onConfirm: () {
              Navigator.pop(context);
              _checkVersionAndNavigate();
            },
          );
      }
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (mounted) {
        if (isFirstTime) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint('Error checking first time: $e');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using a dark, premium background color initially
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark background
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding Circle Reveal (Vibrant Green)
          AnimatedBuilder(
            animation: _circleScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _circleScaleAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00C639), // AppColors.successGreen
                        Color(0xFF007022),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // Text
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Benim Marketim',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.0,
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Bir sipariş kadar yakınız.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Version Info
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFadeAnimation,
              child: Center(
                child: Text(
                  'v$_version',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
