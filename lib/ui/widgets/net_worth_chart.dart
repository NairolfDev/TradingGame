import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/net_worth_history.dart';

enum _Range {
  day('1T', Duration(days: 1)),
  week('1W', Duration(days: 7)),
  all('Alles', null);

  final String label;
  final Duration? window;
  const _Range(this.label, this.window);
}

/// Net worth over time with the gain or loss for the chosen range.
class NetWorthChart extends StatefulWidget {
  final NetWorthHistory history;
  const NetWorthChart({super.key, required this.history});

  @override
  State<NetWorthChart> createState() => _NetWorthChartState();
}

class _NetWorthChartState extends State<NetWorthChart> {
  _Range _range = _Range.all;

  @override
  Widget build(BuildContext context) {
    final points = widget.history.within(_range.window);
    final enough = points.length >= 2;
    final first = enough ? points.first.value : 0.0;
    final last = enough ? points.last.value : 0.0;
    final change = last - first;
    final percent = first > 0 ? change / first * 100 : 0.0;
    final color = change >= 0 ? AppColors.profit : AppColors.loss;
    final sign = change >= 0 ? '+' : '−';
    final summary = enough
        ? '$sign${CurrencyFormatter.format(change.abs())} '
              '($sign${percent.abs().toStringAsFixed(2)} %)'
        : 'Noch zu wenig Daten';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Vermögensverlauf',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enough ? color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              SegmentedButton<_Range>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  for (final r in _Range.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: enough
                ? Semantics(
                    label:
                        'Vermögensverlauf, ${_range.label}: $summary, aktuell ${CurrencyFormatter.format(last)}',
                    child: ExcludeSemantics(
                      child: _Line(points: points, color: color),
                    ),
                  )
                : Center(
                    child: Text(
                      'Der Verlauf füllt sich, solange die App läuft und wenn du handelst.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final List<NetWorthPoint> points;
  final Color color;
  const _Line({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    final values = [for (final p in points) p.value];
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * 0.12 + 1;
    final start = values.first;
    final t0 = points.first.time.millisecondsSinceEpoch.toDouble();
    final spots = [
      for (final p in points)
        FlSpot(p.time.millisecondsSinceEpoch.toDouble() - t0, p.value),
    ];
    final span = spots.last.x - spots.first.x;
    final dateFormat = span > Duration.millisecondsPerDay
        ? DateFormat('dd.MM. HH:mm')
        : DateFormat('HH:mm');

    return LineChart(
      LineChartData(
        minY: lo - pad,
        maxY: hi + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: start,
              color: AppColors.textMuted.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${CurrencyFormatter.format(t.y)}\n'
                  '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch((t.x + t0).toInt()))}',
                  TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
