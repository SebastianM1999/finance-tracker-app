import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/watchlist_repository.dart';
import '../models/watchlist_item.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  final uid = ref.watch(currentUserProvider)!.uid;
  return WatchlistRepository(uid);
});

final watchlistStreamProvider = StreamProvider<List<WatchlistItem>>((ref) {
  return ref.watch(watchlistRepositoryProvider).watchAll();
});
