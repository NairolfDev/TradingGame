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

  @override
  Widget build(BuildContext context) {
    final series = _liveFetchedSeries ?? const <double>[];
    final minVal = series.isEmpty ? 0.0 : series.reduce(min);
    final maxVal = series.isEmpty ? 0.0 : series.reduce(max);
    final diff = maxVal - minVal;
    final chartColor = widget.isPositive ? AppColors.profit : AppColors.loss;

    return Column(
      children: [
        // Top Toolbar: Chart Type & Indicators & Scrubber Display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Display touched price or latest price
              Row(
                children: [
                  Text(
                    _touchedPrice != null
                        ? CurrencyFormatter.format(_touchedPrice!)
                        : CurrencyFormatter.format(widget.asset.currentPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_touchedPrice != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FOKUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Toggle Chart Mode (Line vs Candlestick) & SMA
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showSMA ? Icons.auto_graph : Icons.show_chart,
                      size: 20,
                      color: _showSMA ? AppColors.gold : AppColors.textMuted,
                    ),
                    tooltip: 'Gleitender Durchschnitt (SMA 5)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _showSMA = !_showSMA;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Main Chart Canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 10),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : series.length < 2
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.show_chart,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        const Text('Keine Kursdaten für diesen Zeitraum'),
                        TextButton(
                          onPressed: _loadLiveSeries,
                          child: const Text('Erneut laden'),
                        ),
                      ],
                    ),
                  )
                : _buildLineChart(series, minVal, maxVal, diff, chartColor),
          ),
        ),

        // Bottom Timeframe Selector: 1D, 1W, 1M, 1Y, ALL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.cardBorder, width: 0.8),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeframes.map((tf) {
                final isSelected = _timeframe == tf;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Zeitraum $tf',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _timeframe = tf;
                        _touchedPrice = null;
                        _liveFetchedSeries = null;
                      });
                      widget.onScrubPrice?.call(null);
                      _loadLiveSeries();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 1.2)
                            : null,
                      ),
                      child: Text(
                        tf,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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
            tooltipBorder: const BorderSide(color: AppColors.cardBorder),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  CurrencyFormatter.format(spot.y),
                  const TextStyle(
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
              const FlLine(color: AppColors.cardBorder, strokeWidth: 0.8),
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
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                return Text(
                  CurrencyFormatter.formatCompact(value),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
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
