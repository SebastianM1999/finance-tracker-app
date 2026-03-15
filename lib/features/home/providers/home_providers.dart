import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../crypto/data/crypto_repository.dart';
import '../../etf_stocks/data/etf_repository.dart';
import '../../festgeld/data/festgeld_repository.dart';
import '../../festgeld/models/festgeld.dart';
import '../../giro/data/giro_repository.dart';
import '../../physical_assets/data/assets_repository.dart';
import '../../schulden/data/schulden_repository.dart';
import '../data/net_worth_repository.dart';
import '../models/net_worth_snapshot.dart';

// ── Repositories ─────────────────────────────────────────────────────────────

final giroRepositoryProvider = Provider<GiroRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return GiroRepository(uid);
});

final festgeldRepositoryProvider = Provider<FestgeldRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return FestgeldRepository(uid);
});

final etfRepositoryProvider = Provider<EtfRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return EtfRepository(uid);
});

final cryptoRepositoryProvider = Provider<CryptoRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return CryptoRepository(uid);
});

final assetsRepositoryProvider = Provider<AssetsRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return AssetsRepository(uid);
});

final schuldenRepositoryProvider = Provider<SchuldenRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return SchuldenRepository(uid);
});

final netWorthRepositoryProvider = Provider<NetWorthRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return NetWorthRepository(uid);
});

// ── Live data streams ─────────────────────────────────────────────────────────

final giroStreamProvider = StreamProvider((ref) =>
    ref.watch(giroRepositoryProvider).watchAll());

final festgeldStreamProvider = StreamProvider((ref) =>
    ref.watch(festgeldRepositoryProvider).watchAll());

final etfStreamProvider = StreamProvider((ref) =>
    ref.watch(etfRepositoryProvider).watchAll());

final cryptoStreamProvider = StreamProvider((ref) =>
    ref.watch(cryptoRepositoryProvider).watchAll());

final assetsStreamProvider = StreamProvider((ref) =>
    ref.watch(assetsRepositoryProvider).watchAll());

final schuldenStreamProvider = StreamProvider((ref) =>
    ref.watch(schuldenRepositoryProvider).watchAll());

/// Streams history snapshots for a given number of days (0 = all time).
final netWorthRangeProvider =
    StreamProvider.family<List<NetWorthSnapshot>, int>((ref, days) =>
        ref.watch(netWorthRepositoryProvider).watchRange(days));

// Keep a 30-day alias used by the home screen change badge.
final netWorthHistoryProvider = StreamProvider((ref) =>
    ref.watch(netWorthRepositoryProvider).watchRange(30));

// ── Category totals ───────────────────────────────────────────────────────────

final giroTotalProvider = Provider<double>((ref) {
  final list = ref.watch(giroStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, a) => sum + a.balance);
});

final festgeldTotalProvider = Provider<double>((ref) {
  final list = ref.watch(festgeldStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, f) => sum + f.amount);
});

final etfTotalProvider = Provider<double>((ref) {
  final list = ref.watch(etfStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, p) => sum + p.currentValue);
});

final cryptoTotalProvider = Provider<double>((ref) {
  final list = ref.watch(cryptoStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, p) => sum + p.currentValue);
});

final assetsTotalProvider = Provider<double>((ref) {
  final list = ref.watch(assetsStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, a) => sum + a.currentValue);
});

final schuldenTotalProvider = Provider<double>((ref) {
  final list = ref.watch(schuldenStreamProvider).valueOrNull ?? [];
  return list.fold(0.0, (sum, s) => sum + (s.iOwe ? -s.amount : s.amount));
});

// ── Net worth ─────────────────────────────────────────────────────────────────

final netWorthProvider = Provider<double>((ref) {
  return ref.watch(giroTotalProvider) +
      ref.watch(festgeldTotalProvider) +
      ref.watch(etfTotalProvider) +
      ref.watch(cryptoTotalProvider) +
      ref.watch(assetsTotalProvider) +
      ref.watch(schuldenTotalProvider);
});

// ── Net worth change vs last snapshot ────────────────────────────────────────

final netWorthChangeProvider =
    Provider<({double absolute, double percent})>((ref) {
  final history = ref.watch(netWorthHistoryProvider).valueOrNull ?? [];
  final current = ref.watch(netWorthProvider);

  if (history.length < 2) return (absolute: 0.0, percent: 0.0);

  final previous = history[history.length - 2].totalNetWorth;
  final absolute = current - previous;
  final percent = previous == 0 ? 0.0 : (absolute / previous) * 100;
  return (absolute: absolute, percent: percent);
});

// ── Auto-save net worth snapshot on every data change ────────────────────────
//
// This provider is watched by HomeScreen. Every time any of the 6 streams
// emits new data (i.e. the user saves/edits/deletes any position), we upsert
// today's snapshot in Firestore — capturing the full position list so users
// can drill down into what they had on any given day.

final autoSaveNetWorthProvider = Provider<void>((ref) {
  final giroAsync = ref.watch(giroStreamProvider);
  final festgeldAsync = ref.watch(festgeldStreamProvider);
  final etfAsync = ref.watch(etfStreamProvider);
  final cryptoAsync = ref.watch(cryptoStreamProvider);
  final assetsAsync = ref.watch(assetsStreamProvider);
  final schuldenAsync = ref.watch(schuldenStreamProvider);

  // Only save once all 6 streams have loaded
  if (!giroAsync.hasValue ||
      !festgeldAsync.hasValue ||
      !etfAsync.hasValue ||
      !cryptoAsync.hasValue ||
      !assetsAsync.hasValue ||
      !schuldenAsync.hasValue) { return; }

  final giroList = giroAsync.value!;
  final festgeldList = festgeldAsync.value!;
  final etfList = etfAsync.value!;
  final cryptoList = cryptoAsync.value!;
  final assetsList = assetsAsync.value!;
  final schuldenList = schuldenAsync.value!;

  final positions = [
    ...giroList.map((a) => SnapshotPosition(
          category: 'giro',
          name: '${a.bankName} – ${a.accountLabel}',
          value: a.balance,
        )),
    ...festgeldList.map((f) => SnapshotPosition(
          category: 'festgeld',
          name: f.bankName,
          value: f.amount,
        )),
    ...etfList.map((e) => SnapshotPosition(
          category: 'etf',
          name: e.ticker != null ? '${e.name} (${e.ticker})' : e.name,
          value: e.currentValue,
        )),
    ...cryptoList.map((c) => SnapshotPosition(
          category: 'crypto',
          name: '${c.coinName} (${c.coinSymbol})',
          value: c.currentValue,
        )),
    ...assetsList.map((a) => SnapshotPosition(
          category: 'physical',
          name: a.description,
          value: a.currentValue,
        )),
    ...schuldenList.map((s) => SnapshotPosition(
          category: 'schulden',
          name: s.personOrInstitution,
          value: s.iOwe ? -s.amount : s.amount,
        )),
  ];

  final giroTotal = giroList.fold(0.0, (sum, a) => sum + a.balance);
  final festgeldTotal = festgeldList.fold(0.0, (sum, f) => sum + f.amount);
  final etfTotal = etfList.fold(0.0, (sum, e) => sum + e.currentValue);
  final cryptoTotal = cryptoList.fold(0.0, (sum, c) => sum + c.currentValue);
  final assetsTotal = assetsList.fold(0.0, (sum, a) => sum + a.currentValue);
  final schuldenTotal = schuldenList.fold(
      0.0, (sum, s) => sum + (s.iOwe ? -s.amount : s.amount));

  final snapshot = NetWorthSnapshot(
    id: '',
    totalNetWorth: giroTotal +
        festgeldTotal +
        etfTotal +
        cryptoTotal +
        assetsTotal +
        schuldenTotal,
    giro: giroTotal,
    festgeld: festgeldTotal,
    etfStocks: etfTotal,
    crypto: cryptoTotal,
    physical: assetsTotal,
    schulden: schuldenTotal,
    recordedAt: DateTime.now(),
    positions: positions,
  );

  // Fire-and-forget — runs after the current build frame
  Future.microtask(
      () => ref.read(netWorthRepositoryProvider).saveOrUpdate(snapshot));
});

// ── Upcoming Festgeld maturities (within 60 days) ────────────────────────────

final upcomingMaturitiesProvider = Provider<List<Festgeld>>((ref) {
  final list = ref.watch(festgeldStreamProvider).valueOrNull ?? [];
  return list
      .where((f) => f.daysRemaining >= 0 && f.daysRemaining <= 60)
      .toList()
    ..sort((a, b) => a.endDate.compareTo(b.endDate));
});
