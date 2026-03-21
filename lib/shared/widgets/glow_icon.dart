import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A floating icon with gradient color via ShaderMask. No box, no glow.
class GlowIcon extends StatelessWidget {
  const GlowIcon({
    super.key,
    required this.icon,
    required this.gradient,
    this.size = 28,
    this.isFa = false,
    // kept for API compatibility, unused
    this.glowOpacity = 0,
    this.glowRadius = 0,
  });

  final dynamic icon;
  final List<Color> gradient;
  final double size;
  final bool isFa;
  final double glowOpacity;
  final double glowRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: isFa
              ? FaIcon(icon as IconData, size: size, color: Colors.white)
              : Icon(icon as IconData, size: size, color: Colors.white),
        ),
      ),
    );
  }
}
