import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chip_scan_result.dart';

void showStockDetailSheet(BuildContext context, ChipScanResult result) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StockDetailSheet(result: result),
  );
}

class _StockDetailSheet extends StatelessWidget {
  const _StockDetailSheet({required this.result});
  final ChipScanResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header: ticker + company name | current price
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.ticker,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (r.firestoreName != null)
                          Text(r.firestoreName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5))),
                      ],
                    ),
                  ),
                  Text(
                    '\$${r.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF66BB6A)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Gesamt-Score + wave badge
                  if (r.score != null) ...[
                    _ScoreRow(score: r.score!, waveLabel: r.waveLabel),
                    const SizedBox(height: 12),
                  ],
                  // 2. Relative Stärke card
                  if (r.rs21Rank != null || r.rs63Rank != null) ...[
                    _RsRankCard(result: r)
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 16),
                  ],
                  // 3. Kennzahlen row
                  _KennzahlenRow(result: r)
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 20),
                  // 4. Browser buttons
                  _BrowserButtons(ticker: r.ticker)
                      .animate()
                      .fadeIn(delay: 160.ms, duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Score row ─────────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score, required this.waveLabel});
  final int score;
  final String? waveLabel;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (score >= 80) {
      bg = const Color(0xFFEAF3DE); fg = const Color(0xFF3B6D11);
    } else if (score >= 60) {
      bg = const Color(0xFFFAEEDA); fg = const Color(0xFF854F0B);
    } else {
      bg = Theme.of(context).colorScheme.surfaceContainerHighest;
      fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }

    final (waveDisplay, waveColor) = waveLabelStyle(waveLabel);

    return Row(
      children: [
        Text('Gesamt-Score',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text('$score',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
        ),
        if (waveDisplay.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: waveColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: waveColor.withOpacity(0.5)),
            ),
            child: Text(waveDisplay,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: waveColor)),
          ),
        ],
      ],
    );
  }
}

// ── RS rank card ──────────────────────────────────────────────────────────────

class _RsRankCard extends StatelessWidget {
  const _RsRankCard({required this.result});
  final ChipScanResult result;

  static String _rsLabel(int rank) {
    if (rank >= 90) return 'Marktführer';
    if (rank >= 75) return 'Überdurchschnittlich';
    if (rank >= 50) return 'Durchschnitt';
    return 'Unterdurchschnittlich';
  }

  static Color _rsColor(int rank) {
    if (rank >= 90) return const Color(0xFF66BB6A);
    if (rank >= 75) return const Color(0xFF42A5F5);
    if (rank >= 50) return const Color(0xFFFFCA28);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return _Card(
      title: 'Relative Stärke',
      child: Column(
        children: [
          if (r.rs21Rank != null)
            _RsRankRow(
              label: 'RS(21d)',
              rank: r.rs21Rank!,
              rsLabel: _rsLabel(r.rs21Rank!),
              color: _rsColor(r.rs21Rank!),
            ),
          if (r.rs21Rank != null && r.rs63Rank != null)
            const SizedBox(height: 14),
          if (r.rs63Rank != null)
            _RsRankRow(
              label: 'RS(63d)',
              rank: r.rs63Rank!,
              rsLabel: _rsLabel(r.rs63Rank!),
              color: _rsColor(r.rs63Rank!),
            ),
        ],
      ),
    );
  }
}

class _RsRankRow extends StatelessWidget {
  const _RsRankRow({
    required this.label,
    required this.rank,
    required this.rsLabel,
    required this.color,
  });
  final String label;
  final int rank;
  final String rsLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final topPct = 100 - rank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: rank / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text(
                '$rank. Pz.',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$rsLabel  ·  Top $topPct%',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Kennzahlen row ────────────────────────────────────────────────────────────

class _KennzahlenRow extends StatelessWidget {
  const _KennzahlenRow({required this.result});
  final ChipScanResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return _Card(
      title: 'Kennzahlen',
      child: Row(
        children: [
          _KennzahlCell(
            label: 'Preis',
            value: '\$${r.price.toStringAsFixed(2)}',
          ),
          _KennzahlCell(
            label: '7d%',
            value:
                '${r.change7d >= 0 ? '+' : ''}${r.change7d.toStringAsFixed(1)}%',
            valueColor: r.change7d >= 0
                ? const Color(0xFF66BB6A)
                : const Color(0xFFEF5350),
          ),
          _KennzahlCell(
            label: '21d%',
            value:
                '${r.change21d >= 0 ? '+' : ''}${r.change21d.toStringAsFixed(1)}%',
            valueColor: r.change21d >= 0
                ? const Color(0xFF66BB6A)
                : const Color(0xFFEF5350),
          ),
          _KennzahlCell(
            label: 'Vol/Ø',
            value: '${r.volumeRatio.toStringAsFixed(1)}×',
            valueColor:
                r.volumeRatio >= 2.0 ? const Color(0xFF42A5F5) : null,
          ),
        ],
      ),
    );
  }
}

class _KennzahlCell extends StatelessWidget {
  const _KennzahlCell(
      {required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }
}

// ── Browser buttons ───────────────────────────────────────────────────────────

class _BrowserButtons extends StatelessWidget {
  const _BrowserButtons({required this.ticker});
  final String ticker;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                _open('https://finance.yahoo.com/quote/$ticker/analysis/'),
            icon: const Text('📊', style: TextStyle(fontSize: 14)),
            label: const Text('Analyse'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                _open('https://finance.yahoo.com/quote/$ticker/chart/'),
            icon: const Text('📈', style: TextStyle(fontSize: 14)),
            label: const Text('Chart'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                _open('https://finance.yahoo.com/quote/$ticker/profile/'),
            icon: const Text('🏢', style: TextStyle(fontSize: 14)),
            label: const Text('Profil'),
          ),
        ),
      ],
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
