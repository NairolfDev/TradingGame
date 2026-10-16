import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../logic/live_market_data_service.dart';

enum ChartMode { line, candle }

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
}

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
  ChartMode _chartMode = ChartMode.line;
  bool _showSMA = true;
  double? _touchedPrice;
  List<double>? _liveFetchedSeries;

  final List<String> _timeframes = ['1D', '1W', '1M', '1Y', '3Y', 'ALL'];

  @override
  void initState() {
    super.initState();
    _loadLiveSeries();
  }

  Future<void> _loadLiveSeries() async {
    final series = await LiveMarketDataService().fetchHistoricalSeries(widget.asset, _timeframe);
    if (mounted && series != null && series.length >= 4) {
      setState(() {
        _liveFetchedSeries = series;
      });
    }
  }

  List<double> _generateSeriesForTimeframe() {
    final basePrice = widget.asset.currentPrice;
    final history = widget.asset.priceHistory;
    final vol = widget.asset.volatility.clamp(0.005, 0.05);

    switch (_timeframe) {
      case '1D':
        if (history.length >= 10) return history;
        return _simulatePath(basePrice, 15, vol * 0.4);
      case '1W':
        return _simulatePath(basePrice * 0.98, 20, vol * 0.6);
      case '1M':
        return _simulatePath(basePrice * 0.94, 30, vol * 0.9);
      case '1Y':
        return _simulatePath(basePrice * 0.82, 40, vol * 1.4);
      case '3Y':
        return _simulatePath(basePrice * 0.70, 48, vol * 1.6);
      case 'ALL':
        return _simulatePath(basePrice * 0.55, 60, vol * 2.0);
      default:
        return history;
    }
  }

  List<double> _simulatePath(double startPrice, int count, double spread) {
    final rand = Random(widget.asset.id.hashCode + _timeframe.hashCode);
    final points = <double>[startPrice];
    double current = startPrice;

    for (int i = 1; i < count - 1; i++) {
      final change = (rand.nextDouble() - 0.48) * spread * current;
      current = (current + change).clamp(startPrice * 0.3, startPrice * 3.0);
      points.add(double.parse(current.toStringAsFixed(2)));
    }
    points.add(widget.asset.currentPrice);
    return points;
  }

  List<CandleData> _generateCandles(List<double> series) {
    final candles = <CandleData>[];
    final rand = Random(widget.asset.id.hashCode + 99);

    for (int i = 0; i < series.length; i++) {
      final close = series[i];
      final prev = i > 0 ? series[i - 1] : close * 0.99;
      final open = prev;
      final variance = (close * 0.008) * (rand.nextDouble() + 0.5);
      final high = max(open, close) + variance;
      final low = max(0.1, min(open, close) - variance);
      final vol = (rand.nextDouble() * 50000 + 10000);

      candles.add(CandleData(
        open: open,
        high: high,
        low: low,
        close: close,
        volume: vol,
      ));
    }
    return candles;
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
    final series = _liveFetchedSeries ?? _generateSeriesForTimeframe();
    final candles = _generateCandles(series);
    final minVal = series.reduce(min);
    final maxVal = series.reduce(max);
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('FOKUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          )),
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
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(
                          icon: Icons.trending_up,
                          isSelected: _chartMode == ChartMode.line,
                          onTap: () => setState(() => _chartMode = ChartMode.line),
                        ),
                        _buildModeButton(
                          icon: Icons.candlestick_chart,
                          isSelected: _chartMode == ChartMode.candle,
                          onTap: () => setState(() => _chartMode = ChartMode.candle),
                        ),
                      ],
                    ),
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
            child: _chartMode == ChartMode.line
                ? _buildLineChart(series, minVal, maxVal, diff, chartColor)
                : _buildCandlestickChart(candles, minVal, maxVal, diff),
          ),
        ),

        // Bottom Timeframe Selector: 1D, 1W, 1M, 1Y, ALL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _timeframes.map((tf) {
              final isSelected = _timeframe == tf;
              return InkWell(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.black : AppColors.textSecondary,
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
        isCurved: true,
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
          isCurved: true,
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
          getDrawingHorizontalLine: (value) => const FlLine(
            color: AppColors.cardBorder,
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                return Text(
                  CurrencyFormatter.formatCompact(value),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minVal - (diff * 0.08),
        maxY: maxVal + (diff * 0.08),
        lineBarsData: lineBars,
      ),
    );
  }

  Widget _buildCandlestickChart(
    List<CandleData> candles,
    double minVal,
    double maxVal,
    double diff,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final candleWidth = max(4.0, (constraints.maxWidth / candles.length) - 3.0);
        final height = constraints.maxHeight;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: candles.map((c) {
            final isBull = c.isBullish;
            final candleColor = isBull ? AppColors.profit : AppColors.loss;
            final range = diff > 0 ? diff : 1.0;

            final bodyTop = height - ((max(c.open, c.close) - minVal) / range) * height;
            final bodyBottom = height - ((min(c.open, c.close) - minVal) / range) * height;
            final wickTop = height - ((c.high - minVal) / range) * height;
            final wickBottom = height - ((c.low - minVal) / range) * height;

            final bodyHeight = max(2.0, (bodyBottom - bodyTop).abs());

            return Tooltip(
              message:
                  'Open: ${CurrencyFormatter.format(c.open)}\nHigh: ${CurrencyFormatter.format(c.high)}\nLow: ${CurrencyFormatter.format(c.low)}\nClose: ${CurrencyFormatter.format(c.close)}',
              child: SizedBox(
                width: candleWidth,
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Wick (Docht)
                    Positioned(
                      top: wickTop.clamp(0.0, height),
                      bottom: (height - wickBottom).clamp(0.0, height),
                      child: Container(
                        width: 1.5,
                        color: candleColor.withValues(alpha: 0.8),
                      ),
                    ),
                    // Candle Body (Kerzenkörper)
                    Positioned(
                      top: bodyTop.clamp(0.0, height),
                      height: bodyHeight,
                      child: Container(
                        width: candleWidth,
                        decoration: BoxDecoration(
                          color: candleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
