import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/providers/settings_providers.dart';
import '../widgets/analyse_feature_tile.dart';
import '../widgets/analyse_paywall.dart';

class AnalyseScreen extends ConsumerWidget {
  const AnalyseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse'),
        centerTitle: false,
      ),
      body: isPro ? const _AnalyseHub() : const AnalysePaywall(),
    );
  }
}

class _AnalyseHub extends StatelessWidget {
  const _AnalyseHub();

  static const _features = [
    (
      Icons.percent,
      AppColors.chartEtf,
      'Investitionsrendite',
      'ROI über alle Investments',
      AppRoutes.analyseRendite,
    ),
    (
      Icons.shield_outlined,
      AppColors.chartCrypto,
      'Risikoprofil',
      'Wie riskant ist dein Portfolio',
      AppRoutes.analyseRisiko,
    ),
    (
      Icons.emoji_events_outlined,
      AppColors.chartPhysical,
      'Top & Flop Positionen',
      'Beste und schlechteste Investments',
      AppRoutes.analyseTopFlop,
    ),
    (
      Icons.stacked_line_chart_outlined,
      AppColors.chartFestgeld,
      'Kategorie-Entwicklung',
      'Verlauf je Anlageklasse',
      AppRoutes.analyseKategorien,
    ),
    (
      Icons.savings_outlined,
      Color(0xFF7BC4E2),
      'Festgeld & Zinserträge',
      'Zinsprognose deiner Festgelder',
      AppRoutes.analyseFestgeld,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return ListView.separated(
      itemCount: _features.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: outline.withValues(alpha: 0.15)),
      itemBuilder: (context, i) {
        final (icon, color, title, description, route) = _features[i];
        return AnalyseFeatureTile(
          icon: icon,
          color: color,
          title: title,
          description: description,
          onTap: () => context.push(route),
        );
      },
    );
  }
}
