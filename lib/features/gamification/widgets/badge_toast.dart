import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gamification_models.dart';
import 'badge_card.dart';

/// App-level badge unlock toast with a queue — badges show one after another.
/// Use [GamificationOverlay.enqueue] to add one or more badges.
class GamificationOverlay {
  GamificationOverlay._();

  static final Queue<BadgeDefinition> _queue = Queue();
  static OverlayEntry? _current;
  static OverlayState? _overlay;

  static void registerOverlay(BuildContext context) {
    _overlay ??= Overlay.of(context, rootOverlay: true);
  }

  static void enqueue(BuildContext context, List<BadgeDefinition> badges) {
    if (badges.isEmpty) return;
    _overlay ??= Overlay.of(context, rootOverlay: true);
    _queue.addAll(badges);
    if (_current == null) _showNext();
  }

  static void enqueueFromOverlay(List<BadgeDefinition> badges) {
    if (badges.isEmpty || _overlay == null) return;
    _queue.addAll(badges);
    if (_current == null) _showNext();
  }

  static void _showNext() {
    if (_queue.isEmpty || _overlay == null) return;
    final badge = _queue.removeFirst();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _BadgeToastWidget(
        badge: badge,
        onDismiss: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            entry.remove();
            _current = null;
            Future.delayed(const Duration(milliseconds: 180), _showNext);
          });
        },
      ),
    );

    _current = entry;
    _overlay!.insert(entry);
  }

  static void dismissCurrent() {
    _current?.remove();
    _current = null;
    _queue.clear();
  }
}

// ── Toast widget ───────────────────────────────────────────────────────────────

class _BadgeToastWidget extends StatefulWidget {
  const _BadgeToastWidget({
    required this.badge,
    required this.onDismiss,
    this.onTap,
  });

  final BadgeDefinition badge;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  @override
  State<_BadgeToastWidget> createState() => _BadgeToastWidgetState();
}

class _BadgeToastWidgetState extends State<_BadgeToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _sparkleCtrl;

  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    // One-shot shimmer sweep on entry
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shimmerAnim = Tween<double>(begin: -0.4, end: 1.4).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // Continuous border sparkle pulse
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _slideCtrl.forward();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _shimmerCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _slideCtrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _shimmerCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.badge.tier;
    final color = tier.primaryColor;
    final bgColor = Color.alphaBlend(
      color.withOpacity(0.13),
      const Color(0xFF12141A),
    );
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, topPadding + 10, 10, 0),
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _dismiss();
                  widget.onTap?.call();
                },
                // Stack with Clip.none so border glow can bleed outside card bounds
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Card content (clipped to rounded rect) ─────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Base card
                          Container(
                            color: bgColor,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(width: 14),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: BadgeImage(
                                      missionId: widget.badge.missionId,
                                      tier: tier,
                                      fallbackEmoji:
                                          widget.badge.category.emoji,
                                      size: 56,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Badge freigeschaltet!',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: color.withOpacity(0.85),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.badge.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '+${widget.badge.xpReward} XP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withOpacity(0.4),
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                              ),
                            ),
                          ),

                          // Static gloss (top-left corner)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.09),
                                      Colors.white.withOpacity(0.02),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.3, 0.7],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // One-shot shimmer sweep on entry
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _shimmerAnim,
                                builder: (_, __) => CustomPaint(
                                  painter: _ShimmerPainter(
                                    progress: _shimmerAnim.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Tier border (outside clip, can glow beyond card edge) ──
                    Positioned(
                      left: -8,
                      right: -8,
                      top: -8,
                      bottom: -8,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _sparkleCtrl,
                          builder: (_, __) => CustomPaint(
                            painter: _BadgeBorderPainter(
                              tier: tier,
                              sparklePulse: _sparkleCtrl.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Border painter ─────────────────────────────────────────────────────────────

class _BadgeBorderPainter extends CustomPainter {
  const _BadgeBorderPainter({
    required this.tier,
    required this.sparklePulse,
  });

  final GamificationTier tier;
  final double sparklePulse; // 0.0–1.0

  // 8 px inset = the Positioned(-8,-8,-8,-8) offset, so border aligns to card edge
  static const _inset = 8.0;
  static const _cornerRadius = Radius.circular(16);

  List<Color> get _gradientColors {
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

  bool get _isAnimated =>
      tier == GamificationTier.gold || tier == GamificationTier.diamond;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromLTRBR(
      _inset,
      _inset,
      size.width - _inset,
      size.height - _inset,
      _cornerRadius,
    );
    final innerRect = Offset(_inset, _inset) &
        Size(size.width - _inset * 2, size.height - _inset * 2);

    _drawGlow(canvas, rect);
    _drawBorder(canvas, rect, innerRect);
    _drawShineSegment(canvas, rect);
    _drawCornerSparkle(canvas, rect);
  }

  void _drawGlow(Canvas canvas, RRect rect) {
    final opacity = _isAnimated ? 0.28 + 0.26 * sparklePulse : 0.28;
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _glowColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawBorder(Canvas canvas, RRect rect, Rect innerRect) {
    // Diagonal gradient: bright top-left → dark bottom-right (metallic look)
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ).createShader(innerRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Subtle inner edge highlight line
    canvas.drawRRect(
      RRect.fromLTRBR(
        _inset + 1,
        _inset + 1,
        rect.right - 1,
        rect.bottom - 1,
        const Radius.circular(15),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawShineSegment(Canvas canvas, RRect rect) {
    // Bright segment along the top edge (10 o'clock → 2 o'clock feel)
    final opacity = _isAnimated ? 0.50 + 0.28 * sparklePulse : 0.60;
    final left = rect.left + (rect.width * 0.12);
    final right = rect.left + (rect.width * 0.60);
    final top = rect.top;

    canvas.drawLine(
      Offset(left, top),
      Offset(right, top),
      Paint()
        ..color = _shineColor.withOpacity(opacity)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  void _drawCornerSparkle(Canvas canvas, RRect rect) {
    // Top-right corner of the card border
    final sx = rect.right - 6;
    final sy = rect.top + 6;

    final pulse = _isAnimated ? 0.60 + 0.40 * sparklePulse : 1.0;
    final starR = 4.8 * pulse;

    // Glow halo
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 2.2,
      Paint()
        ..color = _shineColor.withOpacity(0.28 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 4-point cross sparkle
    _drawCross(canvas, sx, sy, starR, _shineColor.withOpacity(0.92 * pulse));

    // White centre dot
    canvas.drawCircle(
      Offset(sx, sy),
      starR * 0.24,
      Paint()..color = Colors.white.withOpacity(0.95 * pulse),
    );
  }

  void _drawCross(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = (i * math.pi / 4) - math.pi / 2;
      final len = i.isEven ? r : r * 0.22;
      final x = cx + len * math.cos(a);
      final y = cy + len * math.sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
  }

  @override
  bool shouldRepaint(_BadgeBorderPainter old) =>
      old.tier != tier || old.sparklePulse != sparklePulse;
}

// ── Entry shimmer sweep ────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.progress});
  final double progress; // -0.4 → 1.4

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < -0.35 || progress > 1.35) return;

    final cx = progress * size.width;
    const hw = 36.0;

    canvas.drawPath(
      Path()
        ..moveTo(cx - hw - 10, 0)
        ..lineTo(cx + hw - 10, 0)
        ..lineTo(cx + hw + 10, size.height)
        ..lineTo(cx - hw + 10, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(cx - hw, 0, hw * 2, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}
