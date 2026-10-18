import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/pending_order_card.dart';
import '../widgets/portfolio_summary.dart';
import '../widgets/sell_order_sheet.dart';
import '../../data/models/position.dart';
import 'trade_detail_screen.dart';

class SimplisticDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const SimplisticDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<SimplisticDashboardScreen> createState() =>
      _SimplisticDashboardScreenState();
}

class _SimplisticDashboardScreenState extends State<SimplisticDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    final filteredPositions = provider.positions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.symbol.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'DEPOT (SIMPLISTIC)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => provider.setSimplisticMode(false),
            icon: Icon(Icons.tune, size: 16, color: AppColors.primary),
            label: Text(
              'Profi-Modus',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchLiveMarketQuotes();
          await provider.reloadLeaderboard();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            PortfolioSummary(portfolio: provider),

            const SizedBox(height: 16),

            // 2. OFFENE ORDERS
            if (provider.pendingOrders.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OFFENE ORDERS (${provider.pendingOrders.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (provider.isRealisticOrderDelay)
                    Text(
                      '⏱️ 5–15 Min. Routing',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...provider.pendingOrders.map(
                (order) => PendingOrderCard(
                  order: order,
                  onCancel: () => provider.cancelPendingOrder(order),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. SUCHE & POSITIONEN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'POSITIONEN (${provider.positions.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      widget.onNavigateTab(1), // Zu Märkten wechseln
                  child: Text(
                    'Alle Märkte',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Search Field
            TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Position filtern...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),

            // Positions List
            if (filteredPositions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                alignment: Alignment.center,
                child: Text(
                  'Keine Wertpapierpositionen vorhanden.\nGehe zu „Märkte“, um Aktien oder Krypto zu kaufen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              ...filteredPositions.map((pos) {
                final posPnL = pos.unrealizedPnL;
                final posProfit = posPnL >= 0;

                return InkWell(
                  onTap: () {
                    final asset = provider.assets.firstWhere(
                      (a) => a.id == pos.assetId || a.symbol == pos.symbol,
                      orElse: () => provider.assets.first,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TradeDetailScreen(asset: asset),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pos.symbol,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                pos.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${CurrencyFormatter.formatAmount(pos.amount)} Stk. @ ${CurrencyFormatter.formatPrice(pos.averageBuyPrice)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(pos.currentValue),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${posProfit ? "+" : ""}${CurrencyFormatter.format(posPnL)} (${CurrencyFormatter.formatPercent(pos.unrealizedPnLPercent)})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: posProfit
                                      ? AppColors.bullish
                                      : AppColors.bearish,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () =>
                              _showSellDialog(context, pos, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.loss.withValues(
                              alpha: 0.18,
                            ),
                            foregroundColor: AppColors.loss,
                            side: BorderSide(color: AppColors.loss, width: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
