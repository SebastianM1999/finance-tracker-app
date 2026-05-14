import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chip_alert.dart';
import '../models/chip_scan_result.dart';

// Known company names for display alongside the ticker
const Map<String, String> _companyNames = {
  'NVDA':  'NVIDIA',
  'AMD':   'Advanced Micro Devices',
  'INTC':  'Intel',
  'QCOM':  'Qualcomm',
  'AVGO':  'Broadcom',
  'TSM':   'Taiwan Semiconductor',
  'AMAT':  'Applied Materials',
  'LRCX':  'Lam Research',
  'KLAC':  'KLA Corporation',
  'MRVL':  'Marvell Technology',
  'MU':    'Micron Technology',
  'SNDK':  'SanDisk',
  'SMCI':  'Super Micro Computer',
  'ARM':   'Arm Holdings',
  'ASML':  'ASML Holding',
  'ON':    'ON Semiconductor',
  'LITE':  'Lumentum',
  'TXN':   'Texas Instruments',
  'NXPI':  'NXP Semiconductors',
  'WOLF':  'Wolfspeed',
  'CRUS':  'Cirrus Logic',
  'MPWR':  'Monolithic Power',
  'SWKS':  'Skyworks Solutions',
  'QRVO':  'Qorvo',
  'MTSI':  'MACOM Technology',
  'ACLS':  'Axcelis Technologies',
  'COHU':  'Cohu',
  'FORM':  'FormFactor',
  'POWI':  'Power Integrations',
  'SITM':  'SiTime Corporation',
};

String companyName(String ticker) => _companyNames[ticker] ?? ticker;


final chipScanResultsProvider = StreamProvider<List<ChipScanResult>>((ref) {
  return FirebaseFirestore.instance
      .collection('chip_radar_scanResults')
      .snapshots()
      .map((snap) => snap.docs
          .map(ChipScanResult.fromFirestore)
          .toList()
        ..sort((a, b) {
          final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
          if (scoreCmp != 0) return scoreCmp;
          return (b.rs21Rank ?? 0).compareTo(a.rs21Rank ?? 0);
        }));
});

// Keyed by ticker for O(1) lookup in the Alarme tab performance calculation
final chipScanResultsMapProvider = StreamProvider<Map<String, ChipScanResult>>((ref) {
  return FirebaseFirestore.instance
      .collection('chip_radar_scanResults')
      .snapshots()
      .map((snap) {
        final map = <String, ChipScanResult>{};
        for (final doc in snap.docs) {
          final r = ChipScanResult.fromFirestore(doc);
          map[r.ticker] = r;
        }
        return map;
      });
});

final chipAlertHistoryProvider = StreamProvider<List<ChipAlert>>((ref) {
  return FirebaseFirestore.instance
      .collection('chip_radar_alertHistory')
      .orderBy('timestamp', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs.map(ChipAlert.fromFirestore).toList());
});

// ── Wave-label filter (persisted via SharedPreferences) ───────────────────────
//
// State is a Set<String> of active wave labels.
// Empty set  → show all stocks (no filter active).
// Non-empty  → show only stocks whose waveLabel is in the set.
// Persisted under the key below so the selection survives app restarts.

class ChipRadarFilterNotifier extends StateNotifier<Set<String>> {
  ChipRadarFilterNotifier() : super(const {}) {
    _load();
  }

  static const _prefKey = 'chip_radar_wave_filter';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = Set<String>.from(saved);
    }
  }

  Future<void> toggle(String label) async {
    final next = Set<String>.from(state);
    if (next.contains(label)) {
      next.remove(label);
    } else {
      next.add(label);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setStringList(_prefKey, next.toList());
    }
  }

  Future<void> clearAll() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

final chipRadarFilterProvider =
    StateNotifierProvider<ChipRadarFilterNotifier, Set<String>>(
  (ref) => ChipRadarFilterNotifier(),
);
