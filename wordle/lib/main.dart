
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const WordleApp());
}

class WordleApp extends StatelessWidget {
  const WordleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wordle Plus',
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

class AnimatedSpaceBackground extends StatefulWidget {
  const AnimatedSpaceBackground({
    super.key,
    required this.child,
    required this.gradientColors,
    this.isDayMode = false,
  });

  final Widget child;
  final List<Color> gradientColors;
  final bool isDayMode;

  @override
  State<AnimatedSpaceBackground> createState() => _AnimatedSpaceBackgroundState();
}

class _AnimatedSpaceBackgroundState extends State<AnimatedSpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 42),
  )..repeat();

  // Normalized pointer position (-1 to 1). The animation controller keeps
  // repainting, so updates from a mouse or trackpad smoothly affect parallax.
  Offset _parallax = Offset.zero;

  void _updateParallax(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = ((localPosition.dx / size.width) * 2 - 1)
        .clamp(-1.0, 1.0)
        .toDouble();
    final dy = ((localPosition.dy / size.height) * 2 - 1)
        .clamp(-1.0, 1.0)
        .toDouble();
    _parallax = Offset(dx, dy);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
            ),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              // Also respond to pointer movement on touch screens / touchpads.
              onPointerMove: (event) => _updateParallax(
                event.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
              ),
              onPointerHover: (event) => _updateParallax(
                event.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
              ),
              child: MouseRegion(
                opaque: false,
                // Trackpad cursor movement is delivered here on desktop browsers.
                onHover: (event) => _updateParallax(
                  event.localPosition,
                  Size(constraints.maxWidth, constraints.maxHeight),
                ),
                onExit: (_) {
                  _parallax = Offset.zero;
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: _SpacePainter(
                            progress: _controller.value,
                            isDayMode: widget.isDayMode,
                            parallax: _parallax,
                          ),
                          isComplex: true,
                          willChange: true,
                        ),
                      ),
                    ),
                    widget.child,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A layered, procedurally drawn space scene. The painter is kept behind the
/// interactive UI, so stars and planets never intercept taps or keyboard input.
class _SpacePainter extends CustomPainter {
  _SpacePainter({
    required this.progress,
    required this.isDayMode,
    required this.parallax,
  });

  final double progress;
  final bool isDayMode;
  final Offset parallax;

  // Different timings and trajectories make shooting stars appear at several
  // points in the sky instead of repeating as a single obvious loop.
  static const List<_ShootingStar> _shootingStars = [
    _ShootingStar(phase: 0.04, speed: 4.2, duration: 0.16, startX: 0.02, startY: 0.10, travelX: 0.78, travelY: 0.24, tailX: 0.075, tailY: 0.032),
    _ShootingStar(phase: 0.31, speed: 3.4, duration: 0.14, startX: 0.52, startY: 0.05, travelX: 0.40, travelY: 0.38, tailX: 0.080, tailY: 0.036),
    _ShootingStar(phase: 0.57, speed: 5.1, duration: 0.15, startX: 0.06, startY: 0.43, travelX: 0.78, travelY: 0.19, tailX: 0.064, tailY: 0.029),
    _ShootingStar(phase: 0.76, speed: 3.8, duration: 0.17, startX: 0.38, startY: 0.22, travelX: 0.58, travelY: 0.45, tailX: 0.085, tailY: 0.039),
    _ShootingStar(phase: 0.90, speed: 4.7, duration: 0.13, startX: 0.10, startY: 0.72, travelX: 0.65, travelY: -0.42, tailX: 0.072, tailY: -0.035),
    _ShootingStar(phase: 0.43, speed: 5.8, duration: 0.12, startX: 0.72, startY: 0.02, travelX: 0.20, travelY: 0.48, tailX: 0.055, tailY: 0.034),
  ];

  static final List<_Star> _stars = List.generate(190, (i) {
    final random = Random(i * 97 + 13);
    return _Star(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: (0.45 + pow(random.nextDouble(), 1.8) * 1.9).toDouble(),
      phase: random.nextDouble() * pi * 2,
      drift: 0.006 + random.nextDouble() * 0.025,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final cycle = progress * 2 * pi;

    // Noticeable depth parallax: the celestial scene glides opposite to the
    // pointer while the gradient stays anchored. The larger travel is intended
    // to be visible with a laptop trackpad, not just in a close inspection.
    canvas.save();
    canvas.translate(-parallax.dx * 64, -parallax.dy * 44);

    // Broad, feathered nebula clouds create depth instead of a flat gradient.
    if (isDayMode) {
      _drawNebula(canvas,
          Offset(size.width * (0.16 + 0.025 * sin(cycle)), size.height * 0.22),
          shortest * 0.62, const Color(0xFF9D8BFF), 0.22);
      _drawNebula(canvas,
          Offset(size.width * 0.82, size.height * (0.50 + 0.035 * cos(cycle))),
          shortest * 0.55, const Color(0xFF70D9F1), 0.19);
      _drawNebula(canvas,
          Offset(size.width * 0.55, size.height * 0.93),
          shortest * 0.48, const Color(0xFFFFA8CC), 0.20);
      _drawSun(canvas, size,
          Offset(size.width * (0.79 + 0.012 * sin(cycle * 0.45)), size.height * 0.18),
          shortest * 0.055);
    } else {
      _drawNebula(canvas,
          Offset(size.width * (0.18 + 0.035 * sin(cycle)), size.height * 0.34),
          shortest * 0.70, const Color(0xFF704BFF), 0.30);
      _drawNebula(canvas,
          Offset(size.width * 0.83, size.height * (0.48 + 0.04 * cos(cycle * 0.72))),
          shortest * 0.64, const Color(0xFF176DD1), 0.27);
      _drawNebula(canvas,
          Offset(size.width * 0.54, size.height * 0.93),
          shortest * 0.53, const Color(0xFFB33C9E), 0.24);
      _drawNebula(canvas,
          Offset(size.width * 0.47, size.height * 0.10),
          shortest * 0.38, const Color(0xFF25B7D5), 0.14);
    }

    // A few very faint orbital tracks add scale and depth to the scene.
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (isDayMode ? const Color(0xFF5864A8) : const Color(0xFFB9BCFF))
          .withValues(alpha: isDayMode ? 0.09 : 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.20, size.height * 0.29),
        width: shortest * 0.44,
        height: shortest * 0.17,
      ),
      orbitPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.83, size.height * 0.70),
        width: shortest * 0.31,
        height: shortest * 0.12,
      ),
      orbitPaint,
    );

    // Three depth layers of stars: dim distant dust, mid-sized stars, and
    // larger twinkling points. In day mode they become muted indigo stars.
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final star in _stars) {
      final twinkle = 0.30 +
          0.66 * (0.5 + 0.5 * sin(cycle * (0.7 + star.radius * 0.15) + star.phase));
      final x = (star.x + progress * star.drift) % 1.0 * size.width;
      final y = (star.y + progress * star.drift * 0.46) % 1.0 * size.height;
      final alpha = isDayMode
          ? (0.08 + 0.26 * twinkle).clamp(0.0, 1.0).toDouble()
          : (0.22 + 0.72 * twinkle).clamp(0.0, 1.0).toDouble();
      starPaint.color = isDayMode
          ? const Color(0xFF464A87).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), star.radius, starPaint);

      if (star.radius > 1.85 && twinkle > 0.79) {
        final sparklePaint = Paint()
          ..strokeWidth = isDayMode ? 0.6 : 0.85
          ..strokeCap = StrokeCap.round
          ..color = (isDayMode ? const Color(0xFF7477B5) : const Color(0xFFE7F7FF))
              .withValues(alpha: isDayMode ? 0.22 : 0.58);
        final arm = star.radius * (isDayMode ? 1.2 : 1.8);
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), sparklePaint);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), sparklePaint);
      }
    }

    // The ringed planet, coral world and small blue planet drift gently.
    _drawPlanet(
      canvas,
      Offset(size.width * (0.12 + 0.022 * sin(cycle * 0.42)),
          size.height * (0.24 + 0.026 * cos(cycle * 0.40))),
      shortest * 0.075,
      isDayMode ? const Color(0xFF8D9FFF) : const Color(0xFF7A7FF0),
      isDayMode ? const Color(0xFF4055A9) : const Color(0xFF24245E),
      ring: true,
      ringColor: isDayMode ? const Color(0xFFB58DCE) : const Color(0xFFC5A9FF),
    );
    _drawPlanet(
      canvas,
      Offset(size.width * (0.87 + 0.022 * cos(cycle * 0.35)),
          size.height * (0.73 + 0.022 * sin(cycle * 0.38))),
      shortest * 0.053,
      isDayMode ? const Color(0xFFFFC3A1) : const Color(0xFFFFA18D),
      isDayMode ? const Color(0xFFD45C83) : const Color(0xFF8D3A77),
    );
    _drawPlanet(
      canvas,
      Offset(size.width * (0.78 + 0.014 * sin(cycle * 0.51)),
          size.height * (0.12 + 0.014 * cos(cycle * 0.43))),
      shortest * 0.026,
      isDayMode ? const Color(0xFF9FF4E8) : const Color(0xFF80F0F1),
      isDayMode ? const Color(0xFF348BA9) : const Color(0xFF1F6499),
    );

    // Multiple luminous shooting stars cross the sky on different trajectories.
    // Their tails fade at both ends so the effect feels more natural than a line.
    for (final comet in _shootingStars) {
      final shot = (progress * comet.speed + comet.phase) % 1.0;
      if (shot >= comet.duration) continue;

      final t = shot / comet.duration;
      final fade = (sin(pi * t) * (isDayMode ? 0.42 : 0.88))
          .clamp(0.0, 1.0)
          .toDouble();
      final start = Offset(
        size.width * (comet.startX + comet.travelX * t),
        size.height * (comet.startY + comet.travelY * t),
      );
      final end = start - Offset(size.width * comet.tailX, size.height * comet.tailY);
      final cometColor = isDayMode
          ? const Color(0xFF737DCA)
          : const Color(0xFFEAFBFF);
      final tailPaint = Paint()
        ..strokeWidth = isDayMode ? 1.3 : 2.0
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            cometColor.withValues(alpha: 0),
            cometColor.withValues(alpha: fade),
          ],
        ).createShader(Rect.fromPoints(end, start));
      canvas.drawLine(end, start, tailPaint);

      final headPaint = Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);
      canvas.drawCircle(start, isDayMode ? 1.8 : 2.5, headPaint);
      final corePaint = Paint()..color = Colors.white.withValues(alpha: fade);
      canvas.drawCircle(start, isDayMode ? 0.7 : 1.0, corePaint);
    }

    canvas.restore();
  }

  void _drawNebula(Canvas canvas, Offset center, double radius,
      Color color, double strength) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: strength),
          color.withValues(alpha: strength * 0.42),
          color.withValues(alpha: strength * 0.10),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.36, 0.70, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);

    // A second off-centre cloud keeps the nebula from looking like a perfect orb.
    final cloudCenter = center + Offset(radius * 0.18, -radius * 0.13);
    final cloudRect = Rect.fromCircle(center: cloudCenter, radius: radius * 0.57);
    final cloudPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: strength * 0.48),
          color.withValues(alpha: strength * 0.12),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(cloudRect);
    canvas.drawCircle(cloudCenter, radius * 0.57, cloudPaint);
  }

  void _drawSun(Canvas canvas, Size size, Offset center, double radius) {
    final haloRect = Rect.fromCircle(center: center, radius: radius * 3.3);
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD98B).withValues(alpha: 0.40),
          const Color(0xFFFFB9A5).withValues(alpha: 0.16),
          const Color(0xFFFFD98B).withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(haloRect);
    canvas.drawCircle(center, radius * 3.3, halo);

    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.38),
        colors: const [Color(0xFFFFF8D9), Color(0xFFFFD17A), Color(0xFFFF9B87)],
        stops: const [0, 0.68, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sunPaint);

    final flarePaint = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFE7B1).withValues(alpha: 0.26);
    canvas.drawLine(Offset(center.dx - radius * 1.5, center.dy),
        Offset(center.dx + radius * 1.5, center.dy), flarePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius * 1.5),
        Offset(center.dx, center.dy + radius * 1.5), flarePaint);
  }

  void _drawPlanet(Canvas canvas, Offset center, double radius, Color light,
      Color dark, {bool ring = false, Color ringColor = const Color(0xFFC5A9FF)}) {
    final glowRect = Rect.fromCircle(center: center, radius: radius * 1.8);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          light.withValues(alpha: isDayMode ? 0.20 : 0.28),
          light.withValues(alpha: isDayMode ? 0.08 : 0.12),
          light.withValues(alpha: 0),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(glowRect);
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    // Put Saturn's rings behind the globe to give the planet more depth.
    if (ring) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.28);
      final ringRect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.15,
        height: radius * 0.88,
      );
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.23
        ..color = ringColor.withValues(alpha: isDayMode ? 0.70 : 0.64);
      canvas.drawOval(ringRect, ringPaint);
      final thinRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.035
        ..color = Colors.white.withValues(alpha: isDayMode ? 0.48 : 0.35);
      canvas.drawOval(ringRect.inflate(radius * 0.16), thinRingPaint);
      canvas.restore();
    }

    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.16,
        colors: [light, dark, const Color(0xFF080B20).withValues(alpha: 0.68)],
        stops: const [0, 0.62, 1],
      ).createShader(sphereRect);
    canvas.drawCircle(center, radius, spherePaint);

    // Subtle curved surface bands add a little planetary texture.
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.11
      ..color = light.withValues(alpha: isDayMode ? 0.18 : 0.15);
    for (var i = -2; i <= 2; i++) {
      final y = center.dy + radius * i * 0.31;
      final path = Path()
        ..moveTo(center.dx - radius, y + radius * 0.10)
        ..quadraticBezierTo(center.dx, y - radius * 0.18,
            center.dx + radius, y + radius * 0.06);
      canvas.drawPath(path, bandPaint);
    }
    canvas.restore();

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..color = light.withValues(alpha: isDayMode ? 0.24 : 0.30);
    canvas.drawCircle(center, radius * 1.015, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isDayMode != isDayMode ||
      oldDelegate.parallax != parallax;
}

class _ShootingStar {
  const _ShootingStar({
    required this.phase,
    required this.speed,
    required this.duration,
    required this.startX,
    required this.startY,
    required this.travelX,
    required this.travelY,
    required this.tailX,
    required this.tailY,
  });

  final double phase;
  final double speed;
  final double duration;
  final double startX;
  final double startY;
  final double travelX;
  final double travelY;
  final double tailX;
  final double tailY;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.drift,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
  final double drift;
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user != null) {
          return WordleGame(key: ValueKey(user.id));
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool createAccount = false;
  bool loading = false;
  bool obscurePassword = true;
  String? errorText;
  String? infoText;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorText = 'Enter your email and password.';
        infoText = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        errorText = 'Password must be at least 6 characters.';
        infoText = null;
      });
      return;
    }

    setState(() {
      loading = true;
      errorText = null;
      infoText = null;
    });

    try {
      if (createAccount) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: Uri.base.origin,
        );
        if (!mounted) return;
        setState(() {
          infoText = response.session == null
              ? 'Account created. Check your email to confirm, then sign in.'
              : 'Account created successfully!';
        });
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => errorText = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => errorText = 'Could not connect. Check your URL and key.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        errorText = 'Enter your email first, then tap Forgot password.';
        infoText = null;
      });
      return;
    }

    setState(() {
      loading = true;
      errorText = null;
      infoText = null;
    });
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: Uri.base.origin,
      );
      if (mounted) {
        setState(() => infoText = 'If that account exists, a reset email has been sent.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => errorText = e.message);
    } catch (_) {
      if (mounted) setState(() => errorText = 'Could not send reset email. Check your settings.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9B72FF);
    const pink = Color(0xFFFF6FAE);
    const ink = Color(0xFF17152B);

    return Scaffold(
      body: AnimatedSpaceBackground(
        gradientColors: const [ink, Color(0xFF29204A), Color(0xFF182B48)],
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFF242337),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: purple.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: pink, size: 42),
                      const SizedBox(height: 8),
                      const Text(
                        'WORDLE PLUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        createAccount ? 'Create your player account' : 'Welcome back, player!',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.email_outlined, color: purple),
                          filled: true,
                          fillColor: ink,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofillHints: createAccount
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        onSubmitted: (_) => loading ? null : submit(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password (at least 6 characters)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.lock_outline, color: purple),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            icon: Icon(
                              obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                          ),
                          filled: true,
                          fillColor: ink,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(errorText!, style: const TextStyle(color: Color(0xFFFF8B9A)), textAlign: TextAlign.center),
                      ],
                      if (infoText != null) ...[
                        const SizedBox(height: 12),
                        Text(infoText!, style: const TextStyle(color: Color(0xFF8FE3B2)), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(createAccount ? 'Create account' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (!createAccount)
                        TextButton(
                          onPressed: loading ? null : resetPassword,
                          child: const Text('Forgot password?', style: TextStyle(color: Colors.white70)),
                        ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  createAccount = !createAccount;
                                  errorText = null;
                                  infoText = null;
                                }),
                        child: Text(
                          createAccount ? 'Already have an account? Sign in' : 'New here? Create an account',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFF9AC4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WordleGame extends StatefulWidget {
  const WordleGame({super.key});

  @override
  State<WordleGame> createState() => _WordleGameState();
}

class _WordleGameState extends State<WordleGame> {
  // Common five-letter answers.
  // Keep this list in the same order for stable daily words.
  final List<String> answerPool = [
    'ABOUT', 'ABOVE', 'ACUTE', 'ADMIT', 'ADOPT',
    'AFTER', 'AGAIN', 'AGENT', 'AGREE', 'ALARM',
    'ALBUM', 'ALERT', 'ALIEN', 'ALIGN', 'ALIVE',
    'ALLOW', 'ALONE', 'ALONG', 'ALTER', 'ANGEL',
    'ANGER', 'ANGLE', 'ANGRY', 'APART', 'APPLE',
    'APPLY', 'ARENA', 'ARGUE', 'ARISE', 'ARRAY',
    'ASIDE', 'AUDIO', 'AVOID', 'AWAKE', 'AWARD',
    'AWARE', 'BADLY', 'BAKER', 'BASES', 'BASIC',
    'BEACH', 'BEGAN', 'BEGIN', 'BEING', 'BELOW',
    'BENCH', 'BIRTH', 'BLACK', 'BLAME', 'BLANK',
    'BLAST', 'BLIND', 'BLOCK', 'BLOOD', 'BOARD',
    'BOOST', 'BOOTH', 'BOUND', 'BRAIN', 'BRAND',
    'BREAD', 'BREAK', 'BRICK', 'BRIEF', 'BRING',
    'BROAD', 'BROKE', 'BROWN', 'BUILD', 'BUILT',
    'BUYER', 'CABIN', 'CABLE', 'CARRY', 'CATCH',
    'CAUSE', 'CHAIN', 'CHAIR', 'CHART', 'CHASE',
    'CHEAP', 'CHECK', 'CHEST', 'CHIEF', 'CHILD',
    'CHINA', 'CHOSE', 'CIVIL', 'CLAIM', 'CLASS',
    'CLEAN', 'CLEAR', 'CLICK', 'CLOCK', 'CLOSE',
    'COACH', 'COAST', 'COULD', 'COUNT', 'COURT',
    'COVER', 'CRAFT', 'CRANE', 'CRASH', 'CRAZY',
    'CREAM', 'CRIME', 'CROSS', 'CROWD', 'CROWN',
    'CURVE', 'CYCLE', 'DAILY', 'DANCE', 'DATED',
    'DEALT', 'DEATH', 'DEBUT', 'DELAY', 'DEPTH',
    'DOING', 'DOUBT', 'DOZEN', 'DRAFT', 'DRAMA',
    'DREAM', 'DRESS', 'DRINK', 'DRIVE', 'DROVE',
    'DYING', 'EAGER', 'EARLY', 'EARTH', 'EIGHT',
    'ELITE', 'EMPTY', 'ENEMY', 'ENJOY', 'ENTER',
    'ENTRY', 'EQUAL', 'ERROR', 'EVENT', 'EVERY',
    'EXACT', 'EXIST', 'EXTRA', 'FAITH', 'FALSE',
    'FAULT', 'FIBER', 'FIELD', 'FIFTH', 'FIFTY',
    'FIGHT', 'FINAL', 'FIRST', 'FIXED', 'FLASH',
    'FLEET', 'FLOOR', 'FLUID', 'FOCUS', 'FORCE',
    'FORTH', 'FORTY', 'FORUM', 'FOUND', 'FRAME',
    'FRANK', 'FRAUD', 'FRESH', 'FRONT', 'FRUIT',
    'FULLY', 'FUNNY', 'GIANT', 'GIVEN', 'GLASS',
    'GLOBE', 'GOING', 'GRACE', 'GRADE', 'GRAND',
    'GRANT', 'GRASS', 'GREAT', 'GREEN', 'GROSS',
    'GROUP', 'GROWN', 'GUARD', 'GUESS', 'GUEST',
    'GUIDE', 'HAPPY', 'HEART', 'HEAVY', 'HENCE',
    'HORSE', 'HOTEL', 'HOUSE', 'HUMAN', 'IDEAL',
    'IMAGE', 'INDEX', 'INNER', 'INPUT', 'ISSUE',
    'JAPAN', 'JIMMY', 'JOINT', 'JONES', 'JUDGE',
    'KNOWN', 'LABEL', 'LARGE', 'LASER', 'LATER',
    'LAUGH', 'LAYER', 'LEARN', 'LEASE', 'LEAST',
    'LEAVE', 'LEGAL', 'LEVEL', 'LEWIS', 'LIGHT',
    'LIMIT', 'LINKS', 'LIVES', 'LOCAL', 'LOGIC',
    'LOOSE', 'LOWER', 'LUCKY', 'LUNCH', 'LYING',
    'MAGIC', 'MAJOR', 'MAKER', 'MARCH', 'MARIA',
    'MATCH', 'MAYBE', 'MAYOR', 'MEANT', 'MEDIA',
    'METAL', 'MIGHT', 'MINOR', 'MINUS', 'MIXED',
    'MODEL', 'MONEY', 'MONTH', 'MORAL', 'MOTOR',
    'MOUNT', 'MOUSE', 'MOUTH', 'MOVED', 'MOVIE',
    'MUSIC', 'NEEDS', 'NEVER', 'NEWLY', 'NIGHT',
    'NOISE', 'NORTH', 'NOTED', 'NOVEL', 'NURSE',
    'OCCUR', 'OCEAN', 'OFFER', 'OFTEN', 'ORDER',
    'OTHER', 'OUGHT', 'PAINT', 'PANEL', 'PAPER',
    'PARTY', 'PEACE', 'PETER', 'PHASE', 'PHONE',
    'PHOTO', 'PIANO', 'PIECE', 'PILOT', 'PITCH',
    'PLACE', 'PLAIN', 'PLANE', 'PLANT', 'PLATE',
    'POINT', 'POUND', 'POWER', 'PRESS', 'PRICE',
    'PRIDE', 'PRIME', 'PRINT', 'PRIOR', 'PRIZE',
    'PROOF', 'PROUD', 'PROVE', 'QUEEN', 'QUICK',
    'QUIET', 'QUITE', 'RADIO', 'RAISE', 'RANGE',
    'RAPID', 'RATIO', 'REACH', 'READY', 'REALM',
    'REBEL', 'REFER', 'RELAX', 'REPAY', 'REPLY',
    'RIGHT', 'RIGID', 'RIVAL', 'RIVER', 'ROBOT',
    'ROGER', 'ROMAN', 'ROUGH', 'ROUND', 'ROUTE',
    'ROYAL', 'RURAL', 'SCALE', 'SCENE', 'SCOPE',
    'SCORE', 'SENSE', 'SERVE', 'SEVEN', 'SHALL',
    'SHAPE', 'SHARE', 'SHARP', 'SHEET', 'SHELF',
    'SHELL', 'SHIFT', 'SHINE', 'SHIRT', 'SHOCK',
    'SHOOT', 'SHORT', 'SHOWN', 'SIGHT', 'SINCE',
    'SKILL', 'SLEEP', 'SLIDE', 'SMALL', 'SMART',
    'SMILE', 'SMITH', 'SMOKE', 'SOLID', 'SOLVE',
    'SORRY', 'SOUND', 'SOUTH', 'SPACE', 'SPARE',
    'SPEAK', 'SPEED', 'SPEND', 'SPENT', 'SPLIT',
    'SPOKE', 'SPORT', 'STAFF', 'STAGE', 'STAKE',
    'STAND', 'START', 'STATE', 'STEAM', 'STEEL',
    'STICK', 'STILL', 'STOCK', 'STONE', 'STOOD',
    'STORE', 'STORM', 'STORY', 'STRIP', 'STUCK',
    'STUDY', 'STUFF', 'STYLE', 'SUGAR', 'SUITE',
    'SUPER', 'SWEET', 'TABLE', 'TAKEN', 'TASTE',
    'TAXES', 'TEACH', 'TEAMS', 'TEARS', 'TERRY',
    'TEXAS', 'THANK', 'THEFT', 'THEIR', 'THEME',
    'THERE', 'THESE', 'THICK', 'THING', 'THINK',
    'THIRD', 'THOSE', 'THREE', 'THREW', 'THROW',
    'TIGHT', 'TIMES', 'TIRED', 'TITLE', 'TODAY',
    'TOPIC', 'TOTAL', 'TOUCH', 'TOUGH', 'TOWER',
    'TRACK', 'TRADE', 'TRAIN', 'TREAT', 'TREND',
    'TRIAL', 'TRIBE', 'TRICK', 'TRIED', 'TRIES',
    'TRUCK', 'TRULY', 'TRUST', 'TRUTH', 'TWICE',
    'UNDER', 'UNDUE', 'UNION', 'UNITY', 'UNTIL',
    'UPPER', 'UPSET', 'URBAN', 'USAGE', 'USUAL',
    'VALID', 'VALUE', 'VIDEO', 'VIRUS', 'VISIT',
    'VITAL', 'VOICE', 'WASTE', 'WATCH', 'WATER',
    'WHEEL', 'WHERE', 'WHICH', 'WHILE', 'WHITE',
    'WHOLE', 'WHOSE', 'WOMAN', 'WOMEN', 'WORLD',
    'WORRY', 'WORSE', 'WORST', 'WORTH', 'WOULD',
    'WRITE', 'WRONG', 'WROTE', 'YOUNG', 'YOUTH',
    'ZEBRA',
  ];

  final List<String> guesses = [];
  final Random random = Random();
  final FocusNode _gameFocusNode =
      FocusNode(debugLabel: 'Wordle Plus keyboard');

  Set<String> validWords = {};

  late String answer;

  String current = '';
  String message = 'Guess the five-letter word!';

  bool dailyMode = true;
  bool darkMode = true;
  bool hintUsed = false;
  bool finished = false;
  bool dictionaryLoading = true;

  int wins = 0;
  int games = 0;
  int streak = 0;
  int bestStreak = 0;

  String? dailyCompletedDate;
  int selectedTab = 0; // 0 = dashboard, 1 = play, 2 = stats
  String? lastDailyActivityDate;
  int streakFreezes = 2; // Players start with two streak freezes.
  int lastFreezeRewardStreak = 0;
  List<String> dailyActivityDates = [];
  List<String> streakFreezeDates = [];

  static const Color green = Color(0xFF35B86B);
  static const Color yellow = Color(0xFFFFC857);
  static const Color gray = Color(0xFF555B70);
  static const Color purple = Color(0xFF9B72FF);
  static const Color pink = Color(0xFFFF6FAE);
  static const Color unusedKeyDark = Color(0xFF947BFA);
  static const Color usedKeyDark = Color(0xFF3B3E53);
  static const Color unusedKeyLight = Color(0xFF8065D9);
  static const Color usedKeyLight = Color(0xFFDAD6E6);

  @override
  void initState() {
    super.initState();
    answer = dailyWordForToday();
    initializeApp();
  }

  String _dateKey(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  DateTime _dateFromKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  List<String> _readDateList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item))
          .toSet()
          .toList()
        ..sort();
    }
    return <String>[];
  }

  String? _normalizeDateKey(dynamic value) {
    if (value == null) return null;
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(value.toString());
    return match?.group(0);
  }

  String? _latestDateKey(String? first, String? second) {
    if (first == null || first.isEmpty) return (second == null || second.isEmpty) ? null : second;
    if (second == null || second.isEmpty) return first;
    return first.compareTo(second) >= 0 ? first : second;
  }

  bool _isDateKeyAfter(String? first, String? second) {
    return first != null && (second == null || first.compareTo(second) > 0);
  }

  bool _timestampIsAfter(String? first, String? second) {
    if (first == null || first.isEmpty) return false;
    final firstDate = DateTime.tryParse(first);
    if (firstDate == null) return false;
    if (second == null || second.isEmpty) return true;
    final secondDate = DateTime.tryParse(second);
    return secondDate == null || firstDate.isAfter(secondDate);
  }

  List<String> _dateKeysAfter(String? previousDate, String endInclusive) {
    if (previousDate == null || previousDate.isEmpty) return [endInclusive];
    final start = _dateFromKey(previousDate);
    final end = _dateFromKey(endInclusive);
    final gap = end.difference(start).inDays;
    if (gap <= 0 || gap > 366) return <String>[];
    return List<String>.generate(
      gap,
      (index) => _dateKey(start.add(Duration(days: index + 1))),
    );
  }

  List<String> _mergeDateLists(List<String> local, List<String> cloud) {
    final valid = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return {...local, ...cloud}
        .where((date) => valid.hasMatch(date))
        .toList()
      ..sort();
  }

  String todayKey() => _dateKey(DateTime.now());

  bool get dailyAlreadyCompleted =>
      dailyCompletedDate == todayKey();

  Future<void> initializeApp() async {
    await loadProgress();
    await loadDictionary();
  }

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;

    final localWins = prefs.getInt('wins') ?? 0;
    final localGames = prefs.getInt('games') ?? 0;
    final localStreak = prefs.getInt('streak') ?? 0;
    final localBestStreak = prefs.getInt('bestStreak') ?? localStreak;
    final localDailyDate = _normalizeDateKey(prefs.getString('dailyCompletedDate'));
    final localLastActivityDate = _normalizeDateKey(prefs.getString('lastDailyActivityDate'));
    final localFreezes = (prefs.getInt('streakFreezes') ?? 2).clamp(0, 2).toInt();
    final grantInitialFreezes = !(prefs.getBool('initialTwoStreakFreezesGranted') ?? false);
    final localLastFreezeReward = prefs.getInt('lastFreezeRewardStreak') ?? 0;
    final localActivityDates = prefs.getStringList('dailyActivityDates') ?? <String>[];
    final localFreezeDates = prefs.getStringList('streakFreezeDates') ?? <String>[];
    final localUpdatedAt = prefs.getString('progressUpdatedAt');

    var loadedWins = localWins;
    var loadedGames = localGames;
    var loadedStreak = localStreak;
    var loadedBestStreak = localBestStreak;
    String? loadedDailyDate = localDailyDate;
    String? loadedLastActivityDate = localLastActivityDate;
    var loadedFreezes = localFreezes;
    var loadedLastFreezeReward = localLastFreezeReward;
    var loadedActivityDates = List<String>.from(localActivityDates);
    var loadedFreezeDates = List<String>.from(localFreezeDates);
    var cloudAvailable = false;
    var shouldSyncMergedState = false;

    if (user != null) {
      try {
        final client = Supabase.instance.client;
        final row = await client
            .from('wordle_stats')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (row == null) {
          // First login: carry any device-local history into the user's row.
          await client.from('wordle_stats').insert({
            'user_id': user.id,
            'games_played': localGames,
            'games_won': localWins,
            'current_streak': localStreak,
            'best_streak': localBestStreak,
            'daily_completed_date': localDailyDate,
            'last_daily_activity_date': localLastActivityDate,
            'streak_freezes': grantInitialFreezes ? 2 : localFreezes,
            'last_freeze_reward_streak': localLastFreezeReward,
            'daily_activity_dates': localActivityDates,
            'streak_freeze_dates': localFreezeDates,
          });
          loadedFreezes = grantInitialFreezes ? 2 : localFreezes;
          cloudAvailable = true;
        } else {
          final cloudWins = (row['games_won'] as num?)?.toInt() ?? 0;
          final cloudGames = (row['games_played'] as num?)?.toInt() ?? 0;
          final cloudStreak = (row['current_streak'] as num?)?.toInt() ?? 0;
          final cloudBestStreak = (row['best_streak'] as num?)?.toInt() ?? cloudStreak;
          final cloudDailyDate = _normalizeDateKey(row['daily_completed_date']);
          final cloudLastActivityDate = _normalizeDateKey(row['last_daily_activity_date']);
          final cloudFreezes = ((row['streak_freezes'] as num?)?.toInt() ?? 2).clamp(0, 2).toInt();
          final cloudLastFreezeReward = (row['last_freeze_reward_streak'] as num?)?.toInt() ?? 0;
          final cloudActivityDates = _readDateList(row['daily_activity_dates']);
          final cloudFreezeDates = _readDateList(row['streak_freeze_dates']);
          final cloudUpdatedAt = row['updated_at']?.toString();

          // Prefer the newest streak/freeze state. Older app versions did not
          // save a local timestamp, so date keys are also used to detect local
          // progress that the cloud did not receive.
          final localStateIsNewer =
              _timestampIsAfter(localUpdatedAt, cloudUpdatedAt) ||
              _isDateKeyAfter(localLastActivityDate, cloudLastActivityDate) ||
              _isDateKeyAfter(localDailyDate, cloudDailyDate);

          loadedWins = max(localWins, cloudWins);
          loadedGames = max(localGames, cloudGames);
          loadedBestStreak = max(localBestStreak, cloudBestStreak);
          loadedDailyDate = _latestDateKey(localDailyDate, cloudDailyDate);
          loadedLastActivityDate = _latestDateKey(localLastActivityDate, cloudLastActivityDate);
          loadedStreak = localStateIsNewer ? localStreak : cloudStreak;
          loadedFreezes = localStateIsNewer ? localFreezes : cloudFreezes;
          loadedLastFreezeReward = localStateIsNewer
              ? localLastFreezeReward
              : cloudLastFreezeReward;
          loadedActivityDates = _mergeDateLists(localActivityDates, cloudActivityDates);
          loadedFreezeDates = _mergeDateLists(localFreezeDates, cloudFreezeDates);

          shouldSyncMergedState = localStateIsNewer ||
              loadedWins != cloudWins ||
              loadedGames != cloudGames ||
              loadedBestStreak != cloudBestStreak ||
              loadedDailyDate != cloudDailyDate ||
              loadedLastActivityDate != cloudLastActivityDate ||
              loadedFreezes != cloudFreezes ||
              loadedLastFreezeReward != cloudLastFreezeReward ||
              loadedActivityDates.length != cloudActivityDates.length ||
              loadedFreezeDates.length != cloudFreezeDates.length;
          cloudAvailable = true;
        }
      } catch (_) {
        // Keep the game usable with local progress when cloud/network access fails.
      }
    }

    if (grantInitialFreezes) loadedFreezes = max(2, loadedFreezes).clamp(0, 2).toInt();

    if (!mounted) return;
    setState(() {
      wins = loadedWins;
      games = loadedGames;
      streak = loadedStreak;
      bestStreak = loadedBestStreak;
      dailyCompletedDate = loadedDailyDate;
      lastDailyActivityDate = loadedLastActivityDate;
      streakFreezes = loadedFreezes.clamp(0, 2).toInt();
      lastFreezeRewardStreak = loadedLastFreezeReward;
      dailyActivityDates = loadedActivityDates;
      streakFreezeDates = loadedFreezeDates;

      if (dailyAlreadyCompleted) {
        finished = true;
        message = "You've completed today's Daily Challenge!";
      } else if (user != null && !cloudAvailable) {
        message = 'Cloud stats unavailable; using saved local stats.';
      }
    });

    if (grantInitialFreezes && (user == null || cloudAvailable)) {
      await prefs.setBool('initialTwoStreakFreezesGranted', true);
      await prefs.setInt('streakFreezes', streakFreezes);
    }

    // Synchronize merged local/cloud activity history so the weekly calendar
    // remains correct across refreshes and devices.
    if (user != null && cloudAvailable && (shouldSyncMergedState || grantInitialFreezes)) {
      unawaited(saveProgress().catchError((Object _) {}));
    }
  }

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.now().toUtc().toIso8601String();
    await prefs.setString('progressUpdatedAt', savedAt);
    await prefs.setInt('wins', wins);
    await prefs.setInt('games', games);
    await prefs.setInt('streak', streak);
    await prefs.setInt('bestStreak', bestStreak);
    await prefs.setInt('streakFreezes', streakFreezes);
    await prefs.setInt('lastFreezeRewardStreak', lastFreezeRewardStreak);
    await prefs.setStringList('dailyActivityDates', dailyActivityDates);
    await prefs.setStringList('streakFreezeDates', streakFreezeDates);

    if (dailyCompletedDate != null) {
      await prefs.setString('dailyCompletedDate', dailyCompletedDate!);
    }
    if (lastDailyActivityDate != null) {
      await prefs.setString('lastDailyActivityDate', lastDailyActivityDate!);
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('wordle_stats').upsert({
        'user_id': user.id,
        'games_played': games,
        'games_won': wins,
        'current_streak': streak,
        'best_streak': bestStreak,
        'daily_completed_date': dailyCompletedDate,
        'last_daily_activity_date': lastDailyActivityDate,
        'streak_freezes': streakFreezes,
        'last_freeze_reward_streak': lastFreezeRewardStreak,
        'daily_activity_dates': dailyActivityDates,
        'streak_freeze_dates': streakFreezeDates,
        'updated_at': savedAt,
      }, onConflict: 'user_id');
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Saved on this device; cloud sync failed.');
      }
    }
  }

  Future<void> _resetStreakAfterDailyLoss() async {
    // A lost Daily Challenge is a streak-miss day. Each uncovered calendar day
    // needs one freeze; freezes are spent only when they can preserve continuity.
    final today = todayKey();
    if (!mounted) return;

    final lastDate = lastDailyActivityDate;
    if (lastDate == today) {
      // Avoid consuming a second freeze if today's date was already recorded.
      await saveProgress();
      return;
    }

    final gap = lastDate == null
        ? 1
        : _dateFromKey(today).difference(_dateFromKey(lastDate)).inDays;
    final datesInGap = (gap > 0 && gap <= 366)
        ? _dateKeysAfter(lastDate, today)
        : <String>[];
    final alreadySuccessful = dailyActivityDates.toSet();
    final alreadyFrozen = streakFreezeDates.toSet();
    final daysNeedingFreeze = datesInGap
        .where((date) => !alreadySuccessful.contains(date) && !alreadyFrozen.contains(date))
        .toList();

    if (streak > 0 &&
        gap > 0 &&
        gap <= streakFreezes &&
        daysNeedingFreeze.length <= streakFreezes) {
      setState(() {
        streakFreezes -= daysNeedingFreeze.length;
        streakFreezeDates = _mergeDateLists(streakFreezeDates, daysNeedingFreeze);
        lastDailyActivityDate = today;
        message = daysNeedingFreeze.isEmpty
            ? '🧊 Your streak remains protected.'
            : '🧊 ${daysNeedingFreeze.length} streak freeze${daysNeedingFreeze.length == 1 ? '' : 's'} used. Your $streak-day streak is safe.';
      });
    } else {
      setState(() {
        streak = 0;
        lastDailyActivityDate = today;
        message = 'Streak lost — no freeze coverage for every missed day. Try again tomorrow!';
      });
    }

    await saveProgress();
  }

  Future<void> _recordDailyActivity() async {
    final today = todayKey();
    if (lastDailyActivityDate == today) return;

    final oldStreak = streak;
    var nextStreak = 1;
    var nextFreezes = streakFreezes;
    var nextLastFreezeRewardStreak = lastFreezeRewardStreak;
    final nextFreezeDates = [...streakFreezeDates];
    var protectedDays = 0;
    var streakRestarted = false;
    var earnedFreeze = false;

    final lastDateKey = lastDailyActivityDate;
    if (lastDateKey == null) {
      // Keep existing legacy streaks when older saved data has no date key.
      nextStreak = streak > 0 ? streak + 1 : 1;
    } else {
      final gap = _dateFromKey(today)
          .difference(_dateFromKey(lastDateKey))
          .inDays;

      if (gap <= 0) {
        nextStreak = max(1, streak);
      } else if (streak <= 0) {
        nextStreak = 1;
      } else if (gap == 1) {
        nextStreak = streak + 1;
      } else {
        final missedDays = gap - 1;
        if (missedDays <= nextFreezes && missedDays <= 2) {
          for (var day = 1; day <= missedDays; day++) {
            final missedDate = _dateKey(
              _dateFromKey(lastDateKey).add(Duration(days: day)),
            );
            if (!dailyActivityDates.contains(missedDate) &&
                !nextFreezeDates.contains(missedDate)) {
              nextFreezeDates.add(missedDate);
              protectedDays++;
            }
          }
          nextFreezes = max(0, nextFreezes - protectedDays);
          nextStreak = streak + 1;
        } else {
          nextStreak = 1;
          streakRestarted = oldStreak > 0;
        }
      }
    }

    final nextActivities = _mergeDateLists(dailyActivityDates, [today]);
    nextFreezeDates.remove(today);
    final cutoff = _dateFromKey(today).subtract(const Duration(days: 365));
    nextActivities.removeWhere((key) => _dateFromKey(key).isBefore(cutoff));
    nextFreezeDates.removeWhere((key) => _dateFromKey(key).isBefore(cutoff));
    nextFreezeDates.sort();

    // Give one freeze at each 7-day milestone, up to two in inventory.
    if ((nextStreak ~/ 7) > (oldStreak ~/ 7)) {
      final milestone = (nextStreak ~/ 7) * 7;
      if (milestone > nextLastFreezeRewardStreak) {
        if (nextFreezes < 2) {
          nextFreezes++;
          earnedFreeze = true;
        }
        nextLastFreezeRewardStreak = milestone;
      }
    }

    if (!mounted) return;
    setState(() {
      lastDailyActivityDate = today;
      dailyActivityDates = nextActivities;
      streakFreezeDates = nextFreezeDates;
      streakFreezes = nextFreezes;
      streak = nextStreak;
      bestStreak = max(bestStreak, nextStreak);

      if (earnedFreeze) {
        message = '🔥 ${streak}-day streak! You earned a streak freeze.';
      } else if (protectedDays > 0) {
        message = '🧊 $protectedDays missed day${protectedDays == 1 ? '' : 's'} protected. Your ${streak}-day streak continues!';
      } else if (streakRestarted) {
        message = 'Welcome back! Your new daily streak starts today.';
      }
    });

    await saveProgress();
  }

  Future<void> loadDictionary() async {
    try {
      final content =
          await rootBundle.loadString('assets/words_alpha.txt');

      final loaded = content
          .split(RegExp(r'\s+'))
          .map((word) => word.trim().toUpperCase())
          .where((word) => RegExp(r'^[A-Z]{5}$').hasMatch(word))
          .toSet();

      loaded.addAll(answerPool);

      if (!mounted) return;

      setState(() {
        validWords = loaded;
        dictionaryLoading = false;

        if (dailyAlreadyCompleted && dailyMode) {
          finished = true;
          message = "Today's Daily Challenge is already complete!";
        } else {
          message = 'Dictionary ready! Let’s play.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        dictionaryLoading = false;
        validWords = answerPool.toSet();

        if (!dailyAlreadyCompleted) {
          message = 'Dictionary unavailable. Using answer words.';
        }
      });
    }
  }

  String dailyWordForToday() {
    // Use the local calendar date for the user's daily reset, then normalize
    // the date components to UTC midnight for daylight-saving-safe arithmetic.
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(2024, 1, 1);
    final day = today.difference(start).inDays;

    return answerPool[day % answerPool.length];
  }

  List<Color> feedbackFor(String guess) {
    final result = List<Color>.filled(5, gray);
    final remaining = <String, int>{};

    for (int i = 0; i < 5; i++) {
      if (guess[i] == answer[i]) {
        result[i] = green;
      } else {
        remaining[answer[i]] =
            (remaining[answer[i]] ?? 0) + 1;
      }
    }

    for (int i = 0; i < 5; i++) {
      if (guess[i] == answer[i]) continue;

      final count = remaining[guess[i]] ?? 0;

      if (count > 0) {
        result[i] = yellow;
        remaining[guess[i]] = count - 1;
      }
    }

    return result;
  }

  String letterAt(int row, int col) {
    if (row < guesses.length) return guesses[row][col];

    if (row == guesses.length && col < current.length) {
      return current[col];
    }

    return '';
  }

  Color tileColor(int row, int col) {
    if (row < guesses.length) {
      return feedbackFor(guesses[row])[col];
    }

    if (row == guesses.length && col < current.length) {
      return darkMode
          ? const Color(0xFF34304B)
          : const Color(0xFFE9E2FF);
    }

    return darkMode
        ? const Color(0xFF242337)
        : const Color(0xFFF1EDFA);
  }

  Color keyColor(String letter) {
    var seenYellow = false;
    var seenGray = false;

    for (final guess in guesses) {
      final feedback = feedbackFor(guess);
      for (int i = 0; i < 5; i++) {
        if (guess[i] != letter) continue;
        // Correct placement always wins over earlier lower-quality feedback.
        if (feedback[i] == green) return green;
        if (feedback[i] == yellow) {
          seenYellow = true;
        } else {
          seenGray = true;
        }
      }
    }

    if (seenYellow) return yellow;
    if (seenGray) return darkMode ? usedKeyDark : usedKeyLight;
    // Untried letters stay vivid so the available keyboard options stand out.
    return darkMode ? unusedKeyDark : unusedKeyLight;
  }

  void typeLetter(String letter) {
    if (finished || dictionaryLoading || current.length >= 5) return;

    setState(() {
      current += letter;
      message = 'Keep going!';
    });
  }

  void deleteLetter() {
    if (finished || current.isEmpty) return;

    setState(() {
      current = current.substring(0, current.length - 1);
    });
  }

  Future<void> submitGuess() async {
    if (finished || dictionaryLoading) return;

    if (current.length != 5) {
      setState(() => message = 'Enter all five letters.');
      return;
    }

    if (!validWords.contains(current)) {
      setState(() => message = 'That word is not in the dictionary.');
      return;
    }

    final submitted = current;
    final wasDaily = dailyMode;
    final won = submitted == answer;
    final lost = !won && guesses.length == 5;

    setState(() {
      guesses.add(submitted);
      current = '';

      if (won) {
        finished = true;
        wins++;
        games++;
        message = '🎉 Amazing! You got it!';
      } else if (lost) {
        finished = true;
        games++;
        message = 'The word was $answer!';
      } else {
        message = '${6 - guesses.length} attempts remaining';
      }

      if ((won || lost) && wasDaily) {
        dailyCompletedDate = todayKey();
      }
    });

    if (won || lost) {
      // Update streak state immediately, but never wait for Supabase/local
      // persistence before displaying the result. A slow network used to leave
      // players stuck on the board with only the inline result message.
      if (wasDaily && won) {
        unawaited(_recordDailyActivity().catchError((Object _) {}));
      } else if (wasDaily && lost) {
        unawaited(_resetStreakAfterDailyLoss().catchError((Object _) {}));
      } else {
        unawaited(saveProgress().catchError((Object _) {}));
      }
    }

    if ((won || lost) && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                won ? Icons.celebration_rounded : Icons.flag_rounded,
                color: won ? const Color(0xFFFFB84D) : pink,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(won ? 'You won!' : 'Out of guesses!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                won
                    ? '🎉 Brilliant work! You guessed the word.'
                    : 'Good try! The word was not guessed in six attempts.',
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  answer,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: won ? green : pink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  won
                      ? 'Solved in ${guesses.length} / 6 attempts'
                      : 'Used all 6 / 6 attempts',
                  textAlign: TextAlign.center,
                ),
              ),
              if (!won && wasDaily) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  void newGame() {
    String next;

    do {
      next = answerPool[random.nextInt(answerPool.length)];
    } while (next == answer && answerPool.length > 1);

    setState(() {
      answer = next;
      dailyMode = false;
      guesses.clear();
      current = '';
      finished = false;
      hintUsed = false;
      message = '✨ Random practice: your turn!';
    });
  }

  void startDailyChallenge() {
    setState(() {
      answer = dailyWordForToday();
      dailyMode = true;
      guesses.clear();
      current = '';
      hintUsed = false;

      if (dailyAlreadyCompleted) {
        finished = true;
        message = "You've already completed today's challenge!";
      } else {
        finished = false;
        message = '📅 Daily challenge: good luck!';
      }
    });
  }

  void showHint() {
    if (finished || hintUsed) {
      setState(() {
        message = finished
            ? 'Start a new game to play again.'
            : 'You have already used your hint!';
      });
      return;
    }

    setState(() {
      hintUsed = true;
      message = '💡 Hint: starts with ${answer[0]}';
    });
  }

  KeyEventResult _handlePhysicalKey(FocusNode node, KeyEvent event) {
    // Avoid processing the same action on both key-down and key-up.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      submitGuess();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      deleteLetter();
      return KeyEventResult.handled;
    }

    final letter = key.keyLabel.toUpperCase();
    if (RegExp(r'^[A-Z]$').hasMatch(letter)) {
      typeLetter(letter);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _gameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = darkMode ? Colors.white : const Color(0xFF292344);
    final background = darkMode ? const Color(0xFF17152B) : const Color(0xFFFFF9FF);

    return Scaffold(
      backgroundColor: background,
      body: AnimatedSpaceBackground(
        isDayMode: !darkMode,
        gradientColors: darkMode
            ? const [Color(0xFF050817), Color(0xFF171238), Color(0xFF0B2945)]
            : const [Color(0xFFEAF5FF), Color(0xFFE6E2FF), Color(0xFFFFE7F0)],
        child: SafeArea(
          child: selectedTab == 0
              ? _buildDashboardPage(foreground)
              : selectedTab == 1
                  ? _buildPlayPage(foreground)
                  : _buildStatsPage(foreground),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: selectedTab,
        onDestinationSelected: _goToTab,
        backgroundColor: darkMode
            ? const Color(0xFF201B37)
            : const Color(0xFFFFF7FD),
        indicatorColor: purple.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_on_rounded),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  void _goToTab(int index) {
    setState(() => selectedTab = index);
    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _gameFocusNode.requestFocus();
      });
    }
  }

  void _openDailyChallenge() {
    startDailyChallenge();
    _goToTab(1);
  }

  void _openPractice() {
    newGame();
    _goToTab(1);
  }

  Widget _buildTopBar(Color foreground) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [pink, Color(0xFFFF985D)]),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'WORDLE PLUS',
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Your progress',
            onPressed: () => _goToTab(2),
            icon: const Icon(Icons.emoji_events_rounded, color: yellow),
          ),
          IconButton(
            tooltip: darkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () => setState(() => darkMode = !darkMode),
            icon: Icon(
              darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: purple,
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: pink),
          ),
        ],
      ),
    );
  }

  String _welcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _prettyToday() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildDashboardPage(Color foreground) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final rawName = email == null ? '' : email.split('@').first;
    final playerName = rawName.isEmpty
        ? 'wordsmith'
        : '${rawName[0].toUpperCase()}${rawName.substring(1)}';

    return Column(
      children: [
        _buildTopBar(foreground),
        Divider(color: purple.withValues(alpha: 0.45), height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_welcomeMessage()}, $playerName 👋',
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'A little word practice goes a long way.',
                                style: TextStyle(
                                  color: foreground.withValues(alpha: 0.68),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: purple.withValues(alpha: 0.28)),
                          ),
                          child: Text(
                            _prettyToday(),
                            style: TextStyle(
                              color: foreground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDashboardHero(foreground),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Your progress',
                      'Small wins add up. Here is your journey so far.',
                      foreground,
                    ),
                    const SizedBox(height: 12),
                    _buildMetricGrid(foreground),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      'Your weekly streak',
                      'Daily activity and streak-freeze days at a glance.',
                      foreground,
                    ),
                    _buildStreakCard(foreground),
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      'Choose your next move',
                      'Play today’s puzzle or practice without pressure.',
                      foreground,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = 14.0;
                        final cardWidth = constraints.maxWidth >= 660
                            ? (constraints.maxWidth - gap) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            _buildQuickActionCard(
                              width: cardWidth,
                              title: 'Daily challenge',
                              description: dailyAlreadyCompleted
                                  ? 'You have finished today’s puzzle. Come back tomorrow for a fresh daily word.'
                                  : 'One shared daily word, six attempts, and progress toward your streak.',
                              buttonLabel: dailyAlreadyCompleted
                                  ? 'Practice instead'
                                  : 'Play today',
                              icon: Icons.calendar_month_rounded,
                              accent: purple,
                              onPressed: dailyAlreadyCompleted
                                  ? _openPractice
                                  : _openDailyChallenge,
                              foreground: foreground,
                            ),
                            _buildQuickActionCard(
                              width: cardWidth,
                              title: 'Random practice',
                              description: 'Keep your vocabulary sharp with another word. Practice does not change your daily streak.',
                              buttonLabel: 'Start practice',
                              icon: Icons.casino_rounded,
                              accent: pink,
                              onPressed: _openPractice,
                              foreground: foreground,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildFreezeInfoCard(foreground),
                    const SizedBox(height: 16),
                    _buildHowToPlayCard(foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardHero(Color foreground) {
    final completed = dailyAlreadyCompleted;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7654E8), Color(0xFFB35AD2), Color(0xFFFF8C91)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '✦  TODAY’S WORD QUEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                completed ? 'You showed up. That counts!' : 'Keep your streak glowing.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                completed
                    ? 'Today’s challenge is complete. Take a practice round or come back for tomorrow’s word.'
                    : 'One five-letter mystery. Six tries. Finish today’s puzzle to record your daily activity.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: completed ? _openPractice : _openDailyChallenge,
                icon: Icon(completed ? Icons.casino_rounded : Icons.play_arrow_rounded),
                label: Text(completed ? 'Practice a new word' : 'Start daily challenge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6A49BE),
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 570) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 20), _buildHeroArtwork()],
            );
          }

          return Row(
            children: [
              Expanded(child: intro),
              const SizedBox(width: 20),
              _buildHeroArtwork(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroArtwork() {
    Widget tile(String letter, Color color, {double size = 42}) {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: color == yellow ? const Color(0xFF292344) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.43,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [tile('W', green), tile('O', yellow), tile('R', purple)]),
          Row(children: [tile('D', pink), tile('L', green), tile('E', const Color(0xFF4A4269))]),
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFD66B), size: 20),
              SizedBox(width: 5),
              Text('ONE WORD A DAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color foreground) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: foreground, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: foreground.withValues(alpha: 0.62), fontSize: 12, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildMetricGrid(Color foreground) {
    final winRate = games == 0 ? 0 : wins * 100 ~/ games;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 4 : constraints.maxWidth >= 340 ? 2 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _buildMetricCard('Puzzles played', '$games', 'Every finished round', Icons.extension_rounded, purple, width, foreground),
            _buildMetricCard('Words solved', '$wins', 'Correct answers', Icons.check_circle_rounded, green, width, foreground),
            _buildMetricCard('Win rate', '$winRate%', 'Across completed rounds', Icons.track_changes_rounded, pink, width, foreground),
            _buildMetricCard('Best streak', '$bestStreak day${bestStreak == 1 ? '' : 's'}', 'Personal record', Icons.local_fire_department_rounded, const Color(0xFFFF9D55), width, foreground),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color accent,
    double width,
    Color foreground,
  ) {
    final base = darkMode ? const Color(0xFF25213C) : Colors.white.withValues(alpha: 0.86);
    return Container(
      width: width,
      height: 125,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: darkMode ? 0.08 : 0.06), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: foreground, fontSize: 27, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground.withValues(alpha: 0.54), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required double width,
    required String title,
    required String description,
    required String buttonLabel,
    required IconData icon,
    required Color accent,
    required VoidCallback onPressed,
    required Color foreground,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF25213C) : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: accent, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text(title, style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(color: foreground.withValues(alpha: 0.66), fontSize: 12, height: 1.45)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: Text(buttonLabel),
              style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreezeInfoCard(Color foreground) {
    final daysToReward = 7 - (streak % 7);
    final progress = (streak % 7) / 7;
    final full = streakFreezes >= 2;
    const ice = Color(0xFF8CDDF5);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF202C45) : const Color(0xFFEFFAFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ice.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: ice.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.ac_unit_rounded, color: ice, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Streak freeze', style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  full
                      ? 'Your freeze stash is full. You can hold up to 2 freezes; a freeze automatically protects one missed day.'
                      : 'You have $streakFreezes freeze${streakFreezes == 1 ? '' : 's'}. Complete daily challenges to build a streak; reach a 7-day milestone to earn a freeze when there is room.',
                  style: TextStyle(color: foreground.withValues(alpha: 0.7), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: full ? 1 : progress,
                    minHeight: 7,
                    backgroundColor: foreground.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(ice),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  full ? 'Freeze inventory: 2 / 2' : '$daysToReward day${daysToReward == 1 ? '' : 's'} to your next 7-day milestone',
                  style: const TextStyle(color: ice, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPlayCard(Color foreground) {
    final base = darkMode ? const Color(0xFF25213C) : Colors.white.withValues(alpha: 0.86);
    Widget legend(Color color, String title, String detail) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 17, height: 17, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w900)),
                Text(detail, style: TextStyle(color: foreground.withValues(alpha: 0.62), fontSize: 10)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: purple.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to read the tiles', style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Every guess gives clues about the hidden word.', style: TextStyle(color: foreground.withValues(alpha: 0.62), fontSize: 12)),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              legend(green, 'Green', 'Right letter, right place'),
              legend(yellow, 'Yellow', 'Letter is somewhere else'),
              legend(gray, 'Gray', 'Not available in the answer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPage(Color foreground) {
    return Focus(
      focusNode: _gameFocusNode,
      autofocus: true,
      descendantsAreFocusable: false,
      onKeyEvent: _handlePhysicalKey,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_gameFocusNode.hasFocus) _gameFocusNode.requestFocus();
        },
        child: Column(
          children: [
            _buildTopBar(foreground),
            Divider(color: purple.withValues(alpha: 0.45), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 5),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9656), size: 18),
                  const SizedBox(width: 4),
                  Text('$streak day streak', style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  const Icon(Icons.ac_unit_rounded, color: Color(0xFF8CDDF5), size: 17),
                  const SizedBox(width: 3),
                  Text('$streakFreezes freeze${streakFreezes == 1 ? '' : 's'}', style: TextStyle(color: foreground.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (dailyAlreadyCompleted)
                    const Text('DAILY COMPLETE', style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [purple, pink]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                dailyMode ? '📅 DAILY CHALLENGE' : '🎲 RANDOM PRACTICE',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                dictionaryLoading ? 'Loading dictionary…' : message,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(6, (row) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (col) {
                        final color = tileColor(row, col);
                        final guessed = row < guesses.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 49,
                          height: 49,
                          margin: const EdgeInsets.all(3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: guessed ? color : purple.withValues(alpha: 0.65), width: 1.5),
                          ),
                          child: Text(
                            letterAt(row, col),
                            style: TextStyle(
                              color: guessed
                                  ? (color == yellow ? const Color(0xFF292344) : Colors.white)
                                  : foreground,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  for (final row in ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'])
                    Row(
                      children: [
                        if (row.startsWith('ZX')) _key('ENTER', green, submitGuess, wide: true),
                        ...row.split('').map((letter) => _key(letter, keyColor(letter), () => typeLetter(letter))),
                        if (row.startsWith('ZX')) _key('⌫', pink, deleteLetter, wide: true),
                      ],
                    ),
                  const SizedBox(height: 7),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _actionButton('Hint', Icons.lightbulb_rounded, yellow, showHint),
                      _actionButton('Daily', Icons.calendar_month_rounded, purple, startDailyChallenge),
                      _actionButton('New game', Icons.casino_rounded, pink, newGame),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPage(Color foreground) {
    final winRate = games == 0 ? 0 : wins * 100 ~/ games;
    return Column(
      children: [
        _buildTopBar(foreground),
        Divider(color: purple.withValues(alpha: 0.45), height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your player report', style: TextStyle(color: foreground, fontSize: 25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('A closer look at your Wordle Plus progress.', style: TextStyle(color: foreground.withValues(alpha: 0.65), fontSize: 13)),
                    const SizedBox(height: 20),
                    _buildMetricGrid(foreground),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(19),
                      decoration: BoxDecoration(
                        color: darkMode ? const Color(0xFF25213C) : Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: green.withValues(alpha: 0.28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.track_changes_rounded, color: green),
                              const SizedBox(width: 9),
                              Text('Accuracy overview', style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Win rate', style: TextStyle(color: foreground.withValues(alpha: 0.7), fontSize: 12)),
                              Text('$winRate%', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: winRate / 100,
                              minHeight: 9,
                              backgroundColor: foreground.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(green),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('$wins wins out of $games completed games. Random practice is included in these game totals.', style: TextStyle(color: foreground.withValues(alpha: 0.63), fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Weekly activity', 'Green means you completed a daily challenge; ice means a freeze protected the day.', foreground),
                    _buildStreakCard(foreground),
                    const SizedBox(height: 12),
                    _buildFreezeInfoCard(foreground),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      onPressed: _openPractice,
                      icon: const Icon(Icons.casino_rounded),
                      label: const Text('Play a practice round'),
                      style: OutlinedButton.styleFrom(foregroundColor: purple, side: BorderSide(color: purple.withValues(alpha: 0.6)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(Color foreground) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final cardBase = darkMode
        ? const Color(0xFF29213F)
        : const Color(0xFFFFF6FC);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pink.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: darkMode ? 0.14 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [pink, Color(0xFFFF8B45)]),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak day streak',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Complete the Daily Challenge to keep it alive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.70),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'A freeze protects one missed day automatically. '
                    'Earn another at each 7-day streak milestone, up to 2.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8CDDF5).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8CDDF5).withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ac_unit_rounded, color: Color(0xFF8CDDF5), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$streakFreezes',
                        style: const TextStyle(
                          color: Color(0xFF8CDDF5),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));
              final key = _dateKey(date);
              final isToday = key == todayKey();
              final active = dailyActivityDates.contains(key);
              final frozen = streakFreezeDates.contains(key);

              final Color markerColor = active
                  ? green
                  : frozen
                      ? const Color(0xFF8CDDF5)
                      : isToday
                          ? pink
                          : foreground.withValues(alpha: 0.22);

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? green.withValues(alpha: 0.18)
                            : frozen
                                ? const Color(0xFF8CDDF5).withValues(alpha: 0.15)
                                : Colors.transparent,
                        border: Border.all(
                          color: markerColor,
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        active
                            ? Icons.check_rounded
                            : frozen
                                ? Icons.ac_unit_rounded
                                : isToday
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                        size: active || frozen ? 15 : 10,
                        color: markerColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _key(
    String label,
    Color color,
    VoidCallback onTap, {
    bool wide = false,
  }) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 45,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: color == yellow
                  ? const Color(0xFF292344)
                  : (color == usedKeyDark || color == usedKeyLight)
                      ? (darkMode ? const Color(0xFFBDB9D0) : const Color(0xFF5D566F))
                      : Colors.white,
              padding: EdgeInsets.zero,
              elevation: (color == usedKeyDark || color == usedKeyLight) ? 0 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: darkMode ? Colors.white : color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}
