import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../logic/live_market_data_service.dart';

class InteractiveBrokerChart extends StatefulWidget {
  final Asset asset;
  final bool isPositive;
  final ValueChanged<double?>? onScrubPrice;

  const InteractiveBrokerChart({
    super.key,
    required this.asset,
    required this.isPositive,
    this.onScrubPrice,
  });

  @override
  State<InteractiveBrokerChart> createState() => _InteractiveBrokerChartState();
}

class _InteractiveBrokerChartState extends State<InteractiveBrokerChart> {
  String _timeframe = '1D'; // 1D, 1W, 1M, 1Y, 3Y, ALL
  bool _showSMA = true;
  double? _touchedPrice;
  List<double>? _liveFetchedSeries;

  final List<String> _timeframes = ['1D', '1W', '1M', '1Y', '3Y', 'ALL'];

  @override
  void initState() {
    super.initState();
    _loadLiveSeries();
  }

  bool _isLoading = true;
  int _requestId = 0;

  @override
  void didUpdateWidget(covariant InteractiveBrokerChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _liveFetchedSeries = null;
      _touchedPrice = null;
      _loadLiveSeries();
    }
  }

  Future<void> _loadLiveSeries() async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    final series = await LiveMarketDataService().fetchHistoricalSeries(
      widget.asset,
      _timeframe,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _liveFetchedSeries = series?.where((v) => v.isFinite && v > 0).toList();
      _isLoading = false;
    });
  }

  List<FlSpot> _computeSMA(List<double> series, int period) {
    final spots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      if (i < period - 1) {
        spots.add(FlSpot(i.toDouble(), series[i]));
      } else {
        double sum = 0.0;
        for (int j = 0; j < period; j++) {
          sum += series[i - j];
        }
        spots.add(FlSpot(i.toDouble(), sum / period));
      }
    }
    return spots;
  }

  /// Timeframes that returned no data; shown disabled so nobody waits on them.
  final Set<String> _emptyTimeframes = {};

  void _selectTimeframe(String tf) {
    setState(() {
      _timeframe = tf;
      _touchedPrice = null;
      _liveFetchedSeries = null;
    });
    widget.onScrubPrice?.call(null);
    _loadLiveSeries();
  }

  @override
  Widget build(BuildContext context) {
    final series = _liveFetchedSeries ?? const <double>[];
    if (!_isLoading && series.length < 2) _emptyTimeframes.add(_timeframe);
    final minVal = series.isEmpty ? 0.0 : series.reduce(min);
    final maxVal = series.isEmpty ? 0.0 : series.reduce(max);
    final diff = maxVal - minVal;
    final periodChange = series.length >= 2
        ? (series.last - series.first) / series.first
        : null;
    final chartColor = periodChange == null
        ? (widget.isPositive ? AppColors.profit : AppColors.loss)
        : (periodChange >= 0 ? AppColors.profit : AppColors.loss);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        _boundedHeight = constraints.hasBoundedHeight;
        return _buildBody(
          series,
          minVal,
          maxVal,
          diff,
          periodChange,
          chartColor,
          textScale,
        );
      },
    );
  }

  Widget _buildBody(
    List<double> series,
    double minVal,
    double maxVal,
    double diff,
    double? periodChange,
    Color chartColor,
    double textScale,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scrubbed or latest price + change over the selected period.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      CurrencyFormatter.format(
                        _touchedPrice ?? widget.asset.currentPrice,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (_touchedPrice != null)
                      _pill('Ausgewählter Punkt', AppColors.accent)
                    else if (periodChange != null)
                      _pill(
                        '${CurrencyFormatter.formatPercent(periodChange)} · ${_label(_timeframe)}',
                        chartColor,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showSMA ? Icons.auto_graph : Icons.show_chart,
                  color: _showSMA ? AppColors.gold : AppColors.textMuted,
                ),
                tooltip: _showSMA
                    ? 'Gleitenden Durchschnitt ausblenden'
                    : 'Gleitenden Durchschnitt (5 Punkte) einblenden',
                onPressed: () => setState(() => _showSMA = !_showSMA),
              ),
            ],
          ),
        ),

        _canvasBox(
          height: 200 * textScale,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 16, 8),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : series.length < 2
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.show_chart,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keine EUR-Kursdaten für ${_label(_timeframe)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verläufe gibt es nur ohne Währungsumrechnung – '
                            'wir zeichnen keine erfundenen Kurven.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _emptyTimeframes.remove(_timeframe);
                              _loadLiveSeries();
                            },
                            child: const Text('Erneut laden'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Semantics(
                    label:
                        'Kursverlauf ${_label(_timeframe)}: von '
                        '${CurrencyFormatter.format(series.first)} auf '
                        '${CurrencyFormatter.format(series.last)}, '
                        'Tief ${CurrencyFormatter.format(minVal)}, '
                        'Hoch ${CurrencyFormatter.format(maxVal)}',
                    child: ExcludeSemantics(
                      child: _buildLineChart(
                        series,
                        minVal,
                        maxVal,
                        diff,
                        chartColor,
                      ),
                    ),
                  ),
          ),
        ),

        // Data transparency: where the curve comes from.
        if (series.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              'Quelle: Yahoo Finance · ${series.length} Kurspunkte in EUR · '
              'Tief ${CurrencyFormatter.format(minVal)} · '
              'Hoch ${CurrencyFormatter.format(maxVal)}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.cardBorder, width: 0.8),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tf in _timeframes)
                  _timeframeChip(
                    tf,
                    selected: _timeframe == tf,
                    empty: _emptyTimeframes.contains(tf) && _timeframe != tf,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fills the parent when it has a fixed height, otherwise a fixed canvas.
  Widget _canvasBox({required double height, required Widget child}) =>
      _boundedHeight
      ? Expanded(child: child)
      : SizedBox(height: height, child: child);

  bool _boundedHeight = false;

  /// Enough decimals that neighbouring ticks never show the same number.
  static String _axisLabel(double value, double range) {
    if (value.abs() >= 10000) return CurrencyFormatter.formatCompact(value);
    final decimals = range >= 30 ? 0 : (range >= 0.3 ? 2 : 4);
    return '€${value.toStringAsFixed(decimals)}';
  }

  static String _label(String tf) => switch (tf) {
    '1D' => '1 Tag',
    '1W' => '1 Woche',
    '1M' => '1 Monat',
    '1Y' => '1 Jahr',
    '3Y' => '3 Jahre',
    _ => 'Gesamt',
  };

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _timeframeChip(
    String tf, {
    required bool selected,
    required bool empty,
  }) {
    final color = selected
        ? AppColors.primary
        : empty
        ? AppColors.textMuted.withValues(alpha: 0.5)
        : AppColors.textSecondary;
    return Tooltip(
      message: empty ? '${_label(tf)}: keine Daten' : _label(tf),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !empty,
        label: 'Zeitraum ${_label(tf)}${empty ? ', keine Daten' : ''}',
        child: InkWell(
          onTap: empty || selected ? null : () => _selectTimeframe(tf),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tf == 'ALL' ? 'Max' : tf,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: color,
                decoration: empty ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(
    List<double> series,
    double minVal,
    double maxVal,
    double diff,
    Color color,
  ) {
    final spots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i]));
    }

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: false,
        curveSmoothness: 0.22,
        color: color,
        barWidth: 2.8,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ];

    if (_showSMA && series.length >= 5) {
      final smaSpots = _computeSMA(series, 5);
      lineBars.add(
        LineChartBarData(
          spots: smaSpots,
          isCurved: false,
          curveSmoothness: 0.3,
          color: AppColors.gold,
          barWidth: 1.5,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
            tooltipBorder: BorderSide(color: AppColors.cardBorder),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  CurrencyFormatter.format(spot.y),
                  TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (event, touchResponse) {
            if (touchResponse?.lineBarSpots != null &&
                touchResponse!.lineBarSpots!.isNotEmpty) {
              final spot = touchResponse.lineBarSpots!.first;
              setState(() {
                _touchedPrice = spot.y;
              });
              widget.onScrubPrice?.call(spot.y);
            } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
              setState(() {
                _touchedPrice = null;
              });
              widget.onScrubPrice?.call(null);
            }
          },
          handleBuiltInTouches: true,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: diff > 0 ? diff / 3 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.cardBorder, strokeWidth: 0.8),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 64,
              interval: diff > 0 ? diff / 3 : null,
              getTitlesWidget: (value, meta) {
                // Edge labels collide with the regular ticks; skip them.
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _axisLabel(value, diff),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minVal - (diff * 0.08),
        maxY: maxVal + (diff * 0.08),
        lineBarsData: lineBars,
      ),
    );
  }
}
