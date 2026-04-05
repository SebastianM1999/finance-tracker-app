import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_providers.dart';

class RisikoDetailScreen extends ConsumerWidget {
  const RisikoDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giro = ref.watch(giroTotalProvider);
    final festgeld = ref.watch(festgeldTotalProvider);
    final etf = ref.watch(etfTotalProvider);
    final crypto = ref.watch(cryptoTotalProvider);
    final assets = ref.watch(assetsTotalProvider);

    final positives = [giro, festgeld, etf, crypto, assets]
        .map((v) => v < 0 ? 0.0 : v)
        .toList();
    final total = positives.fold(0.0, (s, v) => s + v);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risikoprofil'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: onSurface.withValues(alpha: 0.5)),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: total <= 0
          ? Center(
              child: Text(
                'Noch keine Positionen für Risikoanalyse',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 14),
              ),
            )
          : _RisikoBody(
              positives: positives,
              total: total,
              outline: outline,
              onSurface: onSurface,
            ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    const levels = [
      (0.0, 'Konservativ', Color(0xFF3F8ACB),
          'Tagesgeld & Giro – kaum Wertschwankungen, sehr sicher.'),
      (0.0, 'Festgeld', Color(0xFF3F8ACB),
          'Festgeld – gebundenes Kapital, stabil und risikoarm.'),
      (0.3, 'Ausgewogen', Color(0xFF4ADE80),
          'Sachwerte (z. B. Gold, Immobilien) – geringes bis mittleres Risiko.'),
      (0.5, 'Wachstum', Color(0xFFF39C12),
          'ETF & Aktien – Marktrisiko, aber breite Streuung.'),
      (1.0, 'Spekulativ', Color(0xFFFF6B6B),
          'Krypto – hohe Volatilität, maximales Verlustrisiko.'),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Was ist das Risikoprofil?',
            style: TextStyle(
                color: onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dein Risikoprofil zeigt, wie risikoreich dein Portfolio aufgestellt ist – basierend auf der Verteilung deiner Vermögensklassen.',
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            ...levels.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: l.$3, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.$2,
                                style: TextStyle(
                                    color: l.$3,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            Text(l.$4,
                                style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.6),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

class _RisikoBody extends StatelessWidget {
  const _RisikoBody({
    required this.positives,
    required this.total,
    required this.outline,
    required this.onSurface,
  });

  final List<double> positives;
  final double total;
  final Color outline;
  final Color onSurface;

  static (String, Color) _label(double score) {
    if (score < 0.15) return ('Konservativ', Color(0xFF3F8ACB));
    if (score < 0.35) return ('Ausgewogen', Color(0xFF4ADE80));
    if (score < 0.55) return ('Wachstum', Color(0xFFF39C12));
    if (score < 0.75) return ('Offensiv', Color(0xFFE67E22));
    return ('Spekulativ', Color(0xFFFF6B6B));
  }

  @override
  Widget build(BuildContext context) {
    const weights = [0.1, 0.0, 0.5, 1.0, 0.3];
    final riskScore = List.generate(5, (i) => positives[i] * weights[i])
            .fold(0.0, (s, v) => s + v) /
        total;

    final (label, labelColor) = _label(riskScore);

    const names = ['Giro', 'Festgeld', 'ETF & Aktien', 'Krypto', 'Sachwerte'];
    final colors = List.generate(5, (i) => _label(weights[i]).$2);

    const rebalancingTips = [
      ('Konservativ',
          'Dein Portfolio ist sehr sicher aufgestellt. Wenn du mehr Wachstumspotenzial möchtest, könntest du einen kleinen Teil in ETFs investieren.'),
      ('Ausgewogen',
          'Gute Balance aus Sicherheit und Wachstum. Regelmäßiges Rebalancing hält dieses Verhältnis stabil.'),
      ('Wachstum',
          'Du hast ein wachstumsorientiertes Portfolio. Achte darauf, einen Notgroschen in risikoarmen Positionen zu halten.'),
      ('Offensiv',
          'Hohe Renditechancen, aber auch erhöhtes Risiko. Prüfe, ob dein Anteil an sicheren Anlagen ausreicht.'),
      ('Spekulativ',
          'Sehr hohes Risikoprofil. Krypto kann stark schwanken — stelle sicher, dass du nur Kapital investierst, das du langfristig entbehren kannst.'),
    ];

    final tipText = rebalancingTips
        .firstWhere((t) => t.$1 == label,
            orElse: () => rebalancingTips.last)
        .$2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Risk bar card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outline.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Risikoprofil',
                      style: TextStyle(
                          color: onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: labelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: labelColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: labelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFF3F8ACB),
                      Color(0xFF4ADE80),
                      Color(0xFFF39C12),
                      Color(0xFFE67E22),
                      Color(0xFFFF6B6B),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FractionallySizedBox(
                widthFactor: riskScore.clamp(0.02, 0.98),
                alignment: Alignment.centerLeft,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                      width: 2,
                      height: 8,
                      color: onSurface.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Konservativ',
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.38),
                          fontSize: 10)),
                  Text('Spekulativ',
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.38),
                          fontSize: 10)),
                ],
              ),
              const SizedBox(height: 14),
              ...List.generate(5, (i) {
                if (positives[i] <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: colors[i], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(names[i],
                            style: TextStyle(
                                color: onSurface.withValues(alpha: 0.6),
                                fontSize: 12)),
                      ),
                      Text(
                          '${(positives[i] / total * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: onSurface.withValues(alpha: 0.54),
                              fontSize: 11)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Explanation section
        Text('Was bedeutet das?',
            style: TextStyle(
                color: onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outline.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: labelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: labelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(tipText,
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 14),
              Text('Rebalancing-Tipp',
                  style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Überprüfe dein Portfolio regelmäßig (z. B. quartalsweise). Wenn eine Kategorie stark gewachsen ist, kann ein Teilverkauf helfen, die Zielgewichtung wiederherzustellen.',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
