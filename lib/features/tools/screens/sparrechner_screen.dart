import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import 'tools_widgets.dart';

class SparrechnerScreen extends StatefulWidget {
  const SparrechnerScreen({super.key, this.scrollController});
  final ScrollController? scrollController;

  @override
  State<SparrechnerScreen> createState() => _SparrechnerScreenState();
}

class _SparrechnerScreenState extends State<SparrechnerScreen> {
  final _anfangsCtrl = TextEditingController(text: '5000');
  final _sparrateCtrl = TextEditingController(text: '150');
  final _zinsCtrl = TextEditingController(text: '7,0');
  final _laufzeitCtrl = TextEditingController(text: '20');

  int _sparM = 12; // contributions per year: 12=monatlich, 4=vierteljährlich, 1=jährlich

  double _anfang = 5000;
  double _sparrate = 150;
  double _zins = 7.0;
  int _laufzeit = 20;

  void _parse() {
    setState(() {
      _anfang = _pd(_anfangsCtrl.text) ?? _anfang;
      _sparrate = _pd(_sparrateCtrl.text) ?? _sparrate;
      _zins = _pd(_zinsCtrl.text) ?? _zins;
      _laufzeit = int.tryParse(_laufzeitCtrl.text.trim()) ?? _laufzeit;
    });
  }

  double? _pd(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  /// Simulate month-by-month compound growth and return (balance, totalContributions).
  (double, double) _compute(int years) {
    double balance = _anfang;
    double contributions = _anfang;
    final monthlyRate = _zins / 100 / 12;
    final everyNMonths = 12 ~/ _sparM;

    for (int m = 1; m <= years * 12; m++) {
      balance *= (1 + monthlyRate);
      if (m % everyNMonths == 0) {
        balance += _sparrate;
        contributions += _sparrate;
      }
    }
    return (balance, contributions);
  }

  List<(double, double)> get _chartData {
    return List.generate(_laufzeit + 1, (y) => _compute(y));
  }

  @override
  void dispose() {
    _anfangsCtrl.dispose();
    _sparrateCtrl.dispose();
    _zinsCtrl.dispose();
    _laufzeitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _chartData;
    final (endKapital, totalContributions) = data.last;
    final zinsertraege = endKapital - totalContributions;
    final rendite = totalContributions > 0
        ? zinsertraege / totalContributions * 100
        : 0.0;

    final balanceSpots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.$1))
        .toList();
    final contributionSpots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.$2))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Sparrechner',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('ETF & Fondssimulator',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),

          ToolInputField(
            label: 'Anfangskapital (€)',
            controller: _anfangsCtrl,
            onChanged: (_) => _parse(),
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          ToolInputField(
            label: 'Sparrate (€)',
            controller: _sparrateCtrl,
            onChanged: (_) => _parse(),
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),

          const Text('Sparintervall',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              ToolIntervalChip(
                  label: 'Monatlich',
                  selected: _sparM == 12,
                  onTap: () => setState(() => _sparM = 12)),
              const SizedBox(width: 8),
              ToolIntervalChip(
                  label: 'Vierteljährlich',
                  selected: _sparM == 4,
                  onTap: () => setState(() => _sparM = 4)),
              const SizedBox(width: 8),
              ToolIntervalChip(
                  label: 'Jährlich',
                  selected: _sparM == 1,
                  onTap: () => setState(() => _sparM = 1)),
            ],
          ),
          const SizedBox(height: 14),
          ToolInputField(
            label: 'Erwartete Rendite p.a. (%)',
            controller: _zinsCtrl,
            onChanged: (_) => _parse(),
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          ToolInputField(
            label: 'Laufzeit (Jahre)',
            controller: _laufzeitCtrl,
            onChanged: (_) => _parse(),
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 28),

          // Growth chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Entwicklung',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval:
                                max(1, (_laufzeit / 4).floorToDouble()),
                            getTitlesWidget: (value, _) => Text(
                              'J${value.toInt()}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: balanceSpots,
                          isCurved: true,
                          color: AppColors.darkPrimary,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.darkPrimary
                                    .withValues(alpha: 0.25),
                                AppColors.darkPrimary
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        LineChartBarData(
                          spots: contributionSpots,
                          isCurved: false,
                          color: Colors.white30,
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                          dashArray: [4, 4],
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                        width: 16, height: 3,
                        color: AppColors.darkPrimary,
                        margin: const EdgeInsets.only(right: 5)),
                    const Text('Gesamtwert',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    const SizedBox(width: 16),
                    Container(
                        width: 16, height: 1,
                        color: Colors.white30,
                        margin: const EdgeInsets.only(right: 5)),
                    const Text('Einzahlungen',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Result card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.darkPrimary.withValues(alpha: 0.15),
                  AppColors.darkPrimary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.darkPrimary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Endkapital',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(endKapital),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'nach $_laufzeit ${_laufzeit == 1 ? 'Jahr' : 'Jahren'}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                ToolResultRow(
                  label: 'Gesamt-Einzahlungen',
                  value: CurrencyFormatter.format(totalContributions),
                  color: Colors.white54,
                ),
                const SizedBox(height: 8),
                ToolResultRow(
                  label: 'Zinserträge / Gewinne',
                  value: '+${CurrencyFormatter.format(zinsertraege)}',
                  color: AppColors.darkPositive,
                ),
                const SizedBox(height: 8),
                ToolResultRow(
                  label: 'Gesamtrendite',
                  value: '+${rendite.toStringAsFixed(1)}%',
                  color: AppColors.darkPositive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
