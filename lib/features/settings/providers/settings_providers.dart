import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'isDarkMode';
const _kGamificationKey = 'gamificationEnabled';
const _kIsProKey = 'isPro';

/// PRO status — persisted locally via SharedPreferences.
/// In production this would be wired to a real payment/subscription check.
/// Also synced to Firestore so Cloud Functions can check it server-side.
final isProProvider = StateNotifierProvider<ProNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return ProNotifier(prefs);
});

class ProNotifier extends StateNotifier<bool> {
  ProNotifier(this._prefs) : super(_prefs?.getBool(_kIsProKey) ?? false);
  final SharedPreferences? _prefs;

  void toggle() {
    state = !state;
    _prefs?.setBool(_kIsProKey, state);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs)
      : super((_prefs?.getBool(_kThemeKey) ?? true) ? ThemeMode.dark : ThemeMode.light);

  final SharedPreferences? _prefs;

  void toggle() {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setBool(_kThemeKey, !isDark);
  }
}

final gamificationEnabledProvider =
    StateNotifierProvider<GamificationEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return GamificationEnabledNotifier(prefs);
});

class GamificationEnabledNotifier extends StateNotifier<bool> {
  GamificationEnabledNotifier(this._prefs)
      : super(_prefs?.getBool(_kGamificationKey) ?? true);

  final SharedPreferences? _prefs;

  void toggle() {
    state = !state;
    _prefs?.setBool(_kGamificationKey, state);
  }
}
