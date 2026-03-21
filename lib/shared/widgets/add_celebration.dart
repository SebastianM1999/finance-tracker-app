import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum AddCelebrationType { crypto, etf, stock, giro, festgeld, schulden }

/// Shows a brief celebration overlay after a successful add or edit.
/// Callers should `await` this before calling `Navigator.pop`.
Future<void> showAddCelebration(
  BuildContext context,
  AddCelebrationType type, {
  bool isEdit = false,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => _AddCelebDialog(type: type, isEdit: isEdit),
    );

// ─────────────────────────────────────────────────────────────────────────────

class _AddCelebDialog extends StatefulWidget {
  const _AddCelebDialog({required this.type, required this.isEdit});
  final AddCelebrationType type;
  final bool isEdit;

  @override
  State<_AddCelebDialog> createState() => _AddCelebDialogState();
}

class _AddCelebDialogState extends State<_AddCelebDialog> {
  static const _autoDismiss = {
    AddCelebrationType.crypto   : 1900,
    AddCelebrationType.etf      : 2100,
    AddCelebrationType.stock    : 2100,
    AddCelebrationType.giro     : 2000,
    AddCelebrationType.festgeld : 2200,
    AddCelebrationType.schulden : 2000,
  };

  static const _addLabels = {
    AddCelebrationType.crypto   : 'Coin hinzugefügt!',
    AddCelebrationType.etf      : 'ETF hinzugefügt!',
    AddCelebrationType.stock    : 'Aktie hinzugefügt!',
    AddCelebrationType.giro     : 'Konto hinzugefügt!',
    AddCelebrationType.festgeld : 'Festgeld angelegt!',
    AddCelebrationType.schulden : 'Schuld erfasst!',
  };

  static const _editLabels = {
    AddCelebrationType.crypto   : 'Coin aktualisiert!',
    AddCelebrationType.etf      : 'ETF aktualisiert!',
    AddCelebrationType.stock    : 'Aktie aktualisiert!',
    AddCelebrationType.giro     : 'Konto aktualisiert!',
    AddCelebrationType.festgeld : 'Festgeld aktualisiert!',
    AddCelebrationType.schulden : 'Schulden aktualisiert!',
  };

  static const _labelColors = {
    AddCelebrationType.crypto   : Color(0xFFFFD700),
    AddCelebrationType.etf      : Color(0xFF4FC3F7),
    AddCelebrationType.stock    : Color(0xFF66BB6A),
    AddCelebrationType.giro     : Color(0xFF64B5F6),
    AddCelebrationType.festgeld : Color(0xFFCE93D8),
    AddCelebrationType.schulden : Color(0xFFEF9A9A),
  };

  @override
  void initState() {
    super.initState();
    final ms = _autoDismiss[widget.type] ?? 1800;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.isEdit ? _editLabels : _addLabels;
    final label  = labels[widget.type]!;
    final color  = _labelColors[widget.type]!;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnim(widget.type),
          const SizedBox(height: 18),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
            ),
          )
              .animate()
              .fadeIn(delay: 420.ms, duration: 300.ms)
              .slideY(begin: 0.3, end: 0, delay: 420.ms, duration: 300.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAnim(AddCelebrationType t) => switch (t) {
        AddCelebrationType.crypto   => const _CryptoCoin(),
        AddCelebrationType.etf      => const _BarChart(color: Color(0xFF29B6F6), ticker: 'ETF'),
        AddCelebrationType.stock    => const _BarChart(color: Color(0xFF66BB6A), ticker: 'BUY'),
        AddCelebrationType.giro     => const _BankBuildingWidget(),
        AddCelebrationType.festgeld => const _PiggyBankWidget(),
        AddCelebrationType.schulden => const _DebtCardWidget(),
      };
}

// ── Crypto Coin ───────────────────────────────────────────────────────────────

class _CryptoCoin extends StatelessWidget {
  const _CryptoCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
          center: Alignment(-0.3, -0.3),
          radius: 0.88,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.70),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '₿',
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))],
          ),
        ),
      ),
    )
        .animate()
        .rotate(begin: -1.5, end: 0, duration: 700.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.1, 0.1), duration: 650.ms, curve: Curves.elasticOut)
        .shimmer(delay: 600.ms, duration: 900.ms, color: Colors.white60);
  }
}

// ── Bar Chart (ETF / Stock) ───────────────────────────────────────────────────

class _BarChart extends StatefulWidget {
  const _BarChart({required this.color, required this.ticker});
  final Color color;
  final String ticker;

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 900.ms);
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _progress,
          builder: (_, __) => CustomPaint(
            painter: _BarChartPainter(progress: _progress.value, color: widget.color),
            size: const Size(140, 110),
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 350.ms, curve: Curves.easeOut),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, color: widget.color, size: 20)
                .animate()
                .fadeIn(delay: 750.ms)
                .slideX(begin: -0.3, end: 0, delay: 750.ms),
            const SizedBox(width: 6),
            Text(
              widget.ticker,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 850.ms),
          ],
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  static const _heights = [0.38, 0.54, 0.72, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 9.0;
    final barW = (size.width - spacing * (_heights.length - 1)) / _heights.length;
    for (int i = 0; i < _heights.length; i++) {
      final maxH = size.height * _heights[i];
      final h    = maxH * progress;
      final x    = i * (barW + spacing);
      final y    = size.height - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, h), const Radius.circular(4)),
        Paint()
          ..shader = LinearGradient(
            colors: [color, color.withValues(alpha: 0.45)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(x, y, barW, h)),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.progress != progress;
}

// ── Bank Building (Giro) — falls from above, bounces to a stop ───────────────

class _BankBuildingWidget extends StatelessWidget {
  const _BankBuildingWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 140,
      child: CustomPaint(painter: _BankPainter(), size: const Size(120, 140)),
    )
        .animate()
        .fadeIn(duration: 180.ms)
        .slideY(begin: -6.0, end: 0, duration: 900.ms, curve: Curves.bounceOut)
        .then(delay: 80.ms)
        .shimmer(duration: 700.ms, color: const Color(0xFF64B5F6).withValues(alpha: 0.5));
  }
}

class _BankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ── Building body ───────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(15, 50, 90, 78),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFCFD8DC), Color(0xFFB0BEC5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(15, 50, 90, 78)),
    );

    // ── Pediment ────────────────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(8, 50)
        ..lineTo(112, 50)
        ..lineTo(60, 12)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF90A4AE), Color(0xFF78909C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(8, 12, 104, 38)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(22, 48)
        ..lineTo(98, 48)
        ..lineTo(60, 18)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    // ── Cornice ─────────────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(8, 46, 104, 7), Paint()..color = const Color(0xFF607D8B));
    canvas.drawRect(
      Rect.fromLTWH(8, 52, 104, 1.5),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // ── Columns (3) ─────────────────────────────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final cx = 22.0 + i * 34.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx + 10, 53, 4, 74), const Radius.circular(2)),
        Paint()..color = Colors.black.withValues(alpha: 0.10),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx, 53, 14, 74), const Radius.circular(3)),
        Paint()
          ..shader = LinearGradient(
            colors: const [Color(0xFFECEFF1), Color(0xFFB0BEC5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Rect.fromLTWH(cx, 53, 14, 74)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx + 2, 53, 3, 74), const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.50),
      );
    }

    // ── Door ────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(51, 98, 18, 29),
        topLeft: const Radius.circular(9),
        topRight: const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFF37474F),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(53, 100, 14, 25),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(55, 103, 10, 9), const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFF4E342E).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(const Offset(63, 114), 2.5, Paint()..color = const Color(0xFFFFD700));

    // ── Steps ───────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(12, 128, 96, 6), const Radius.circular(1)),
      Paint()..color = const Color(0xFF78909C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(5, 134, 110, 6), const Radius.circular(1)),
      Paint()..color = const Color(0xFF607D8B),
    );

    // Top body highlight
    canvas.drawRect(
      Rect.fromLTWH(15, 50, 90, 4),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_BankPainter old) => false;
}

// ── Piggy Bank (Festgeld) ─────────────────────────────────────────────────────

class _PiggyBankWidget extends StatefulWidget {
  const _PiggyBankWidget();

  @override
  State<_PiggyBankWidget> createState() => _PiggyBankWidgetState();
}

class _PiggyBankWidgetState extends State<_PiggyBankWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coinCtrl;
  late final Animation<double> _coinAnim;

  @override
  void initState() {
    super.initState();
    _coinCtrl = AnimationController(vsync: this, duration: 400.ms);
    _coinAnim = CurvedAnimation(parent: _coinCtrl, curve: Curves.easeIn);
    Future.delayed(850.ms, () {
      if (mounted) _coinCtrl.forward();
    });
  }

  @override
  void dispose() {
    _coinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pig
          SizedBox(
            width: 120,
            height: 130,
            child: CustomPaint(painter: _PiggyPainter(), size: const Size(120, 130)),
          )
              .animate()
              .scale(
                begin: const Offset(0.05, 0.05),
                duration: 700.ms,
                curve: Curves.elasticOut,
              )
              .shimmer(delay: 650.ms, duration: 700.ms, color: Colors.white54),

          // Gold coin falling into slot
          AnimatedBuilder(
            animation: _coinAnim,
            builder: (_, __) {
              final t       = _coinAnim.value;
              final opacity = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
              return Positioned(
                left: 40,
                top:  6 + t * 40,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
                        center: Alignment(-0.3, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8F00).withValues(alpha: 0.50),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '€',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  // Canvas: 120 × 130. Pig faces right.
  static const _pink   = Color(0xFFFF80AB);
  static const _light  = Color(0xFFFFCDD2);
  static const _dark   = Color(0xFFAD1457);
  static const _darker = Color(0xFF880E4F);

  @override
  void paint(Canvas canvas, Size size) {
    // ── Body ────────────────────────────────────────────────────────────────
    final bodyRect = Rect.fromLTWH(8, 52, 86, 62);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = RadialGradient(
          colors: [_light, _pink, _dark.withValues(alpha: 0.85)],
          center: const Alignment(-0.2, -0.4),
          radius: 0.9,
        ).createShader(bodyRect),
    );
    canvas.drawOval(
      Rect.fromLTWH(14, 55, 32, 16),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // ── Head ────────────────────────────────────────────────────────────────
    final headRect = Rect.fromLTWH(60, 28, 54, 52);
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = RadialGradient(
          colors: [_light, _pink, _dark.withValues(alpha: 0.85)],
          center: const Alignment(-0.3, -0.4),
          radius: 0.85,
        ).createShader(headRect),
    );
    canvas.drawOval(
      Rect.fromLTWH(64, 30, 22, 13),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // ── Ears ────────────────────────────────────────────────────────────────
    canvas.drawOval(Rect.fromLTWH(63, 21, 15, 18), Paint()..color = _pink);
    canvas.drawOval(Rect.fromLTWH(65, 23, 9, 11), Paint()..color = const Color(0xFFF48FB1));
    canvas.drawOval(Rect.fromLTWH(82, 19, 15, 18), Paint()..color = _pink);
    canvas.drawOval(Rect.fromLTWH(84, 21, 9, 11), Paint()..color = const Color(0xFFF48FB1));

    // ── Snout ───────────────────────────────────────────────────────────────
    canvas.drawOval(Rect.fromLTWH(99, 57, 19, 14), Paint()..color = const Color(0xFFF06292));
    canvas.drawCircle(const Offset(104, 64), 3, Paint()..color = _darker);
    canvas.drawCircle(const Offset(113, 64), 3, Paint()..color = _darker);

    // ── Eye ─────────────────────────────────────────────────────────────────
    canvas.drawCircle(const Offset(87, 50), 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(87, 50), 3.5, Paint()..color = const Color(0xFF212121));
    canvas.drawCircle(const Offset(88.5, 48.5), 1.3, Paint()..color = Colors.white);

    // ── Coin slot ───────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(40, 53, 22, 5), const Radius.circular(2)),
      Paint()..color = _darker,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(41, 54, 20, 2), const Radius.circular(1)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // ── Tail ────────────────────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(10, 76)
        ..cubicTo(0, 68, -1, 57, 8, 54)
        ..cubicTo(14, 51, 16, 58, 9, 62),
      Paint()
        ..color = _pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // ── Legs (4) ────────────────────────────────────────────────────────────
    for (int i = 0; i < 4; i++) {
      final lx = 14.0 + i * 22.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx, 106, 13, 18), const Radius.circular(5)),
        Paint()..color = _pink,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(lx + 2, 106, 5, 8), const Radius.circular(3)),
        Paint()..color = _light.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_PiggyPainter old) => false;
}

// ── Debt Card (Schulden) ──────────────────────────────────────────────────────

class _DebtCardWidget extends StatelessWidget {
  const _DebtCardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 92,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF5350).withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle (card bg detail)
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: -28,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Chip
          Positioned(
            left: 14,
            top: 18,
            child: Container(
              width: 28,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // −€ label
          const Center(
            child: Text(
              '−€',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(1, 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.05, 0.05),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .shimmer(delay: 550.ms, duration: 800.ms, color: Colors.white38);
  }
}
