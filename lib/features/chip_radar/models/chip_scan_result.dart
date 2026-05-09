import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChipScanResult {
  const ChipScanResult({
    required this.ticker,
    this.firestoreName,
    required this.price,
    required this.change1d,
    required this.change7d,
    required this.change14d,
    required this.change21d,
    required this.volumeRatio,
    required this.lastUpdated,
    this.waveLabel,
  });

  final String ticker;
  final double price;
  final double change1d;
  final double change7d;
  final double change14d;
  final double change21d;
  final double volumeRatio;
  final String lastUpdated;
  final String? firestoreName;
  final String? waveLabel; // "extended" | "running" | "early" | "watching" | null

  factory ChipScanResult.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChipScanResult(
      ticker:        d['ticker']        as String? ?? doc.id,
      firestoreName: d['name']          as String?,
      price:         (d['price']        as num?)?.toDouble() ?? 0,
      change1d:      (d['change_1d']    as num?)?.toDouble() ?? 0,
      change7d:      (d['change_7d']    as num?)?.toDouble() ?? 0,
      change14d:     (d['change_14d']   as num?)?.toDouble() ?? 0,
      change21d:     (d['change_21d']   as num?)?.toDouble() ?? 0,
      volumeRatio:   (d['volume_ratio'] as num?)?.toDouble() ?? 0,
      lastUpdated:   d['last_updated']  as String? ?? '',
      waveLabel:     d['wave_label']    as String?,
    );
  }

  // ── Threshold definitions ─────────────────────────────────────────────────

  static const Map<String, double> thresholds = {
    '1d':   10.0,
    '7d':   20.0,
    '7d_s': 35.0,
    '14d':  40.0,
    '21d':  60.0,
    'vol':   2.0,
  };

  double valueFor(String window) => switch (window) {
    '1d'   => change1d,
    '7d'   => change7d,
    '7d_s' => change7d,
    '14d'  => change14d,
    '21d'  => change21d,
    'vol'  => volumeRatio,
    _      => 0,
  };

  bool isAboveThreshold(String window) {
    final threshold = thresholds[window];
    if (threshold == null) return false;
    return valueFor(window) >= threshold;
  }

  bool isApproaching(String window) {
    final threshold = thresholds[window];
    if (threshold == null) return false;
    final val = valueFor(window);
    return val >= threshold * 0.85 && val < threshold;
  }

  Color cellColor(String window, {required bool isDark}) {
    if (isAboveThreshold(window)) {
      return isDark ? const Color(0xFF2E7D32) : const Color(0xFF43A047);
    }
    if (isApproaching(window)) {
      return isDark ? const Color(0xFF7B5800) : const Color(0xFFF9A825);
    }
    return Colors.transparent;
  }

  bool get hasSurge =>
      isAboveThreshold('1d') ||
      isAboveThreshold('7d') ||
      isAboveThreshold('14d') ||
      isAboveThreshold('21d') ||
      isAboveThreshold('vol');
}

// ── Wave label styling ────────────────────────────────────────────────────────

(String display, Color color) waveLabelStyle(String? label) => switch (label) {
      'extended' => ('Extended', const Color(0xFFEF5350)),
      'running'  => ('Running',  const Color(0xFFFFCA28)),
      'early'    => ('Early',    const Color(0xFF66BB6A)),
      'watching' => ('Watching', const Color(0xFF42A5F5)),
      _          => ('',         Colors.transparent),
    };
