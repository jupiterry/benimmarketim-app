import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/version_check_service.dart';
import 'widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _animationController.repeat();

    // 3 saniye sonra sürüm kontrolü yap ve ana sayfaya geç
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkVersionAndNavigate();
      }
    });
  }

  // Sürüm kontrolü ve navigasyon
  Future<void> _checkVersionAndNavigate() async {
    try {
      // Firebase Remote Config ile sürüm kontrolü yap
      final versionService = VersionCheckService();
      final needsUpdate = await versionService.checkVersion();

      if (needsUpdate == true) {
        // Güncelleme gerekiyor, dialog göster
        if (mounted) {
          showUpdateDialog(context);
        }
        return;
      }

      // Güncelleme gerekmiyorsa veya kontrol yapılamadıysa normal akışa devam et
      _checkAuthAndNavigate();
    } catch (e) {
      print('Sürüm kontrolü hatası: $e');
      // Hata durumunda normal akışa devam et (kullanıcıyı engelleme)
      _checkAuthAndNavigate();
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    // final authViewModel = context.read<AuthViewModel>();
    // final isLoggedIn = authViewModel.isLoggedIn; // Unused for now as we redirect to home regardless

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00C639), // AppColors.successGreen
              Color(0xFF007022), // Darker green
            ],
          ),
        ),
        child: Stack(
          children: [
            // Arka plan desenleri (Hafif daireler)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Merkez içerik
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo Asset
                          Container(
                            width: 200,
                            height: 200,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Slogan
                          Text(
                            'Alışverişin kolay yolu',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 60),

                          // Modern Loading Dots
                          SizedBox(
                            height: 30,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    final delay = index * 0.15;
                                    final animValue =
                                        (_animationController.value - delay)
                                            .clamp(0.0, 1.0);
                                    final scale =
                                        0.5 +
                                        (0.5 *
                                            (1.0 -
                                                ((animValue * 2 - 1).abs())));

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.9),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.5 * scale,
                                            ),
                                            blurRadius: 8 * scale,
                                            spreadRadius: 2 * scale,
                                          ),
                                        ],
                                      ),
                                      transform: Matrix4.identity()
                                        ..scale(scale),
                                    );
                                  },
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Alt kısım - Versiyon
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
