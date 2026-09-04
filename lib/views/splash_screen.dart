import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/version_check_service.dart';
import 'whats_new_screen.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _start();
  }

  Future<void> _start() async {
    final package = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = package.version);
    try {
      final result = await VersionCheckService().checkVersion();
      if (!mounted) return;
      if (result == null) {
        await CustomDialog.show(
          context: context,
          title: 'Bağlantı kurulamadı',
          message:
              'Market bilgilerine ulaşamadık. İnternet bağlantınızı kontrol edip yeniden deneyin.',
          confirmButtonText: 'Yeniden dene',
          showCancelButton: false,
          icon: Icons.wifi_off_rounded,
          isDestructive: true,
          onConfirm: () {
            Navigator.pop(context);
            _start();
          },
        );
        return;
      }
      if (result.isUpdateRequired) {
        showUpdateDialog(
          context,
          isMandatory: result.isMandatory,
          storeUrl: result.storeUrl,
          latestVersion: result.latestVersion,
        );
        if (result.isMandatory) return;
      }
      await _navigate();
    } catch (_) {
      if (mounted) await _navigate();
    }
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool('isFirstTime') ?? true) {
      context.go('/onboarding');
      return;
    }
    if (await WhatsNewScreen.shouldShow(_version) && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WhatsNewScreen(
          currentVersion: _version,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ));
    }
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _animation, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: const Color(0xFF053D2A),
      body: Stack(
        children: [
          const Positioned.fill(child: _SplashBackdrop()),
          SafeArea(
            child: FadeTransition(
              opacity: fade,
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 58),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: .72, end: 1).animate(
                              CurvedAnimation(
                                parent: _animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB9EB67),
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x55000000),
                                    blurRadius: 38,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 58,
                                color: Color(0xFF06452E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'BENİM MARKETİM',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'İhtiyacın olan her şey, birkaç dokunuş uzağında.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 22,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFB9EB67),
                            backgroundColor: Color(0x22FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _version.isEmpty
                              ? 'Market hazırlanıyor'
                              : 'v$_version',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: .45),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BackdropPainter());
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lime = Paint()
      ..color = const Color(0xFFB9EB67).withValues(alpha: .09);
    final green = Paint()
      ..color = const Color(0xFF15965C).withValues(alpha: .25);
    canvas.drawCircle(Offset(size.width * .9, size.height * .08), 150, lime);
    canvas.drawCircle(Offset(size.width * .05, size.height * .78), 210, green);
    canvas.drawCircle(Offset(size.width * .85, size.height * .7), 70, lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
