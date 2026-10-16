import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../data/models/market_schedule.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/trading_fee_service.dart';
import 'auth_screen.dart';

class TradeDetailScreen extends StatefulWidget {
  final Asset asset;

  const TradeDetailScreen({super.key, required this.asset});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  final TextEditingController _amountController = TextEditingController();
  int _leverage = 1;
  bool _isShort = false;
  double _amount = 1.0;

  @override
  void initState() {
    super.initState();
    // Intelligenter Initialwert je nach Asset-Preis
    if (widget.asset.currentPrice > 1000) {
      _amount = 0.1;
    } else if (widget.asset.currentPrice < 1) {
      _amount = 100.0;
    } else {
      _amount = 5.0;
    }
    _amountController.text = CurrencyFormatter.formatAmount(_amount);
    _leverage = widget.asset.maxLeverage > 1 ? 5 : 1;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setPercentageOfCash(double fraction, PortfolioProvider provider) {
    final availableCash = provider.cash * fraction;
    if (availableCash <= 0) return;

    final unitPrice = widget.asset.currentPrice / _leverage;
    if (unitPrice <= 0) return;

    double calculatedAmount = availableCash / unitPrice;
    if (widget.asset.currentPrice > 1000) {
      calculatedAmount = double.parse(calculatedAmount.toStringAsFixed(4));
    } else {
      calculatedAmount = double.parse(calculatedAmount.toStringAsFixed(2));
    }

    setState(() {
      _amount = calculatedAmount;
      _amountController.text = CurrencyFormatter.formatAmount(_amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    // Finde das aktuellste Asset aus dem Provider für Live-Ticker Updates
    final liveAsset = provider.assets.firstWhere(
      (a) => a.id == widget.asset.id,
      orElse: () => widget.asset,
    );

    final isOpen = provider.isAssetMarketOpen(liveAsset);
    final schedule = MarketSchedule.forAsset(liveAsset);
    final isPos = liveAsset.isPositive;
    final feeBreakdown = TradingFeeService.calculateBuyFee(
      asset: liveAsset,
      amount: _amount,
      leverage: _leverage,
    );
    final totalCost = feeBreakdown.totalCashRequired;
    final hasEnoughCash = provider.cash >= totalCost;

    // Vorab-Liquidation Berechnung bei Hebel
    double estLiquidationPrice = 0.0;
    if (_leverage > 1) {
      final maxLossFactor = 0.90 / _leverage;
      estLiquidationPrice = _isShort
          ? liveAsset.currentPrice * (1 + maxLossFactor)
          : liveAsset.currentPrice * (1 - maxLossFactor);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(liveAsset.symbol,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(liveAsset.name,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isOpen ? AppColors.profit : AppColors.loss)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOpen ? AppColors.profit : AppColors.loss,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: isOpen ? AppColors.profit : AppColors.loss,
                ),
                const SizedBox(width: 6),
                Text(
                  isOpen ? 'Börse Offen' : 'Geschlossen',
                  style: TextStyle(
                    color: isOpen ? AppColors.profit : AppColors.loss,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preis & 24h PnL Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktueller Kurs',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    CurrencyFormatter.format(liveAsset.currentPrice),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isPos ? AppColors.profit : AppColors.loss)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${CurrencyFormatter.formatPercent(liveAsset.change24hPercent)} (24h)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPos ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Interaktiver Kurschart mit fl_chart
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: _buildInteractiveChart(liveAsset, isPos),
          ),

          const SizedBox(height: 16),

          // Börsenöffnungszeiten Information Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOpen
                    ? AppColors.cardBorder
                    : AppColors.gold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOpen ? Icons.info_outline : Icons.schedule,
                  color: isOpen ? AppColors.accent : AppColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.region.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isOpen
                            ? 'Sofortige Ausführung zum Live-Marktpreis garantiert.'
                            : 'Markt aktuell geschlossen. Deine Kauforder wird als Vorab-Order gespeichert und bei Öffnung ausgeführt!',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOpen ? AppColors.textSecondary : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Key Stats Row
          Row(
            children: [
              _buildStatTile(
                  '24h Hoch', CurrencyFormatter.format(liveAsset.dailyHigh)),
              const SizedBox(width: 8),
              _buildStatTile(
                  '24h Tief', CurrencyFormatter.format(liveAsset.dailyLow)),
              const SizedBox(width: 8),
              if (liveAsset.couponRate != null)
                _buildStatTile('Zinskupon',
                    '${(liveAsset.couponRate! * 100).toStringAsFixed(1)}% p.a.')
              else
                _buildStatTile(
                    'Volatilität', '${(liveAsset.volatility * 100).toInt()}%'),
            ],
          ),

          const SizedBox(height: 20),

          // --- ORDER TERMINAL ---
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Terminal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Bargeld: ${CurrencyFormatter.format(provider.cash)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Falls Hebel-CFD: Long / Short Umschalter
                if (liveAsset.maxLeverage > 1) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isShort = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isShort
                                  ? AppColors.profit.withValues(alpha: 0.2)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isShort
                                    ? AppColors.profit
                                    : AppColors.cardBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'LONG (Steigend ↗)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.profit,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isShort = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isShort
                                  ? AppColors.loss.withValues(alpha: 0.2)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isShort
                                    ? AppColors.loss
                                    : AppColors.cardBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'SHORT (Fallend ↘)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.loss,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hebel Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hebelwirkung (Leverage):',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${_leverage}x',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cfd,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _leverage.toDouble(),
                    min: 1,
                    max: liveAsset.maxLeverage.toDouble(),
                    divisions: liveAsset.maxLeverage > 1
                        ? (liveAsset.maxLeverage - 1)
                        : 1,
                    activeColor: AppColors.cfd,
                    onChanged: (val) {
                      setState(() {
                        _leverage = val.toInt();
                      });
                    },
                  ),
                  if (_leverage > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.loss.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              size: 14, color: AppColors.loss),
                          const SizedBox(width: 6),
                          Text(
                            'Geschätzter Liquidationspreis: ${CurrencyFormatter.format(estLiquidationPrice)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.loss,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // Menge Eingabefeld
                const Text(
                  'Menge / Anteile',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    suffixText: liveAsset.symbol,
                    suffixStyle: const TextStyle(color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _amount = parsed;
                      });
                    }
                  },
                ),

                const SizedBox(height: 8),

                // Prozentuale Schnellbuttons (25%, 50%, 75%, 100% Cash)
                Row(
                  children: [
                    _buildPercentButton('25%', () => _setPercentageOfCash(0.25, provider)),
                    const SizedBox(width: 6),
                    _buildPercentButton('50%', () => _setPercentageOfCash(0.50, provider)),
                    const SizedBox(width: 6),
                    _buildPercentButton('75%', () => _setPercentageOfCash(0.75, provider)),
                    const SizedBox(width: 6),
                    _buildPercentButton('MAX', () => _setPercentageOfCash(1.0, provider)),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.cardBorder),
                const SizedBox(height: 10),

                // Order Übersicht mit detaillierten Transaktionsspesen
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Positionswert (Kurswert):',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            CurrencyFormatter.format(_amount * liveAsset.currentPrice),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_outlined,
                                  size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                feeBreakdown.feeDescription,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.gold),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(feeBreakdown.transactionFee),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.cardBorder, height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamter Cash-Bedarf:',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          Text(
                            CurrencyFormatter.format(feeBreakdown.totalCashRequired),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: hasEnoughCash
                                  ? AppColors.primary
                                  : AppColors.loss,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Haupt Button: Order prüfen & bestätigen
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: hasEnoughCash && _amount > 0
                        ? () {
                            final auth = context.read<AuthProvider>();
                            if (auth.currentUser == null || auth.currentUser!.isGuest) {
                              _showLoginRequiredDialog(context);
                            } else {
                              _showOrderConfirmationSheet(
                                context,
                                liveAsset,
                                provider,
                                feeBreakdown,
                                isOpen,
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOpen ? AppColors.primary : AppColors.gold,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isOpen ? Icons.assignment_outlined : Icons.schedule, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isOpen
                              ? 'ORDER PRÜFEN & KAUFEN (${CurrencyFormatter.format(feeBreakdown.totalCashRequired)})'
                              : 'VORAB-ORDER PRÜFEN (Bei Börsenöffnung)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart(Asset asset, bool isPos) {
    final history = asset.priceHistory;
    final minVal = history.reduce((a, b) => a < b ? a : b);
    final maxVal = history.reduce((a, b) => a > b ? a : b);
    final diff = maxVal - minVal;

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i]));
    }

    final color = isPos ? AppColors.profit : AppColors.loss;

    return LineChart(
      LineChartData(
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
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minVal - (diff * 0.1),
        maxY: maxVal + (diff * 0.1),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentButton(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text(
              '🔒 Anmelden erforderlich',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Im Börsenspiel kannst du alle Märkte, Charts und das Leaderboard frei beobachten ("Nur Schauen").',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            SizedBox(height: 10),
            Text(
              'Um eigene Wertpapiere zu kaufen, Positionen zu halten und dein Vermögen in Firebase zu sichern, melde dich bitte kostenlos an!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Weiter nur zusehen',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuthScreen(
                    onAuthenticated: () => Navigator.pop(context),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Jetzt Anmelden / Registrieren',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationSheet(
    BuildContext context,
    Asset asset,
    PortfolioProvider provider,
    OrderFeeBreakdown feeBreakdown,
    bool isOpen,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 VERBINDLICHE ORDERÜBERSICHT',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asset.name} (${asset.symbol})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Börsenstatus Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isOpen ? AppColors.profit : AppColors.gold)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isOpen ? AppColors.profit : AppColors.gold)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(isOpen ? Icons.bolt : Icons.schedule,
                      size: 18, color: isOpen ? AppColors.profit : AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOpen
                          ? 'Sofortige Orderausführung zum Live-Börsenkurs'
                          : 'Vorab-Kauforder: Börse geschlossen. Ausführung erfolgt automatisch bei Börsenöffnung!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppColors.profit : AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detaillierte Kostenaufstellung (Kostenausweis)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildSheetRow(
                      'Ordertyp:', isOpen ? 'Market Kauforder' : 'Vorab-Kauforder'),
                  const SizedBox(height: 8),
                  _buildSheetRow('Order-Menge:',
                      '${CurrencyFormatter.formatAmount(_amount)} Anteile'),
                  const SizedBox(height: 8),
                  _buildSheetRow('Ausführungskurs (ca.):',
                      CurrencyFormatter.format(asset.currentPrice)),
                  const SizedBox(height: 8),
                  if (_leverage > 1) ...[
                    _buildSheetRow('Hebelwirkung:',
                        '${_leverage}x ${_isShort ? "SHORT" : "LONG"}'),
                    const SizedBox(height: 8),
                  ],
                  _buildSheetRow('Kurswert der Anteile:',
                      CurrencyFormatter.format(_amount * asset.currentPrice)),
                  const SizedBox(height: 8),
                  _buildSheetRow(
                    'Transaktions- & Börsenspesen:',
                    CurrencyFormatter.format(feeBreakdown.transactionFee),
                    valueColor: AppColors.gold,
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  const SizedBox(height: 10),
                  _buildSheetRow(
                    'Gesamtabbuchung vom Cash:',
                    CurrencyFormatter.format(feeBreakdown.totalCashRequired),
                    isBold: true,
                    valueColor: AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  _buildSheetRow(
                    'Verbleibendes Barmittel danach:',
                    CurrencyFormatter.format(
                        provider.cash - feeBreakdown.totalCashRequired),
                    valueColor: AppColors.textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bestätigungs-Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final nav = Navigator.of(context);
                  final success = await provider.executeBuy(
                    asset: asset,
                    amount: _amount,
                    leverage: _leverage,
                    isShort: _isShort,
                  );
                  if (success && mounted) {
                    nav.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOpen ? AppColors.primary : AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isOpen ? 'KAUF JETZT VERBINDLICH BESTÄTIGEN' : 'VORAB-ORDER VERBINDLICH PLATZIEREN',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
