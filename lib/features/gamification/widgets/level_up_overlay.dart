import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/gamification_models.dart';

/// Full-screen level-up overlay. User must tap to dismiss.
/// Show it with [LevelUpOverlay.show].
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({
    super.key,
    required this.result,
  });

  final GamificationResult result;

  static Future<void> show(
    BuildContext context,
    GamificationResult result,
  ) =>
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        builder: (_) => LevelUpOverlay(result: result),
      );

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  GamificationResult get result => widget.result;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterCtrl.forward().then((_) {
        _pulseCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = result.newTier;
    final gradient = tier.gradient;
    final glow = tier.glowColor;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Background: near-black with radial glow of tier color
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      glow.withOpacity(0.18),
                      tier.backgroundColor,
                      tier.backgroundColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Floating particles
            const Positioned.fill(child: _ParticleLayer()),

            // Content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LEVEL UP text — slides down and fades in
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'LEVEL UP',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(color: Colors.white24, blurRadius: 24),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .slideY(
                        begin: -0.4,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      )
                      .fade(duration: 400.ms),

                  const SizedBox(height: 24),

                  // Level number — bounces in with glow
                  _LevelNumber(
                    level: result.newLevel,
                    gradient: gradient,
                    glow: glow,
                    enterCtrl: _enterCtrl,
                    pulseCtrl: _pulseCtrl,
                  ),

                  const SizedBox(height: 12),

                  // Tier label with subtle border badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: tier.primaryColor.withOpacity(0.5), width: 1),
                      borderRadius: BorderRadius.circular(20),
                      color: tier.primaryColor.withOpacity(0.08),
                    ),
                    child: Text(
                      tier.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 4,
                        color: tier.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                      .animate(delay: 400.ms)
                      .fade(duration: 400.ms)
                      .scale(begin: const Offset(0.85, 0.85), duration: 400.ms),

                  const SizedBox(height: 36),

                  // XP bar
                  _XPBar(gradient: gradient, result: result)
                      .animate(delay: 500.ms)
                      .fade(duration: 400.ms)
                      .slideY(begin: 0.2, duration: 400.ms),

                  const SizedBox(height: 32),

                  // Tier change banner
                  if (result.tierChanged)
                    _TierBanner(tier: result.newTier)
                        .animate(delay: 700.ms)
                        .fade(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),

                  const SizedBox(height: 48),

                  // Dismiss hint
                  Text(
                    'Tippe zum Fortfahren',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.35),
                      letterSpacing: 1,
                    ),
                  ).animate(delay: 1000.ms).fade(duration: 600.ms),
                ],
              ),
            ),

            // Confetti layer
            Positioned.fill(
              child: _ConfettiLayer(colors: tier.confettiColors),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level number with bounce + glow ──────────────────────────────────────────

class _LevelNumber extends StatelessWidget {
  const _LevelNumber({
    required this.level,
    required this.gradient,
    required this.glow,
    required this.enterCtrl,
    required this.pulseCtrl,
  });

  final int level;
  final List<Color> gradient;
  final Color glow;
  final Animation<double> enterCtrl;
  final Animation<double> pulseCtrl;

  @override
  Widget build(BuildContext context) {
    final scaleIn = CurvedAnimation(
      parent: enterCtrl,
      curve: const Interval(0.3, 0.9, curve: Curves.elasticOut),
    );
    final fadeIn = CurvedAnimation(
      parent: enterCtrl,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    final pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([scaleIn, fadeIn, pulse]),
      builder: (_, __) {
        return Opacity(
          opacity: fadeIn.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scaleIn.value * pulse.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow behind number
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glow.withOpacity(0.35 * scaleIn.value),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: gradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── XP bar ────────────────────────────────────────────────────────────────────

class _XPBar extends StatelessWidget {
  const _XPBar({required this.gradient, required this.result});
  final List<Color> gradient;
  final GamificationResult result;

  @override
  Widget build(BuildContext context) {
    final xpInLevel = result.newLevel * LevelSystem.xpPerLevel -
        LevelSystem.xpPerLevel +
        (result.xpGained > 0 ? result.xpGained : 0);
    final progress = LevelSystem.levelProgress(xpInLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(gradient.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * LevelSystem.xpPerLevel).round()} / ${LevelSystem.xpPerLevel} XP',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tier change banner ────────────────────────────────────────────────────────

class _TierBanner extends StatelessWidget {
  const _TierBanner({required this.tier});
  final GamificationTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: tier.primaryColor, width: 1.5),
        borderRadius: BorderRadius.circular(30),
        color: tier.primaryColor.withOpacity(0.12),
      ),
      child: Text(
        '✦  Neue Stufe: ${tier.label}  ✦',
        style: TextStyle(
          fontSize: 14,
          letterSpacing: 2,
          color: tier.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Confetti layer ────────────────────────────────────────────────────────────

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.colors});
  final List<Color> colors;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiPiece> _pieces;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    _pieces = List.generate(
      60,
      (_) => _ConfettiPiece(_rng, widget.colors),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ConfettiPainter(_pieces, _ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece(math.Random rng, List<Color> colors)
      : x = rng.nextDouble(),
        delay = rng.nextDouble() * 0.4,
        speed = 0.3 + rng.nextDouble() * 0.5,
        size = 4.0 + rng.nextDouble() * 6,
        rotation = rng.nextDouble() * math.pi * 2,
        rotationSpeed = (rng.nextDouble() - 0.5) * 6,
        color = colors[rng.nextInt(colors.length)],
        isRect = rng.nextBool();

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final bool isRect;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);
  final List<_ConfettiPiece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final progress = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final y = progress * p.speed * size.height * 1.4;
      final x = p.x * size.width + math.sin(progress * math.pi * 3) * 20;
      final opacity = progress < 0.8 ? 1.0 : (1.0 - progress) / 0.2;
      final rot = p.rotation + p.rotationSpeed * progress;
      final paint = Paint()..color = p.color.withOpacity(opacity.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ── Particle layer ────────────────────────────────────────────────────────────

class _ParticleLayer extends StatefulWidget {
  const _ParticleLayer();

  @override
  State<_ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<_ParticleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _particles = List.generate(30, (_) => _Particle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_particles, _ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Particle {
  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        startY = rng.nextDouble(),
        speed = 0.03 + rng.nextDouble() * 0.06,
        radius = 1.5 + rng.nextDouble() * 3,
        opacity = 0.1 + rng.nextDouble() * 0.3;

  final double x;
  final double startY;
  final double speed;
  final double radius;
  final double opacity;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.startY - t * p.speed) % 1.0) * size.height;
      final x = p.x * size.width;
      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()..color = Colors.white.withOpacity(p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
