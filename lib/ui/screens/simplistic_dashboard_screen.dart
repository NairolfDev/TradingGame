import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/pending_order_card.dart';
import '../widgets/order_routing_dialog.dart';
import '../../data/models/position.dart';
import 'trade_detail_screen.dart';

class SimplisticDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const SimplisticDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<SimplisticDashboardScreen> createState() => _SimplisticDashboardScreenState();
}

class _SimplisticDashboardScreenState extends State<SimplisticDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showSellDialog(
      BuildContext context, Position position, PortfolioProvider provider) {
    double amountToSell = position.amount;
    double sellFraction = 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final portionPnL = (amountToSell / position.amount) * position.unrealizedPnL;
            final isPnLPos = portionPnL >= 0;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Position Schließen: ${position.symbol}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF8B9CB2)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aktueller PnL: ${isPnLPos ? "+" : ""}${CurrencyFormatter.format(portionPnL)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPnLPos ? AppColors.bullish : AppColors.bearish,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Menge: ${CurrencyFormatter.formatAmount(amountToSell)} / ${CurrencyFormatter.formatAmount(position.amount)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8B9CB2)),
                  ),
                  Slider(
                    value: sellFraction,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: AppColors.loss,
                    inactiveColor: const Color(0xFF243247),
                    onChanged: (val) {
                      setModalState(() {
                        sellFraction = val;
                        amountToSell = position.amount * val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: sellFraction > 0 ? () async {
                        Navigator.pop(ctx);
                        await OrderRoutingDialog.show(
                          context: context,
                          symbol: position.symbol,
                          assetName: position.name,
                          isBuy: false,
                          amount: amountToSell,
                          price: position.currentPrice,
                          onExecute: () => provider.executeSell(
                            position: position,
                            sellAmount: amountToSell,
                            sellFraction: sellFraction,
                          ),
                        );
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loss,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verkauf Bestätigen',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    final netWorth = provider.netWorth;
    final totalPnL = provider.totalUnrealizedPnL;
    final isProfit = totalPnL >= 0;

    final filteredPositions = provider.positions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.symbol.toLowerCase().contains(q) || p.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111722),
        elevation: 0,
        title: const Text(
          'DEPOT (SIMPLISTIC)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => provider.setSimplisticMode(false),
            icon: const Icon(Icons.tune, size: 16, color: AppColors.primary),
            label: const Text(
              'Profi-Modus',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
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
          // 1. MINIMALIST BALANCE CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF243247)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GESAMTWERT DEPOT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF8B9CB2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(netWorth),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: isProfit ? AppColors.bullish : AppColors.bearish,
                      size: 20,
                    ),
                    Text(
                      '${isProfit ? "+" : ""}${CurrencyFormatter.format(totalPnL)} (${CurrencyFormatter.formatPercent(provider.unrealizedPnLPercent)})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isProfit ? AppColors.bullish : AppColors.bearish,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF243247), height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Freies Barmittel', style: TextStyle(fontSize: 11, color: Color(0xFF8B9CB2))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(provider.cash),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Investiert in Werte', style: TextStyle(fontSize: 11, color: Color(0xFF8B9CB2))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(provider.totalInvested),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. OFFENE ORDERS
          if (provider.pendingOrders.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OFFENE ORDERS (${provider.pendingOrders.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF8B9CB2),
                  ),
                ),
                if (provider.isRealisticOrderDelay)
                  const Text(
                    '⏱️ 5–15 Min. Routing',
                    style: TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.bold),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF8B9CB2),
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(1), // Zu Märkten wechseln
                child: const Text('Alle Märkte', style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Search Field
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Position filtern...',
              hintStyle: const TextStyle(color: Color(0xFF56677F), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF56677F)),
              filled: true,
              fillColor: const Color(0xFF161F2E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF243247)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF243247)),
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
              child: const Text(
                'Keine Wertpapierpositionen vorhanden.\nGehe zu „Märkte“, um Aktien oder Krypto zu kaufen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF56677F), fontSize: 12),
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
                    MaterialPageRoute(builder: (_) => TradeDetailScreen(asset: asset)),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF243247)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              pos.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8B9CB2)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${CurrencyFormatter.formatAmount(pos.amount)} Stk. @ ${CurrencyFormatter.formatPrice(pos.averageBuyPrice)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF56677F)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              '${posProfit ? "+" : ""}${CurrencyFormatter.format(posPnL)} (${CurrencyFormatter.formatPercent(pos.unrealizedPnLPercent)})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: posProfit ? AppColors.bullish : AppColors.bearish,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _showSellDialog(context, pos, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loss.withValues(alpha: 0.18),
                          foregroundColor: AppColors.loss,
                          side: const BorderSide(color: AppColors.loss, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Verkaufen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
