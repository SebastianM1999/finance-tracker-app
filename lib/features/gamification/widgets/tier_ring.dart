import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gamification_models.dart';

/// Draws a coded gradient ring around [child].
/// Gold/Diamond: animated glow pulse + sparkle.
/// Bronze/Silver: static with shine.
class TierRing extends StatefulWidget {
  const TierRing({
    super.key,
    required this.tier,
    required this.level,
    required this.radius,
    this.strokeWidth = 4.0,
    required this.child,
  });

  final GamificationTier tier;
  final int level;
  final double radius;
  final double strokeWidth;
  final Widget child;

  @override
  State<TierRing> createState() => _TierRingState();
}

class _TierRingState extends State<TierRing> with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _sparkleCtrl;

  bool get _hasAnim =>
      widget.tier == GamificationTier.gold ||
      widget.tier == GamificationTier.diamond;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: widget.tier == GamificationTier.diamond
          ? const Duration(milliseconds: 1800)
          : const Duration(milliseconds: 2600),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (_hasAnim) {
      _glowCtrl.repeat(reverse: true);
      _sparkleCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TierRing old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier) {
      if (_hasAnim) {
        _glowCtrl.repeat(reverse: true);
        _sparkleCtrl.repeat(reverse: true);
      } else {
        _glowCtrl.stop();
        _sparkleCtrl.stop();
        _glowCtrl.reset();
        _sparkleCtrl.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Outer SizedBox includes room for the glow halo beyond the stroke
    final size = widget.radius * 2 + 20;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Ring + sparkle (behind avatar)
          Positioned.fill(
            child: IgnorePointer(
              child: _hasAnim
                  ? AnimatedBuilder(
                      animation:
                          Listenable.merge([_glowCtrl, _sparkleCtrl]),
                      builder: (_, __) => CustomPaint(
                        painter: _TierRingPainter(
                          tier: widget.tier,
                          radius: widget.radius,
                          strokeWidth: widget.strokeWidth,
                          glowPulse: _glowCtrl.value,
                          sparklePulse: _sparkleCtrl.value,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _TierRingPainter(
                        tier: widget.tier,
                        radius: widget.radius,
                        strokeWidth: widget.strokeWidth,
                        glowPulse: 0.6,
                        sparklePulse: 0.85,
                      ),
                    ),
            ),
          ),
          // Avatar centered on top of ring
          Center(child: widget.child),
        ],
      ),
    );
  }
}

// ── Ring painter ───────────────────────────────────────────────────────────────

class _TierRingPainter extends CustomPainter {
  const _TierRingPainter({
    required this.tier,
    required this.radius,
    required this.strokeWidth,
    required this.glowPulse,
    required this.sparklePulse,
  });

  final GamificationTier tier;
  final double radius;
  final double strokeWidth;
  final double glowPulse; // 0.0–1.0
  final double sparklePulse; // 0.0–1.0

  // ── Tier colour palettes ────────────────────────────────────────────────────

  List<Color> get _sweepColors {
    switch (tier) {
      case GamificationTier.bronze:
        return const [
          Color(0xFF5C2700),
          Color(0xFFCD7F32),
          Color(0xFFFF9B3C),
          Color(0xFFFFD090),
          Color(0xFFFF9B3C),
          Color(0xFFCD7F32),
          Color(0xFF5C2700),
        ];
      case GamificationTier.silver:
        return const [
          Color(0xFF4A5A6A),
          Color(0xFF9AAABB),
          Color(0xFFD8E8F0),
          Color(0xFFFFFFFF),
          Color(0xFFD8E8F0),
          Color(0xFF9AAABB),
          Color(0xFF4A5A6A),
        ];
      case GamificationTier.gold:
        return const [
          Color(0xFF4A2800),
          Color(0xFFB8860B),
          Color(0xFFD4A017),
          Color(0xFFFFF0A0),
          Color(0xFFD4A017),
          Color(0xFFB8860B),
          Color(0xFF4A2800),
        ];
      case GamificationTier.diamond:
        return const [
          Color(0xFF001A3A),
          Color(0xFF0077BB),
          Color(0xFF00CFFF),
          Color(0xFFAAEEFF),
          Color(0xFF00CFFF),
          Color(0xFF0077BB),
          Color(0xFF001A3A),
        ];
    }
  }

  Color get _glowColor {
    switch (tier) {
      case GamificationTier.bronze:
        return const Color(0xFFFF9B3C);
      case GamificationTier.silver:
        return const Color(0xFFB8C8D8);
      case GamificationTier.gold:
        return const Color(0xFFD4A017);
      case GamificationTier.diamond:
        return const Color(0xFF00CFFF);
    }
  }

  Color get _shineColor {
    switch (tier) {
      case GamificationTier.bronze:
        return const Color(0xFFFFD090);
      case GamificationTier.silver:
        return Colors.white;
      case GamificationTier.gold:
        return const Color(0xFFFFF0A0);
      case GamificationTier.diamond:
        return const Color(0xFFCCF5FF);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = radius; // ring centered at avatar edge

    _drawOuterGlow(canvas, cx, cy, r);
    _drawRing(canvas, cx, cy, r);
    _drawShineArc(canvas, cx, cy, r);
    _drawCornerSparkle(canvas, cx, cy, r);
  }

  void _drawOuterGlow(Canvas canvas, double cx, double cy, double r) {
    final isAnimated = tier == GamificationTier.gold ||
        tier == GamificationTier.diamond;
    final opacity =
        isAnimated ? (0.30 + 0.28 * glowPulse) : 0.28;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = _glowColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawRing(Canvas canvas, double cx, double cy, double r) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Main gradient ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = SweepGradient(
          colors: _sweepColors,
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Subtle inner edge highlight
    canvas.drawCircle(
      Offset(cx, cy),
      r - strokeWidth / 2,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawShineArc(Canvas canvas, double cx, double cy, double r) {
    // Bright arc from roughly 10 o'clock to 1 o'clock
    final isAnimated = tier == GamificationTier.gold ||
        tier == GamificationTier.diamond;
    final opacity =
        isAnimated ? (0.45 + 0.35 * glowPulse) : 0.55;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.78, // ~-140° = ~10 o'clock
      math.pi * 0.56,  // sweep ~100° to ~1 o'clock
      false,
      Paint()
        ..color = _shineColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCornerSparkle(Canvas canvas, double cx, double cy, double r) {
    // Position: top-right of ring (~-45° from top = 1:30 o'clock)
    const angle = -math.pi / 4;
    final sx = cx + r * math.cos(angle);
    final sy = cy + r * math.sin(angle);

    final isAnimated = tier == GamificationTier.gold ||
        tier == GamificationTier.diamond;
    final pulse = isAnimated ? (0.65 + 0.35 * sparklePulse) : 1.0;
    final starR = strokeWidth * 2.0 * pulse;

    // Glow halo
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 2.2,
      Paint()
        ..color = _shineColor.withOpacity(0.30 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Cross-style 4-point star (long horizontal/vertical, short diagonals)
    _drawCrossSparkle(canvas, sx, sy, starR, _shineColor.withOpacity(0.92 * pulse));

    // Bright white centre dot
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 0.25,
      Paint()..color = Colors.white.withOpacity(0.95 * pulse),
    );
  }

  /// 4-point lens-flare cross: long on 0°/90° axes, short on diagonals.
  void _drawCrossSparkle(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

    final path = Path();
    for (int i = 0; i < 8; i++) {
      // Even indices = cardinal directions (long), odd = diagonals (short)
      final a = (i * math.pi / 4) - math.pi / 2;
      final len = i.isEven ? r : r * 0.22;
      final x = cx + len * math.cos(a);
      final y = cy + len * math.sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TierRingPainter old) =>
      old.tier != tier ||
      old.glowPulse != glowPulse ||
      old.sparklePulse != sparklePulse;
}
