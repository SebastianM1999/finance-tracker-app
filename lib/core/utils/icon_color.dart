import 'package:flutter/material.dart';

/// Generates a deterministic per-item gradient from any string seed.
/// Uses HSL with fixed saturation/lightness so the color is vivid and
/// readable on both dark AND light backgrounds.
class IconColor {
  IconColor._();

  static List<Color> gradientFor(String seed) {
    // djb2-style hash → stable hue 0–359
    int hash = 5381;
    for (final c in seed.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7FFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    // Lightness 55 % → bright enough for dark bg, saturated enough for light bg
    final base    = HSLColor.fromAHSL(1.0, hue,               0.72, 0.55).toColor();
    final shifted = HSLColor.fromAHSL(1.0, (hue + 25) % 360,  0.65, 0.42).toColor();
    return [base, shifted];
  }
}
