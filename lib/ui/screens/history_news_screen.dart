import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction.dart';
import '../../logic/portfolio_provider.dart';

class HistoryNewsScreen extends StatelessWidget {
  const HistoryNewsScreen({super.key});

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
            tabs: [
              Tab(icon: Icon(Icons.newspaper), text: 'Marktnachrichten'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Orderbuch-Historie'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Live News
            _buildNewsTab(provider),
            // Tab 2: Transaction History
            _buildHistoryTab(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsTab(PortfolioProvider provider) {
    final newsList = provider.newsEvents;

    if (newsList.isEmpty) {
      return Center(
        child: Text(
          'Noch keine aktuellen Eilmeldungen.\nNeue Meldungen erscheinen, sobald eine Nachrichtenquelle verfügbar ist.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final dateFormat = DateFormat('HH:mm:ss');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: newsList.length,
      itemBuilder: (context, index) {
        final news = newsList[index];
        final isBull = news.isBullish;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBull
                  ? AppColors.profit.withValues(alpha: 0.3)
                  : AppColors.loss.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isBull ? AppColors.profit : AppColors.loss)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isBull ? 'BULLISH ↗' : 'BEARISH ↘',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBull ? AppColors.profit : AppColors.loss,
                      ),
                    ),
                  ),
                  Text(
                    dateFormat.format(news.timestamp),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(PortfolioProvider provider) {
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'Noch keine Transaktionen vorhanden.\nKaufe Wertpapiere oder Prestige-Güter!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
            badgeColor = AppColors.gold;
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
                    fontSize: 11,
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
                        fontSize: 10,
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
                        fontSize: 11,
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
