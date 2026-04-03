import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gamification_tier.dart';

/// Draws a gradient ring around [child] with a metallic look and a corner sparkle.
/// No animation — all tiers render at fixed pulse values.
class TierRing extends StatelessWidget {
  const TierRing({
    super.key,
    required this.tier,
    required this.radius,
    required this.child,
    this.strokeWidth = 4.0,
  });

  final GamificationTier tier;
  final double radius;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2 + 20;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TierRingPainter(
                  tier: tier,
                  radius: radius,
                  strokeWidth: strokeWidth,
                  glowPulse: 0.6,
                  sparklePulse: 0.85,
                ),
              ),
            ),
          ),
          Center(child: child),
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
  final double glowPulse;
  final double sparklePulse;

  List<Color> get _sweepColors {
    switch (tier) {
      case GamificationTier.bronze:
        return const [
          Color(0xFF5C2700), Color(0xFFCD7F32), Color(0xFFFF9B3C),
          Color(0xFFFFD090), Color(0xFFFF9B3C), Color(0xFFCD7F32), Color(0xFF5C2700),
        ];
      case GamificationTier.silver:
        return const [
          Color(0xFF4A5A6A), Color(0xFF9AAABB), Color(0xFFD8E8F0),
          Color(0xFFFFFFFF), Color(0xFFD8E8F0), Color(0xFF9AAABB), Color(0xFF4A5A6A),
        ];
      case GamificationTier.gold:
        return const [
          Color(0xFF4A2800), Color(0xFFB8860B), Color(0xFFD4A017),
          Color(0xFFFFF0A0), Color(0xFFD4A017), Color(0xFFB8860B), Color(0xFF4A2800),
        ];
      case GamificationTier.diamond:
        return const [
          Color(0xFF001A3A), Color(0xFF0077BB), Color(0xFF00CFFF),
          Color(0xFFAAEEFF), Color(0xFF00CFFF), Color(0xFF0077BB), Color(0xFF001A3A),
        ];
    }
  }

  Color get _glowColor {
    switch (tier) {
      case GamificationTier.bronze: return const Color(0xFFFF9B3C);
      case GamificationTier.silver: return const Color(0xFFB8C8D8);
      case GamificationTier.gold:   return const Color(0xFFD4A017);
      case GamificationTier.diamond: return const Color(0xFF00CFFF);
    }
  }

  Color get _shineColor {
    switch (tier) {
      case GamificationTier.bronze: return const Color(0xFFFFD090);
      case GamificationTier.silver: return Colors.white;
      case GamificationTier.gold:   return const Color(0xFFFFF0A0);
      case GamificationTier.diamond: return const Color(0xFFCCF5FF);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawOuterGlow(canvas, cx, cy);
    _drawRing(canvas, cx, cy);
    _drawShineArc(canvas, cx, cy);
    _drawCornerSparkle(canvas, cx, cy);
  }

  void _drawOuterGlow(Canvas canvas, double cx, double cy) {
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = _glowColor.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawRing(Canvas canvas, double cx, double cy) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Main gradient ring
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
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
      radius - strokeWidth / 2,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawShineArc(Canvas canvas, double cx, double cy) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi * 0.78,
      math.pi * 0.56,
      false,
      Paint()
        ..color = _shineColor.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCornerSparkle(Canvas canvas, double cx, double cy) {
    const angle = -math.pi / 4; // top-right ~1:30
    final sx = cx + radius * math.cos(angle);
    final sy = cy + radius * math.sin(angle);
    final starR = strokeWidth * 2.0 * sparklePulse;

    // Glow halo
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 2.2,
      Paint()
        ..color = _shineColor.withOpacity(0.30 * sparklePulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 4-point cross sparkle
    _drawCrossSparkle(canvas, sx, sy, starR, _shineColor.withOpacity(0.92 * sparklePulse));

    // Bright white centre dot
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 0.25,
      Paint()..color = Colors.white.withOpacity(0.95 * sparklePulse),
    );
  }

  void _drawCrossSparkle(Canvas canvas, double cx, double cy, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

    final path = Path();
    for (int i = 0; i < 8; i++) {
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
  bool shouldRepaint(_TierRingPainter old) => old.tier != tier;
}
