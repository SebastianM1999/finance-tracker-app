import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gamification_models.dart';

/// Wraps a child (typically a profile picture) with a tier-colored ring.
/// Gold gets a slow glow pulse; Diamond gets a prismatic color-shift.
class TierRing extends StatefulWidget {
  const TierRing({
    super.key,
    required this.tier,
    required this.level,
    required this.radius,
    this.strokeWidth = 3,
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

class _TierRingState extends State<TierRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  bool get _hasAnim =>
      widget.tier == GamificationTier.gold ||
      widget.tier == GamificationTier.diamond;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.tier == GamificationTier.diamond
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3),
    );
    if (_hasAnim) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(TierRing old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier) {
      _ctrl.stop();
      if (_hasAnim) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAnim) {
      return _RingPainterWidget(
        tier: widget.tier,
        radius: widget.radius,
        strokeWidth: widget.strokeWidth,
        t: 0,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => _RingPainterWidget(
        tier: widget.tier,
        radius: widget.radius,
        strokeWidth: widget.strokeWidth,
        t: _ctrl.value,
        child: widget.child,
      ),
    );
  }
}

class _RingPainterWidget extends StatelessWidget {
  const _RingPainterWidget({
    required this.tier,
    required this.radius,
    required this.strokeWidth,
    required this.t,
    required this.child,
  });

  final GamificationTier tier;
  final double radius;
  final double strokeWidth;
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2 + strokeWidth * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TierRingPainter(tier: tier, t: t, strokeWidth: strokeWidth),
        child: Center(child: child),
      ),
    );
  }
}

class _TierRingPainter extends CustomPainter {
  const _TierRingPainter({
    required this.tier,
    required this.t,
    required this.strokeWidth,
  });

  final GamificationTier tier;
  final double t;
  final double strokeWidth;

  List<Color> _colors() {
    if (tier == GamificationTier.diamond) {
      final hue = (t * 360) % 360;
      return [
        HSVColor.fromAHSV(1, hue, 0.8, 1).toColor(),
        HSVColor.fromAHSV(1, (hue + 120) % 360, 0.8, 1).toColor(),
        HSVColor.fromAHSV(1, (hue + 240) % 360, 0.8, 1).toColor(),
      ];
    }
    return tier.gradient;
  }

  double _opacity() {
    if (tier == GamificationTier.gold) {
      return 0.7 + 0.3 * math.sin(t * 2 * math.pi);
    }
    return 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final colors = _colors();
    final opacity = _opacity();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        startAngle: 0,
        endAngle: 2 * math.pi,
      ).createShader(rect)
      ..color = Colors.white.withOpacity(opacity);

    // Draw ring with opacity
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white.withOpacity(opacity),
    );
    canvas.drawCircle(center, radius, paint);
    canvas.restore();

    // Glow for gold/diamond
    if (tier == GamificationTier.gold || tier == GamificationTier.diamond) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, strokeWidth * opacity);
      glowPaint.shader = SweepGradient(
        colors: [...colors, colors.first],
      ).createShader(rect);
      canvas.drawCircle(center, radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_TierRingPainter old) =>
      old.t != t || old.tier != tier;
}
