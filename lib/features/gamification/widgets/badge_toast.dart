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
  // Store OverlayState (not BuildContext) — never goes stale while app is alive.
  static OverlayState? _overlay;

  /// Adds [badges] to the queue and starts showing if not already running.
  static void enqueue(BuildContext context, List<BadgeDefinition> badges) {
    if (badges.isEmpty) return;
    _overlay ??= Overlay.of(context, rootOverlay: true);
    _queue.addAll(badges);
    if (_current == null) _showNext();
  }

  static void _showNext() {
    if (_queue.isEmpty || _overlay == null) return;
    final badge = _queue.removeFirst();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: _BadgeToastWidget(
          badge: badge,
          onDismiss: () {
            // Post-frame removal avoids removing the entry mid-build/navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              entry.remove();
              _current = null;
              Future.delayed(
                const Duration(milliseconds: 180), _showNext);
            });
          },
        ),
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

// ── Toast widget ──────────────────────────────────────────────────────────────

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

    // Slide-in / slide-out
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    // One-shot shimmer sweep across the card
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shimmerAnim = Tween<double>(begin: -0.4, end: 1.4).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // Continuous sparkle pulse
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _slideCtrl.forward();

    // Shimmer fires once after slide-in settles
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _shimmerCtrl.forward();
    });

    // Auto-dismiss after 2.5 seconds
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

    // View.of(context) reads the raw platform padding — not affected by
    // Navigator consuming safe-area insets in the MediaQuery tree.
    final view = View.of(context);
    final statusBarHeight = view.padding.top / view.devicePixelRatio;

    return Positioned(
      top: statusBarHeight + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: () {
              _dismiss();
              widget.onTap?.call();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // ── Base card ──────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),

                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.32),
                          blurRadius: 22,
                          spreadRadius: 0,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tier color left bar
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  color,
                                  color.withOpacity(0.5),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Badge image
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: BadgeImage(
                              missionId: widget.badge.missionId,
                              tier: tier,
                              fallbackEmoji: widget.badge.category.emoji,
                              size: 56,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Text
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tier.label.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: color,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Badge freigeschaltet!',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: color.withOpacity(0.85),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                                      color: Colors.white.withOpacity(0.4),
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

                  // ── Static gloss highlight (top-left corner) ───────────────
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.03),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Animated shimmer sweep ─────────────────────────────────
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (_, __) {
                          return CustomPaint(
                            painter: _ShimmerPainter(
                              progress: _shimmerAnim.value,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Sparkles across the full card ──────────────────────────
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _sparkleCtrl,
                        builder: (_, __) => CustomPaint(
                          painter: _CardSparklePainter(
                            progress: _sparkleCtrl.value,
                            color: color,
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
    );
  }
}

// ── Full-card sparkle painter ─────────────────────────────────────────────────

/// Draws multiple 4-point stars scattered across the card, each with its own
/// phase offset so they twinkle independently.
class _CardSparklePainter extends CustomPainter {
  const _CardSparklePainter({required this.progress, required this.color});
  final double progress; // 0.0–1.0 from the repeating sparkle controller
  final Color color;

  // (relX, relY, phase, size) — relative to card dimensions
  static const _points = [
    (0.08, 0.18, 0.0,  8.0),
    (0.92, 0.22, 0.3,  7.0),
    (0.5,  0.12, 0.55, 6.0),
    (0.78, 0.80, 0.15, 9.0),
    (0.18, 0.75, 0.45, 7.0),
    (0.62, 0.55, 0.7,  5.0),
    (0.35, 0.35, 0.85, 6.0),
    (0.88, 0.50, 0.25, 5.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (rx, ry, phase, r) in _points) {
      final t = ((progress + phase) % 1.0);
      final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      if (opacity < 0.02) continue;

      final cx = rx * size.width;
      final cy = ry * size.height;
      _drawStar(canvas, cx, cy, r * opacity, color.withOpacity(opacity * 0.9));
    }
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, Color c) {
    final paint = Paint()
      ..color = c
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final radius = i.isEven ? r : r * 0.35;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.22,
      Paint()..color = Colors.white.withOpacity(0.9 * (c.opacity)),
    );
  }

  @override
  bool shouldRepaint(_CardSparklePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Shimmer sweep painter ─────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.progress, required this.color});
  final double progress; // -0.4 → 1.4 (normalized to card width)
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // progress is outside [0,1] → nothing to draw
    if (progress < -0.35 || progress > 1.35) return;

    final w = size.width;
    final h = size.height;

    // Diagonal sweep: a narrow band tilted ~30°
    final cx = progress * w;
    const halfWidth = 36.0;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.13),
          color.withOpacity(0.20),
          color.withOpacity(0.13),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(cx - halfWidth, 0, halfWidth * 2, h));

    // Slight diagonal: top edge is cx-10, bottom edge is cx+10
    final path = Path()
      ..moveTo(cx - halfWidth - 10, 0)
      ..lineTo(cx + halfWidth - 10, 0)
      ..lineTo(cx + halfWidth + 10, h)
      ..lineTo(cx - halfWidth + 10, h)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}
