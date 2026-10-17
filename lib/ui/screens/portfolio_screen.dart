import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/pending_order_card.dart';
import '../widgets/portfolio_summary.dart';
import '../widgets/position_tile.dart';
import '../widgets/sell_order_sheet.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    if (portfolio.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: portfolio.fetchLiveMarketQuotes,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Portfolio',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              PortfolioSummary(portfolio: portfolio),
              const SizedBox(height: 24),
              Text(
                'Positionen (${portfolio.positions.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (portfolio.positions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Keine aktiven Positionen. Unter Märkte kannst du '
                    'Wertpapiere entdecken und deine erste Order aufgeben.',
                  ),
                ),
              for (final position in portfolio.positions)
                PositionTile(
                  position: position,
                  onSell: () => SellOrderSheet.show(
                    context: context,
                    position: position,
                    provider: portfolio,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Offene Orders (${portfolio.pendingOrders.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kauf-Cash und zum Verkauf vorgemerkte Anteile bleiben '
                'bis zur Ausführung reserviert.',
              ),
              if (portfolio.pendingOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Keine offenen Orders.'),
                ),
              for (final order in portfolio.pendingOrders)
                PendingOrderCard(
                  order: order,
                  onCancel: () => portfolio.cancelPendingOrder(order),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
