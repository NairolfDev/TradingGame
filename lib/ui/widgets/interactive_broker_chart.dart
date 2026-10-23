import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  bool _isCandlestick = false;
  bool _showSMA = true;
  bool _showEMA = false;
  bool _showBollinger = false;

  double? _touchedPrice;
  int? _touchedCandleIndex;
  List<double>? _liveFetchedSeries;
  List<OhlcPoint>? _liveFetchedOhlc;

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
      _liveFetchedOhlc = null;
      _touchedPrice = null;
      _touchedCandleIndex = null;
      _loadLiveSeries();
    }
  }

  Future<void> _loadLiveSeries() async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    final seriesFuture = LiveMarketDataService().fetchHistoricalSeries(
      widget.asset,
      _timeframe,
    );
    final ohlcFuture = LiveMarketDataService().fetchHistoricalOhlc(
      widget.asset,
      _timeframe,
    );

    final results = await Future.wait([seriesFuture, ohlcFuture]);
    final series = results[0] as List<double>?;
    final ohlc = results[1] as List<OhlcPoint>?;

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _liveFetchedSeries = series?.where((v) => v.isFinite && v > 0).toList();
      _liveFetchedOhlc = ohlc;
      _isLoading = false;
    });
  }

  List<OhlcPoint> _getEffectiveOhlc(List<double> series) {
    if (_liveFetchedOhlc != null && _liveFetchedOhlc!.isNotEmpty) {
      return _liveFetchedOhlc!;
    }
    if (series.isEmpty) return const [];
    final times = LiveMarketDataService().historyTimes(
      widget.asset,
      _timeframe,
    );
    final list = <OhlcPoint>[];
    for (int i = 0; i < series.length; i++) {
      final curr = series[i];
      final prev = i > 0 ? series[i - 1] : curr;
      final o = prev;
      final c = curr;
      final h = max(o, c);
      final l = min(o, c);
      final t = (times != null && i < times.length)
          ? times[i]
          : DateTime.now().subtract(
              Duration(minutes: (series.length - i) * 5),
            );
      list.add(OhlcPoint(time: t, open: o, high: h, low: l, close: c));
    }
    return list;
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

  List<FlSpot> _computeEMA(List<double> series, int period) {
    if (series.isEmpty) return const [];
    final spots = <FlSpot>[];
    final k = 2.0 / (period + 1);
    double ema = series.first;
    spots.add(FlSpot(0, ema));
    for (int i = 1; i < series.length; i++) {
      ema = (series[i] * k) + (ema * (1.0 - k));
      spots.add(FlSpot(i.toDouble(), ema));
    }
    return spots;
  }

  ({List<FlSpot> upper, List<FlSpot> lower}) _computeBollinger(
    List<double> series,
    int period,
    double numStdDev,
  ) {
    final upper = <FlSpot>[];
    final lower = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      final start = max(0, i - period + 1);
      final window = series.sublist(start, i + 1);
      final mean = window.reduce((a, b) => a + b) / window.length;
      double sumSq = 0.0;
      for (final v in window) {
        sumSq += (v - mean) * (v - mean);
      }
      final stdDev = sqrt(sumSq / window.length);
      upper.add(FlSpot(i.toDouble(), mean + (numStdDev * stdDev)));
      lower.add(FlSpot(i.toDouble(), mean - (numStdDev * stdDev)));
    }
    return (upper: upper, lower: lower);
  }

  /// Timeframes that returned no data; shown disabled so nobody waits on them.
  final Set<String> _emptyTimeframes = {};

  void _selectTimeframe(String tf) {
    setState(() {
      _timeframe = tf;
      _touchedPrice = null;
      _touchedCandleIndex = null;
      _liveFetchedSeries = null;
      _liveFetchedOhlc = null;
    });
    widget.onScrubPrice?.call(null);
    _loadLiveSeries();
  }

  /// Permanent gap (no live source / proxy said 422): a short note instead of
  /// an empty chart with a retry that can never succeed.
  Widget _unavailableNote() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.show_chart, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kein EUR-Verlauf verfügbar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Für dieses Instrument gibt es keine währungsbereinigte '
                'Kursreihe. Wir zeichnen keine erfundenen Kurven.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && LiveMarketDataService.historyUnavailable(widget.asset)) {
      return _unavailableNote();
    }
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
    final ohlc = _getEffectiveOhlc(series);
    final candleMinVal = ohlc.isEmpty
        ? minVal
        : ohlc.map((p) => p.low).reduce(min);
    final candleMaxVal = ohlc.isEmpty
        ? maxVal
        : ohlc.map((p) => p.high).reduce(max);
    final candleDiff = candleMaxVal - candleMinVal;

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
                  _isCandlestick ? Icons.candlestick_chart : Icons.show_chart,
                  color: _isCandlestick
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                tooltip: _isCandlestick
                    ? 'Zu Linienchart wechseln'
                    : 'Zu Kerzenchart (OHLC) wechseln',
                onPressed: () =>
                    setState(() => _isCandlestick = !_isCandlestick),
              ),
              IconButton(
                icon: Icon(
                  _showSMA ? Icons.auto_graph : Icons.show_chart,
                  color: _showSMA ? AppColors.accent : AppColors.textMuted,
                ),
                tooltip: _showSMA
                    ? 'Gleitenden Durchschnitt ausblenden'
                    : 'Gleitenden Durchschnitt (5 Punkte) einblenden',
                onPressed: () => setState(() => _showSMA = !_showSMA),
              ),
            ],
          ),
        ),

        // Indicator & chart-type quick toggles
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _controlChip(
                  label: 'Linie',
                  icon: Icons.show_chart,
                  selected: !_isCandlestick,
                  onTap: () => setState(() => _isCandlestick = false),
                ),
                const SizedBox(width: 6),
                _controlChip(
                  label: 'Kerzen (OHLC)',
                  icon: Icons.candlestick_chart,
                  selected: _isCandlestick,
                  onTap: () => setState(() => _isCandlestick = true),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: AppColors.cardBorder),
                const SizedBox(width: 10),
                _indicatorChip(
                  label: 'SMA 5',
                  active: _showSMA,
                  color: AppColors.accent,
                  onTap: () => setState(() => _showSMA = !_showSMA),
                ),
                const SizedBox(width: 6),
                _indicatorChip(
                  label: 'EMA 20',
                  active: _showEMA,
                  color: Colors.amberAccent,
                  onTap: () => setState(() => _showEMA = !_showEMA),
                ),
                const SizedBox(width: 6),
                _indicatorChip(
                  label: 'Bollinger (20, 2σ)',
                  active: _showBollinger,
                  color: Colors.purpleAccent,
                  onTap: () => setState(() => _showBollinger = !_showBollinger),
                ),
              ],
            ),
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
                        'Tief ${CurrencyFormatter.format(_isCandlestick ? candleMinVal : minVal)}, '
                        'Hoch ${CurrencyFormatter.format(_isCandlestick ? candleMaxVal : maxVal)}',
                    child: ExcludeSemantics(
                      child: _isCandlestick
                          ? _buildCandlestickChart(
                              ohlc,
                              candleMinVal,
                              candleMaxVal,
                              candleDiff,
                              chartColor,
                            )
                          : _buildLineChart(
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
              'Tief ${CurrencyFormatter.format(_isCandlestick ? candleMinVal : minVal)} · '
              'Hoch ${CurrencyFormatter.format(_isCandlestick ? candleMaxVal : maxVal)}',
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

  Widget _controlChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorChip({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : AppColors.cardBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? color : AppColors.textMuted,
          ),
        ),
      ),
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

  /// Date axis under the curve: four labels, format by timeframe.
  SideTitles _dateTitles(int count) {
    final times = LiveMarketDataService().historyTimes(
      widget.asset,
      _timeframe,
    );
    if (times == null || times.length != count || count < 2) {
      return const SideTitles(showTitles: false);
    }
    final pattern = switch (_timeframe) {
      '1D' => 'HH:mm',
      '1W' => 'dd.MM.',
      '1M' => 'dd.MM.',
      _ => 'MM/yy',
    };
    final format = DateFormat(pattern);
    final step = ((count - 1) / 3).ceilToDouble();
    return SideTitles(
      showTitles: true,
      reservedSize: 24,
      interval: step,
      getTitlesWidget: (value, meta) {
        final i = value.round();
        if (i < 0 || i >= count || value != i.toDouble()) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            format.format(times[i]),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildCandlestickChart(
    List<OhlcPoint> points,
    double minVal,
    double maxVal,
    double diff,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const rightPadding = 64.0;
        final candleAreaWidth = max(10.0, width - rightPadding);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) => _handleCandleScrub(
            details.localPosition.dx,
            candleAreaWidth,
            points,
          ),
          onHorizontalDragUpdate: (details) => _handleCandleScrub(
            details.localPosition.dx,
            candleAreaWidth,
            points,
          ),
          onHorizontalDragEnd: (_) => _endCandleScrub(),
          onHorizontalDragCancel: () => _endCandleScrub(),
          onTapDown: (details) => _handleCandleScrub(
            details.localPosition.dx,
            candleAreaWidth,
            points,
          ),
          onTapUp: (_) => _endCandleScrub(),
          child: CustomPaint(
            size: Size(width, height),
            painter: CandlestickPainter(
              points: points,
              minPrice: minVal,
              maxPrice: maxVal,
              showSMA: _showSMA,
              showEMA: _showEMA,
              showBollinger: _showBollinger,
              rightPadding: rightPadding,
              touchedIndex: _touchedCandleIndex,
              timeframe: _timeframe,
              historyTimes: LiveMarketDataService().historyTimes(
                widget.asset,
                _timeframe,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCandleScrub(
    double dx,
    double candleAreaWidth,
    List<OhlcPoint> points,
  ) {
    if (points.isEmpty || candleAreaWidth <= 0) return;
    final clampedX = dx.clamp(0.0, candleAreaWidth);
    final idx = ((clampedX / candleAreaWidth) * points.length)
        .floor()
        .clamp(0, points.length - 1);
    final price = points[idx].close;
    setState(() {
      _touchedPrice = price;
      _touchedCandleIndex = idx;
    });
    widget.onScrubPrice?.call(price);
  }

  void _endCandleScrub() {
    setState(() {
      _touchedPrice = null;
      _touchedCandleIndex = null;
    });
    widget.onScrubPrice?.call(null);
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
          color: AppColors.accent,
          barWidth: 1.5,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (_showEMA && series.length >= 5) {
      final emaSpots = _computeEMA(series, 20);
      lineBars.add(
        LineChartBarData(
          spots: emaSpots,
          isCurved: false,
          curveSmoothness: 0.3,
          color: Colors.amberAccent,
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (_showBollinger && series.length >= 5) {
      final bb = _computeBollinger(series, 20, 2.0);
      lineBars.add(
        LineChartBarData(
          spots: bb.upper,
          isCurved: false,
          curveSmoothness: 0.3,
          color: Colors.purpleAccent.withValues(alpha: 0.7),
          barWidth: 1.2,
          dashArray: [3, 3],
          dotData: const FlDotData(show: false),
        ),
      );
      lineBars.add(
        LineChartBarData(
          spots: bb.lower,
          isCurved: false,
          curveSmoothness: 0.3,
          color: Colors.purpleAccent.withValues(alpha: 0.7),
          barWidth: 1.2,
          dashArray: [3, 3],
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
          bottomTitles: AxisTitles(sideTitles: _dateTitles(series.length)),
        ),
        borderData: FlBorderData(show: false),
        minY: minVal - (diff * 0.08),
        maxY: maxVal + (diff * 0.08),
        lineBarsData: lineBars,
      ),
    );
  }
}

class CandlestickPainter extends CustomPainter {
  final List<OhlcPoint> points;
  final double minPrice;
  final double maxPrice;
  final bool showSMA;
  final bool showEMA;
  final bool showBollinger;
  final double rightPadding;
  final int? touchedIndex;
  final String timeframe;
  final List<DateTime>? historyTimes;

  CandlestickPainter({
    required this.points,
    required this.minPrice,
    required this.maxPrice,
    required this.showSMA,
    required this.showEMA,
    required this.showBollinger,
    required this.rightPadding,
    this.touchedIndex,
    required this.timeframe,
    this.historyTimes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final width = size.width;
    final height = size.height;
    const bottomDateReserved = 22.0;
    final chartHeight = max(10.0, height - bottomDateReserved);
    final chartWidth = max(10.0, width - rightPadding);

    final range = maxPrice - minPrice;
    final padY = range > 0 ? range * 0.08 : 1.0;
    final effectiveMin = minPrice - padY;
    final effectiveMax = maxPrice + padY;
    final effectiveRange =
        effectiveMax - effectiveMin > 0 ? effectiveMax - effectiveMin : 1.0;

    double getY(double price) {
      final normalized = (price - effectiveMin) / effectiveRange;
      return chartHeight - (normalized * chartHeight);
    }

    // Grid lines & price labels
    final gridPaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 0.8;

    final textStyle = TextStyle(color: AppColors.textMuted, fontSize: 12);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const numGridLines = 3;
    final step = range > 0 ? range / numGridLines : 1.0;
    for (int i = 0; i <= numGridLines; i++) {
      final p = minPrice + (i * step);
      final y = getY(p);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      textPainter.text = TextSpan(
        text: _axisLabel(p, range),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartWidth + 6, y - (textPainter.height / 2)),
      );
    }

    // Date labels
    if (historyTimes != null &&
        historyTimes!.length == points.length &&
        points.length >= 2) {
      final pattern = switch (timeframe) {
        '1D' => 'HH:mm',
        '1W' => 'dd.MM.',
        '1M' => 'dd.MM.',
        _ => 'MM/yy',
      };
      final format = DateFormat(pattern);
      final stepIdx = ((points.length - 1) / 3).ceil();
      for (int i = 0; i < points.length; i += stepIdx) {
        final candleWidth = chartWidth / points.length;
        final cx = i * candleWidth + (candleWidth / 2);
        textPainter.text = TextSpan(
          text: format.format(historyTimes![i]),
          style: textStyle,
        );
        textPainter.layout();
        final textX = (cx - (textPainter.width / 2)).clamp(
          0.0,
          chartWidth - textPainter.width,
        );
        textPainter.paint(canvas, Offset(textX, chartHeight + 4));
      }
    }

    // Candles
    final wickPaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final bodyPaint = Paint()..style = PaintingStyle.fill;

    final count = points.length;
    final candleWidth = chartWidth / count;
    final bodyW = (candleWidth * 0.65).clamp(2.0, 14.0);

    for (int i = 0; i < count; i++) {
      final pt = points[i];
      final cx = i * candleWidth + (candleWidth / 2);
      final isGreen = pt.close >= pt.open;
      final color = isGreen ? AppColors.profit : AppColors.loss;

      // Wick
      wickPaint.color = color;
      canvas.drawLine(
        Offset(cx, getY(pt.high)),
        Offset(cx, getY(pt.low)),
        wickPaint,
      );

      // Body
      bodyPaint.color = color;
      final topY = getY(max(pt.open, pt.close));
      final botY = getY(min(pt.open, pt.close));
      final h = max(1.5, botY - topY);
      canvas.drawRect(
        Rect.fromLTWH(cx - (bodyW / 2), topY, bodyW, h),
        bodyPaint,
      );
    }

    // Indicators on Candlestick
    final closeSeries = [for (final p in points) p.close];

    // SMA 5
    if (showSMA && count >= 5) {
      final smaPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i < count; i++) {
        double val;
        if (i < 4) {
          val = closeSeries[i];
        } else {
          double sum = 0.0;
          for (int j = 0; j < 5; j++) {
            sum += closeSeries[i - j];
          }
          val = sum / 5;
        }
        final cx = i * candleWidth + (candleWidth / 2);
        final cy = getY(val);
        if (i == 0) {
          path.moveTo(cx, cy);
        } else {
          path.lineTo(cx, cy);
        }
      }
      canvas.drawPath(path, smaPaint);
    }

    // EMA 20
    if (showEMA && count >= 5) {
      final emaPaint = Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      final k = 2.0 / (20 + 1);
      double ema = closeSeries.first;
      for (int i = 0; i < count; i++) {
        if (i > 0) ema = (closeSeries[i] * k) + (ema * (1.0 - k));
        final cx = i * candleWidth + (candleWidth / 2);
        final cy = getY(ema);
        if (i == 0) {
          path.moveTo(cx, cy);
        } else {
          path.lineTo(cx, cy);
        }
      }
      canvas.drawPath(path, emaPaint);
    }

    // Bollinger (20, 2σ)
    if (showBollinger && count >= 5) {
      final bbPaint = Paint()
        ..color = Colors.purpleAccent.withValues(alpha: 0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final upperPath = Path();
      final lowerPath = Path();
      for (int i = 0; i < count; i++) {
        final start = max(0, i - 19);
        final window = closeSeries.sublist(start, i + 1);
        final mean = window.reduce((a, b) => a + b) / window.length;
        double sumSq = 0.0;
        for (final v in window) {
          sumSq += (v - mean) * (v - mean);
        }
        final stdDev = sqrt(sumSq / window.length);
        final upperVal = mean + (2.0 * stdDev);
        final lowerVal = mean - (2.0 * stdDev);
        final cx = i * candleWidth + (candleWidth / 2);
        final uY = getY(upperVal);
        final lY = getY(lowerVal);
        if (i == 0) {
          upperPath.moveTo(cx, uY);
          lowerPath.moveTo(cx, lY);
        } else {
          upperPath.lineTo(cx, uY);
          lowerPath.lineTo(cx, lY);
        }
      }
      canvas.drawPath(upperPath, bbPaint);
      canvas.drawPath(lowerPath, bbPaint);
    }

    // Scrub overlay
    if (touchedIndex != null && touchedIndex! >= 0 && touchedIndex! < count) {
      final p = points[touchedIndex!];
      final cx = touchedIndex! * candleWidth + (candleWidth / 2);
      final cy = getY(p.close);

      final scrubPaint = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(cx, 0), Offset(cx, chartHeight), scrubPaint);
      canvas.drawLine(Offset(0, cy), Offset(chartWidth, cy), scrubPaint);

      final dotFill = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 4.5, dotFill);

      final dotBorder = Paint()
        ..color = AppColors.surfaceElevated
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), 4.5, dotBorder);
    }
  }

  static String _axisLabel(double value, double range) {
    if (value.abs() >= 10000) return CurrencyFormatter.formatCompact(value);
    final decimals = range >= 30 ? 0 : (range >= 0.3 ? 2 : 4);
    return '€${value.toStringAsFixed(decimals)}';
  }

  @override
  bool shouldRepaint(covariant CandlestickPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minPrice != minPrice ||
        oldDelegate.maxPrice != maxPrice ||
        oldDelegate.showSMA != showSMA ||
        oldDelegate.showEMA != showEMA ||
        oldDelegate.showBollinger != showBollinger ||
        oldDelegate.touchedIndex != touchedIndex ||
        oldDelegate.timeframe != timeframe;
  }
}
