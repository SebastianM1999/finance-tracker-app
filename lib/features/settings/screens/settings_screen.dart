import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/profile_image_stub.dart'
    if (dart.library.js_interop) '../../../shared/widgets/profile_image_web.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/providers/home_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          _SectionCard(
            child: ListTile(
              leading: user?.photoUrl != null
                  ? ClipOval(child: buildProfileImage(user!.photoUrl!, 48))
                  : CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.darkPrimary,
                      child: Text(
                        user?.displayName.substring(0, 1).toUpperCase() ?? 'D',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
              title: Text(user?.displayName ?? 'Nutzer',
                  style: theme.textTheme.titleMedium),
              subtitle: Text(user?.email ?? '',
                  style: theme.textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 20),

          // Appearance
          _SectionHeader('Darstellung'),
          _SectionCard(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Dunkles Erscheinungsbild'),
              secondary: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(height: 20),

          // Notifications
          _SectionHeader('Benachrichtigungen'),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Festgeld-Erinnerungen'),
              subtitle: const Text('30, 7, 1 Tag vor Fälligkeit'),
              trailing: kIsWeb
                  ? const Chip(label: Text('Nur mobil'))
                  : const Icon(Icons.check_circle_outline,
                      color: AppColors.darkPositive),
            ),
          ),
          const SizedBox(height: 20),

          // Data
          _SectionHeader('Daten'),
          _SectionCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Als JSON exportieren'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportJson(context, ref),
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppColors.darkSecondary),
                  title: const Text('Alle Daten löschen',
                      style: TextStyle(color: AppColors.darkSecondary)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _deleteAllData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account
          _SectionHeader('Account'),
          _SectionCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.darkSecondary),
              title: const Text('Abmelden',
                  style: TextStyle(color: AppColors.darkSecondary)),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Text('FinTrack v1.0.0',
                style: theme.textTheme.labelSmall),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final giro = ref.read(giroStreamProvider).valueOrNull ?? [];
      final festgeld = ref.read(festgeldStreamProvider).valueOrNull ?? [];
      final etf = ref.read(etfStreamProvider).valueOrNull ?? [];
      final crypto = ref.read(cryptoStreamProvider).valueOrNull ?? [];
      final assets = ref.read(assetsStreamProvider).valueOrNull ?? [];
      final schulden = ref.read(schuldenStreamProvider).valueOrNull ?? [];

      final data = {
        'exportedAt': DateTime.now().toIso8601String(),
        'giro': giro.map((e) => e.toFirestore()).toList(),
        'festgeld': festgeld.map((e) => e.toFirestore()).toList(),
        'etf_stocks': etf.map((e) => e.toFirestore()).toList(),
        'crypto': crypto.map((e) => e.toFirestore()).toList(),
        'physical_assets': assets.map((e) => e.toFirestore()).toList(),
        'schulden': schulden.map((e) => e.toFirestore()).toList(),
      };

      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON in Zwischenablage kopiert ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Alle Daten löschen',
      message:
          'Alle Konten, Investments und Schulden werden unwiderruflich gelöscht. Fortfahren?',
      confirmLabel: 'Alles löschen',
    );
    if (!confirmed) return;

    try {
      final giro = ref.read(giroStreamProvider).valueOrNull ?? [];
      final festgeld = ref.read(festgeldStreamProvider).valueOrNull ?? [];
      final etf = ref.read(etfStreamProvider).valueOrNull ?? [];
      final crypto = ref.read(cryptoStreamProvider).valueOrNull ?? [];
      final assets = ref.read(assetsStreamProvider).valueOrNull ?? [];
      final schulden = ref.read(schuldenStreamProvider).valueOrNull ?? [];

      final giroRepo = ref.read(giroRepositoryProvider);
      final festgeldRepo = ref.read(festgeldRepositoryProvider);
      final etfRepo = ref.read(etfRepositoryProvider);
      final cryptoRepo = ref.read(cryptoRepositoryProvider);
      final assetsRepo = ref.read(assetsRepositoryProvider);
      final schuldenRepo = ref.read(schuldenRepositoryProvider);

      await Future.wait([
        ...giro.map((e) => giroRepo.delete(e.id)),
        ...festgeld.map((e) => festgeldRepo.delete(e.id)),
        ...etf.map((e) => etfRepo.delete(e.id)),
        ...crypto.map((e) => cryptoRepo.delete(e.id)),
        ...assets.map((e) => assetsRepo.delete(e.id)),
        ...schulden.map((e) => schuldenRepo.delete(e.id)),
      ]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Daten gelöscht'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: child);
  }
}
