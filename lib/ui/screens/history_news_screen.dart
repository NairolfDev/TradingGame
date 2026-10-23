import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/empty_state.dart';
import 'trade_detail_screen.dart';

class HistoryNewsScreen extends StatelessWidget {
  /// Takes people to the markets from the empty order history.
  final VoidCallback? onOpenMarkets;
  const HistoryNewsScreen({super.key, this.onOpenMarkets});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aktivität'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.newspaper), text: 'Marktnachrichten'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Orderbuch-Historie'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Live News
            _buildNewsTab(context, provider),
            // Tab 2: Transaction History
            _buildHistoryTab(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsTab(BuildContext context, PortfolioProvider provider) {
    final newsList = provider.newsEvents;
    final dateFormat = DateFormat('HH:mm:ss');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 18, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Live-Marktbewegung & Berichte',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => provider.fetchLiveMarketQuotes(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Aktualisieren'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: newsList.isEmpty
              ? const EmptyState(
                  icon: Icons.newspaper,
                  title: 'Noch keine Eilmeldungen',
                  message:
                      'Neue Meldungen erscheinen hier, sobald eine Nachrichtenquelle verfügbar ist.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: newsList.length,
                  itemBuilder: (context, index) {
                    final news = newsList[index];
                    final isBull = news.isBullish;
                    final matchingAsset = news.affectedSymbol != null
                        ? provider.assets
                            .where((a) => a.symbol == news.affectedSymbol)
                            .firstOrNull
                        : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isBull
                              ? AppColors.profit.withValues(alpha: 0.3)
                              : AppColors.loss.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: matchingAsset != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TradeDetailScreen(
                                        asset: matchingAsset,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isBull
                                                      ? AppColors.profit
                                                      : AppColors.loss)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isBull
                                                  ? 'BULLISH ↗'
                                                  : 'BEARISH ↘',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isBull
                                                    ? AppColors.profit
                                                    : AppColors.loss,
                                              ),
                                            ),
                                          ),
                                          if (news.affectedSymbol != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                '${news.affectedSymbol} • ${news.category}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateFormat.format(news.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  news.headline,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  news.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (matchingAsset != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Zum Instrument ${matchingAsset.symbol} →',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(PortfolioProvider provider) {
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long,
        title: 'Noch keine Transaktionen',
        message:
            'Kaufe Wertpapiere oder Prestige-Güter, dann erscheinen sie hier.',
        actionLabel: onOpenMarkets == null ? null : 'Märkte entdecken',
        onAction: onOpenMarkets,
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];

        Color badgeColor;
        switch (tx.type) {
          case TransactionType.buy:
            badgeColor = AppColors.primary;
            break;
          case TransactionType.sell:
            badgeColor = tx.realizedPnL != null && tx.realizedPnL! >= 0
                ? AppColors.profit
                : AppColors.loss;
            break;
          case TransactionType.liquidation:
            badgeColor = AppColors.loss;
            break;
          case TransactionType.couponPayout:
            badgeColor = AppColors.bond;
            break;
          case TransactionType.luxuryPurchase:
            badgeColor = AppColors.purple;
            break;
          case TransactionType.loanPayout:
            badgeColor = AppColors.accent;
            break;
          case TransactionType.loanRepayment:
            badgeColor = AppColors.profit;
            break;
          case TransactionType.dividendPayout:
            badgeColor = AppColors.profit;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  tx.type.displayName,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tx.symbol} • ${tx.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dateFormat.format(tx.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(tx.totalAmount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (tx.realizedPnL != null)
                    Text(
                      '${tx.realizedPnL! >= 0 ? "+" : ""}${CurrencyFormatter.format(tx.realizedPnL!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tx.realizedPnL! >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
