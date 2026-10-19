import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../data/models/market_schedule.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/trading_fee_service.dart';
import '../../data/models/automation_order.dart';
import '../../data/models/position.dart';
import '../widgets/interactive_broker_chart.dart';
import '../widgets/order_routing_dialog.dart';
import '../widgets/order_book_widget.dart';
import '../widgets/order_entry.dart';
import '../widgets/price_alert_sheet.dart';
import '../../logic/live_market_data_service.dart';
import '../widgets/sell_order_sheet.dart';
import 'auth_screen.dart';

class TradeDetailScreen extends StatefulWidget {
  final Asset asset;

  const TradeDetailScreen({super.key, required this.asset});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  int _leverage = 1;
  bool _isShort = false;
  double _amount = 1.0;
  double? _cashFraction;
  double? _euroBudget;
  bool _submitting = false;

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
    _leverage = widget.asset.maxLeverage > 1
        ? 5.clamp(1, widget.asset.maxLeverage)
        : 1;
  }

  void _showSellDialog(
    BuildContext context,
    Position position,
    PortfolioProvider provider,
  ) {
    SellOrderSheet.show(
      context: context,
      position: position,
      provider: provider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    // Finde das aktuellste Asset aus dem Provider für Live-Ticker Updates
    final liveAsset = provider.assets.firstWhere(
      (a) => a.id == widget.asset.id,
      orElse: () => widget.asset,
    );

    if (_cashFraction != null || _euroBudget != null) {
      _amount = TradingFeeService.maximumBuyAmount(
        asset: liveAsset,
        cash: _cashFraction != null
            ? provider.cash * _cashFraction!
            : _euroBudget!,
        leverage: _leverage,
      );
    }

    final isOpen = provider.isAssetMarketOpen(liveAsset);
    final schedule = MarketSchedule.forAsset(liveAsset);
    final hasQuote =
        liveAsset.currentPrice.isFinite && liveAsset.currentPrice > 0;
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed:
                hasQuote &&
                    hasEnoughCash &&
                    _amount.isFinite &&
                    _amount > 0 &&
                    !_submitting &&
                    !provider.isLoading
                ? () {
                    final auth = context.read<AuthProvider>();
                    if (auth.currentUser == null || auth.currentUser!.isGuest) {
                      _showLoginRequiredDialog(context);
                    } else {
                      FocusScope.of(context).unfocus();
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
            child: Text(
              '${isOpen ? "Kauf prüfen" : "Vorab-Order prüfen"} · ${CurrencyFormatter.format(totalCost)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              liveAsset.symbol,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              liveAsset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: AppColors.textMuted,
            ),
            tooltip: 'Kursalarm setzen',
            onPressed: () {
              final auth = context.read<AuthProvider>();
              final yahoo = LiveMarketDataService.euroYahooSymbolFor(liveAsset);
              if (auth.currentUser == null || auth.currentUser!.isGuest) {
                _showLoginRequiredDialog(context);
              } else if (yahoo == null || yahoo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Für dieses Instrument gibt es keine Live-Kurse, daher keinen Kursalarm.',
                    ),
                  ),
                );
              } else {
                showPriceAlertSheet(
                  context,
                  asset: liveAsset,
                  yahooSymbol: yahoo,
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              liveAsset.isWatchlisted ? Icons.star : Icons.star_border,
              color: liveAsset.isWatchlisted
                  ? AppColors.accent
                  : AppColors.textMuted,
            ),
            tooltip: liveAsset.isWatchlisted
                ? 'Aus Watchlist entfernen'
                : 'Zu Watchlist hinzufügen',
            onPressed: () {
              provider.toggleWatchlist(liveAsset);
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isOpen ? AppColors.profit : AppColors.loss).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOpen ? AppColors.profit : AppColors.loss,
                width: 0.8,
              ),
            ),
            child: Semantics(
              label: isOpen ? 'Börse offen' : 'Börse geschlossen',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: isOpen ? AppColors.profit : AppColors.loss,
                  ),
                  // With large system text the label would not fit next to the
                  // two action buttons; the dot alone keeps the state visible.
                  if (MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? 'Börse Offen' : 'Geschlossen',
                      style: TextStyle(
                        color: isOpen ? AppColors.profit : AppColors.loss,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      // Not a lazy ListView: the order form must exist for focus/ensureVisible.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preis & 24h PnL Banner
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.quoteStatus(liveAsset),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      hasQuote
                          ? CurrencyFormatter.format(liveAsset.currentPrice)
                          : 'Kein Kurs',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (isPos ? AppColors.profit : AppColors.loss)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasQuote
                        ? '${CurrencyFormatter.formatPercent(liveAsset.change24hPercent)} (24h)'
                        : '—',
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

            // Interaktiver Profi-Broker Chart (1D, 1W, 1M, 1Y, ALL, Kerzen & Indikatoren)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: InteractiveBrokerChart(
                asset: liveAsset,
                isPositive: isPos,
              ),
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
                      : AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOpen ? Icons.info_outline : Icons.schedule,
                    color: isOpen ? AppColors.accent : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.region.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isOpen
                              ? 'Sofortige Ausführung zum angezeigten Kursstand.'
                              : 'Markt aktuell geschlossen. Deine Kauforder wird als Vorab-Order gespeichert und bei Öffnung ausgeführt!',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOpen
                                ? AppColors.textSecondary
                                : AppColors.warning,
                          ),
                        ),
                        if (!isOpen)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              schedule.getNextOpenTimeString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
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
                  '24h Hoch',
                  CurrencyFormatter.formatOrDash(liveAsset.dailyHigh),
                ),
                const SizedBox(width: 8),
                _buildStatTile(
                  '24h Tief',
                  CurrencyFormatter.formatOrDash(liveAsset.dailyLow),
                ),
                const SizedBox(width: 8),
                if (liveAsset.couponRate != null)
                  _buildStatTile(
                    'Zinskupon',
                    '${(liveAsset.couponRate! * 100).toStringAsFixed(1)}% p.a.',
                  )
                else
                  _buildStatTile(
                    'Volatilität',
                    liveAsset.volatility > 0
                        ? '${(liveAsset.volatility * 100).toInt()}%'
                        : '–',
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Falls bereits Positionen gehalten werden: Depotbestand-Widget
            Builder(
              builder: (context) {
                final existingPositions = provider.positions
                    .where(
                      (p) =>
                          p.assetId == liveAsset.id ||
                          p.symbol == liveAsset.symbol,
                    )
                    .toList();
                if (existingPositions.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pie_chart,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DEIN DEPOTBESTAND (${existingPositions.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...existingPositions.map((p) {
                            final isP = p.unrealizedPnL >= 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${CurrencyFormatter.formatAmount(p.amount)} Stk.${p.isLeveraged ? " (${p.leverage}x ${p.isShort ? "Short" : "Long"})" : ""}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Ø Kauf: ${CurrencyFormatter.formatPrice(p.averageBuyPrice)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(
                                          p.currentValue,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${isP ? "+" : ""}${CurrencyFormatter.format(p.unrealizedPnL)} (${CurrencyFormatter.formatPercent(p.unrealizedPnLPercent)})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isP
                                              ? AppColors.profit
                                              : AppColors.loss,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _showSellDialog(context, p, provider),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.loss
                                          .withValues(alpha: 0.18),
                                      foregroundColor: AppColors.loss,
                                      side: BorderSide(color: AppColors.loss),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Verkaufen',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Order Terminal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Bargeld: ${CurrencyFormatter.format(provider.cash)}',
                        style: TextStyle(
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
                              child: Text(
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
                              child: Text(
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
                        Text(
                          'Hebelwirkung (Leverage):',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
                    Builder(
                      builder: (context) {
                        // Up to 100x every step; beyond that fixed stops so
                        // 500x or 5000x stays reachable with one slider.
                        final max = liveAsset.maxLeverage;
                        final steps = max <= 100
                            ? [for (var i = 1; i <= max; i++) i]
                            : [
                                for (final v in const [
                                  1,
                                  2,
                                  3,
                                  5,
                                  10,
                                  20,
                                  25,
                                  50,
                                  75,
                                  100,
                                  200,
                                  250,
                                  500,
                                  1000,
                                  2000,
                                  2500,
                                  5000,
                                ])
                                  if (v <= max) v,
                                if (![
                                  1,
                                  2,
                                  3,
                                  5,
                                  10,
                                  20,
                                  25,
                                  50,
                                  75,
                                  100,
                                  200,
                                  250,
                                  500,
                                  1000,
                                  2000,
                                  2500,
                                  5000,
                                ].contains(max))
                                  max,
                              ];
                        var index = steps.indexWhere((v) => v >= _leverage);
                        if (index < 0) index = steps.length - 1;
                        return Slider(
                          value: index.toDouble(),
                          min: 0,
                          max: (steps.length - 1).toDouble(),
                          divisions: steps.length > 1 ? steps.length - 1 : 1,
                          label: '${steps[index]}x',
                          activeColor: AppColors.cfd,
                          onChanged: (val) {
                            setState(() => _leverage = steps[val.round()]);
                          },
                        );
                      },
                    ),
                    if (_leverage > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.loss.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 14,
                              color: AppColors.loss,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Geschätzter Liquidationspreis: ${CurrencyFormatter.format(estLiquidationPrice)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.loss,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  OrderEntry(
                    amount: _amount,
                    fraction: _cashFraction,
                    enabled: hasQuote && !_submitting && !provider.isLoading,
                    amountForEuros: (euros) =>
                        TradingFeeService.maximumBuyAmount(
                          asset: liveAsset,
                          cash: euros,
                          leverage: _leverage,
                        ),
                    eurosForAmount: (amount) =>
                        TradingFeeService.calculateBuyFee(
                          asset: liveAsset,
                          amount: amount,
                          leverage: _leverage,
                        ).totalCashRequired,
                    amountForFraction: (fraction) =>
                        TradingFeeService.maximumBuyAmount(
                          asset: liveAsset,
                          cash: provider.cash * fraction,
                          leverage: _leverage,
                        ),
                    onChanged: (amount, fraction, euros) => setState(() {
                      _amount = amount;
                      _cashFraction = fraction;
                      _euroBudget = euros;
                    }),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 10),

                  _buildSheetRow(
                    'Positionswert',
                    CurrencyFormatter.format(_amount * liveAsset.currentPrice),
                  ),
                  _buildSheetRow(
                    'Einsatz / Margin',
                    CurrencyFormatter.format(feeBreakdown.assetCost),
                  ),
                  _buildSheetRow(
                    'Gebühren',
                    CurrencyFormatter.format(feeBreakdown.transactionFee),
                  ),
                  Text(
                    feeBreakdown.feeDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(),
                  _buildSheetRow(
                    'Gesamt inkl. Gebühren',
                    CurrencyFormatter.format(totalCost),
                    isBold: true,
                  ),
                  if (!hasEnoughCash)
                    Text(
                      'Nicht genügend Cash.',
                      style: TextStyle(color: AppColors.loss),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OrderBookWidget(asset: liveAsset),
            const SizedBox(height: 16),
            _buildAutomationBotSection(context, liveAsset, provider),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationBotSection(
    BuildContext context,
    Asset asset,
    PortfolioProvider provider,
  ) {
    final activeOrdersForAsset = provider.activeAutomationOrders
        .where((o) => o.assetId == asset.id || o.symbol == asset.symbol)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Limit-Orders & Bot-Trading',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${provider.activeAutomationOrders.length} / ${provider.unlockedAutomationSlotsCount} Slots',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Automatisiere deine Ein- und Ausstiege. Kaufe bei Marktrücksetzern (Buy-At) oder sichere Gewinne automatisch (Sell-At).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Aktive Orders für dieses Asset
          if (activeOrdersForAsset.isNotEmpty) ...[
            Text(
              'Aktive Bot-Orders für dieses Instrument:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...activeOrdersForAsset.map((order) {
              final isBuy = order.orderType == AutomationOrderType.buyLimit;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 14,
                          color: isBuy
                              ? AppColors.profitGreen
                              : AppColors.lossRed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${order.orderType.displayName}: ${CurrencyFormatter.formatPrice(order.targetPrice)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${CurrencyFormatter.formatAmount(order.amount)} Stk.)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.lossRed,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        provider.cancelAutomationOrder(order.id);
                      },
                      child: const Text(
                        'Stornieren',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Buttons: Neue Order & Slot freischalten
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Limit-Order setzen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onPrimary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _showCreateLimitOrderDialog(context, asset, provider),
                ),
              ),
              if (provider.nextAutomationSlotCost != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.upgrade, size: 16),
                  label: Text(
                    '+Slot (${CurrencyFormatter.format(provider.nextAutomationSlotCost!)})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final success = await provider.unlockAutomationSlot();
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Nicht genügend Barmittel für diesen Bot-Slot!',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateLimitOrderDialog(
    BuildContext context,
    Asset asset,
    PortfolioProvider provider,
  ) {
    if (provider.activeAutomationOrders.length >=
        provider.unlockedAutomationSlotsCount) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Kein freier Bot-Slot'),
          content: Text(
            provider.nextAutomationSlotCost != null
                ? 'Alle ${provider.unlockedAutomationSlotsCount} Slots sind belegt. Schalte Slot ${provider.unlockedAutomationSlotsCount + 1} für ${CurrencyFormatter.format(provider.nextAutomationSlotCost!)} frei!'
                : 'Du hast bereits alle 5 Bot-Slots belegt!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
            if (provider.nextAutomationSlotCost != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await provider.unlockAutomationSlot();
                },
                child: const Text('Slot freischalten'),
              ),
          ],
        ),
      );
      return;
    }

    AutomationOrderType selectedType = AutomationOrderType.buyLimit;
    double targetPrice = double.parse(
      (asset.currentPrice * 0.96).toStringAsFixed(
        asset.currentPrice > 500 ? 2 : 4,
      ),
    );
    double orderAmount = _amount;

    final targetPriceController = TextEditingController(
      text: targetPrice.toString(),
    );
    final orderAmountController = TextEditingController(
      text: orderAmount.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Neue Limit-Order (Bot)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<AutomationOrderType>(
                  segments: const [
                    ButtonSegment(
                      value: AutomationOrderType.buyLimit,
                      label: Text('Buy-At', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: AutomationOrderType.takeProfit,
                      label: Text(
                        'Take-Profit',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ButtonSegment(
                      value: AutomationOrderType.stopLoss,
                      label: Text('Stop-Loss', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) {
                    setModalState(() {
                      selectedType = val.first;
                      if (selectedType == AutomationOrderType.buyLimit) {
                        targetPrice = double.parse(
                          (asset.currentPrice * 0.95).toStringAsFixed(
                            asset.currentPrice > 500 ? 2 : 4,
                          ),
                        );
                      } else if (selectedType ==
                          AutomationOrderType.takeProfit) {
                        targetPrice = double.parse(
                          (asset.currentPrice * 1.08).toStringAsFixed(
                            asset.currentPrice > 500 ? 2 : 4,
                          ),
                        );
                      } else {
                        targetPrice = double.parse(
                          (asset.currentPrice * 0.92).toStringAsFixed(
                            asset.currentPrice > 500 ? 2 : 4,
                          ),
                        );
                      }
                      targetPriceController.text = targetPrice.toString();
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Zielkurs / Auslösepreis (€)',
                    suffixText: '€',
                    helperText:
                        'Aktueller Marktpreis: ${CurrencyFormatter.formatPrice(asset.currentPrice)}',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                  ),
                  onChanged: (v) {
                    targetPrice = double.tryParse(v) ?? targetPrice;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Menge (Stückzahl)',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                  ),
                  onChanged: (v) {
                    orderAmount = double.tryParse(v) ?? orderAmount;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (targetPrice <= 0 || orderAmount <= 0) return;
                      Navigator.pop(ctx);
                      await provider.placeAutomationOrder(
                        asset: asset,
                        orderType: selectedType,
                        targetPrice: targetPrice,
                        amount: orderAmount,
                      );
                    },
                    child: const Text(
                      'Limit-Order scharf stellen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
          side: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Anmelden erforderlich',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        scrollable: true,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Weiter nur zusehen',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
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
    final cashFraction = _cashFraction;
    final orderAmount = _amount;
    final euroBudget = _euroBudget;
    final leverage = _leverage;
    final isShort = _isShort;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kauf prüfen: ${asset.symbol}',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(asset.name),
              const SizedBox(height: 12),
              Text(provider.quoteStatus(asset)),
              Text(
                isOpen
                    ? 'Ausführung zum verfügbaren Kursstand.'
                    : 'Vorab-Order: Ausführung nach Börsenöffnung.',
              ),
              if (!isOpen)
                Text(
                  MarketSchedule.forAsset(asset).nextOpeningLine(),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 16),
              _buildSheetRow(
                'Voraussichtliche Menge',
                '${CurrencyFormatter.formatAmount(orderAmount)} Stück',
              ),
              if (cashFraction != null)
                Text(
                  '${(cashFraction * 100).round()}% des bei Ausführung verfügbaren Cash inkl. Gebühren',
                ),
              _buildSheetRow(
                'Kurs (ca.)',
                CurrencyFormatter.format(asset.currentPrice),
              ),
              if (leverage > 1)
                _buildSheetRow(
                  'Hebel',
                  '${leverage}x ${isShort ? "SHORT" : "LONG"}',
                ),
              _buildSheetRow(
                'Einsatz / Margin',
                CurrencyFormatter.format(feeBreakdown.assetCost),
              ),
              _buildSheetRow(
                'Gebühren',
                CurrencyFormatter.format(feeBreakdown.transactionFee),
              ),
              const Divider(),
              _buildSheetRow(
                'Gesamt inkl. Gebühren',
                CurrencyFormatter.format(feeBreakdown.totalCashRequired),
                isBold: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Menge, Kurs und Gesamtabbuchung können sich bis zur Ausführung ändern.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _submitting = true);
                  final nav = Navigator.of(context);
                  final success = await OrderRoutingDialog.show(
                    context: context,
                    symbol: asset.symbol,
                    assetName: asset.name,
                    isBuy: true,
                    amount: orderAmount,
                    price: asset.currentPrice,
                    provider: provider,
                    onExecute: () => provider.executeBuy(
                      asset: asset,
                      amount: euroBudget == null
                          ? orderAmount
                          : TradingFeeService.maximumBuyAmount(
                              asset: provider.assets.firstWhere(
                                (a) => a.id == asset.id,
                                orElse: () => asset,
                              ),
                              cash: euroBudget,
                              leverage: leverage,
                            ),
                      cashFraction: cashFraction,
                      leverage: leverage,
                      isShort: isShort,
                    ),
                  );
                  if (!mounted) return;
                  setState(() => _submitting = false);
                  if (success) nav.pop();
                },
                child: Text(
                  isOpen
                      ? 'Kauf verbindlich bestätigen'
                      : 'Vorab-Order verbindlich platzieren',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
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
