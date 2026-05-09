import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ..sort((a, b) => b.change7d.compareTo(a.change7d)));
});

final chipAlertHistoryProvider = StreamProvider<List<ChipAlert>>((ref) {
  return FirebaseFirestore.instance
      .collection('chip_radar_alertHistory')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(ChipAlert.fromFirestore).toList());
});
