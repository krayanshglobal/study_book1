import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_logo.dart';

// ─── Timing helpers ────────────────────────────────────────────────────────
double _t(double ms) => ms / 3200.0;

// ─── Glowing particle model ───────────────────────────────────────────────
class _Particle {
  final double angle;   // radians around origin
  final double radius;  // distance from center
  final double size;    // dot size
  final double speed;   // animation phase offset
  final Color color;

  const _Particle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.speed,
    required this.color,
  });
}

final _kParticles = List<_Particle>.generate(12, (i) {
  final rng = math.Random(i * 31 + 7);
  final colors = [AppColors.blue, AppColors.violet, const Color(0xFF60A5FA)];
  return _Particle(
    angle: (i / 12) * math.pi * 2,
    radius: 90 + rng.nextDouble() * 40,
    size: 3.5 + rng.nextDouble() * 3,
    speed: rng.nextDouble() * 0.6,
    color: colors[i % colors.length],
  );
});

// ─── Particle painter ─────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 (particle animation cycle)
  final double opacity;

  const _ParticlePainter({required this.progress, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final p in _kParticles) {
      final phase = (progress + p.speed) % 1.0;
      final wobble = math.sin(phase * math.pi * 2) * 8;
      final r = p.radius + wobble;
      final x = cx + math.cos(p.angle + progress * math.pi * 0.4) * r;
      final y = cy + math.sin(p.angle + progress * math.pi * 0.4) * r;
      final alpha = ((0.4 + 0.6 * math.sin(phase * math.pi)) * opacity)
          .clamp(0.0, 1.0);

      // Glow
      final glowPaint = Paint()
        ..color = p.color.withAlpha((alpha * 60).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), p.size + 3, glowPaint);

      // Core dot
      final dotPaint = Paint()
        ..color = p.color.withAlpha((alpha * 220).round());
      canvas.drawCircle(Offset(x, y), p.size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.opacity != opacity;
}

// ─── Splash Screen ───────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Main sequence controller (3.2s)
  late final AnimationController _ctrl;
  // Continuous particle loop controller
  late final AnimationController _particleCtrl;

  // ── Logo
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // ── Title
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  // ── Tagline
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  // ── Particles
  late final Animation<double> _particleFade;

  // ── Exit
  late final Animation<double> _exitFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // ── Main sequence ──────────────────────────────────────────────────────
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Logo fade & scale  0s → 0.9s
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(0), _t(600), curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(200), _t(900), curve: Curves.easeOutCubic),
      ),
    );

    // Title  1.0s → 1.4s
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(1000), _t(1400), curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Interval(_t(1000), _t(1400), curve: Curves.easeOutCubic),
    ));

    // Tagline  1.5s → 1.9s
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(1500), _t(1900), curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Interval(_t(1500), _t(1900), curve: Curves.easeOutCubic),
    ));

    // Particles visibility  1.2s → 2.0s
    _particleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(1200), _t(2000), curve: Curves.easeOut),
      ),
    );

    // Exit  2.8s → 3.2s
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_t(2800), _t(3200), curve: Curves.easeIn),
      ),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _navigate();
    });

    // ── Continuous particle loop ───────────────────────────────────────────
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _ctrl.forward();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    final authState = ref.read(authProvider);
    if (authState.isLoading) {
      ref.listenManual<AuthState>(authProvider, (_, next) {
        if (!next.isLoading && mounted && !_navigated) _doNavigate(next);
      });
    } else {
      _doNavigate(authState);
    }
  }

  void _doNavigate(AuthState auth) {
    if (_navigated || !mounted) return;
    _navigated = true;
    if (auth.user != null) {
      context.go(auth.user!.isAdmin ? '/admin' : '/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Opacity(
            opacity: _exitFade.value,
            child: Stack(
              children: [
                // ── Particle layer ───────────────────────────────────────
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ParticlePainter(
                        progress: _particleCtrl.value,
                        opacity: _particleFade.value,
                      ),
                      size: MediaQuery.sizeOf(context),
                    );
                  },
                ),

                // ── Content layer ────────────────────────────────────────
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: const AppLogo(size: 120),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Title
                          FadeTransition(
                            opacity: _titleFade,
                            child: SlideTransition(
                              position: _titleSlide,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    AppColors.navy,
                                    AppColors.blue,
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'StudyBook',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white, // masked
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Tagline
                          FadeTransition(
                            opacity: _taglineFade,
                            child: SlideTransition(
                              position: _taglineSlide,
                              child: Text(
                                'LEARN  •  FOCUS  •  ACHIEVE',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.violet,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
