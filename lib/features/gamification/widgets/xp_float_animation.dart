import 'package:flutter/material.dart';

/// Shows a floating "+X XP" label that rises and fades out.
class XPFloatAnimation {
  XPFloatAnimation._();

  static void show(BuildContext context, int xp) {
    if (xp <= 0) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: _XPFloatWidget(
          xp: xp,
          onDone: entry.remove,
        ),
      ),
    );

    overlay.insert(entry);
  }
}

class _XPFloatWidget extends StatefulWidget {
  const _XPFloatWidget({required this.xp, required this.onDone});
  final int xp;
  final VoidCallback onDone;

  @override
  State<_XPFloatWidget> createState() => _XPFloatWidgetState();
}

class _XPFloatWidgetState extends State<_XPFloatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _yAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _yAnim = Tween<double>(begin: 0, end: -64).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      ),
    );

    // Pop in quickly, then hold
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutBack),
      ),
    );

    _ctrl.forward().whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Center of screen, slightly above middle
    final startX = screenSize.width / 2;
    const startY = 200.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            left: startX,
            top: startY + _yAnim.value,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: Text(
                      '+${widget.xp} XP',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFD4A017),
                        shadows: [
                          Shadow(
                            color: Color(0xFF8B6000),
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
