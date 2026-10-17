import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import 'game_fx.dart';

/// Uses the provider's accounting: sell reservations have left active positions.
class PortfolioSummary extends StatelessWidget {
  final PortfolioProvider portfolio;

  const PortfolioSummary({super.key, required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final reservedCash = portfolio.pendingOrders
        .where((order) => order.isBuy)
        .fold<double>(0, (sum, order) => sum + order.totalEstimatedCost);
    final reservedSales = portfolio.pendingOrderValue - reservedCash;
    final profit = portfolio.netWorth - 25000;
    final profitColor = profit >= 0 ? AppColors.profit : AppColors.loss;
    final metrics = <Widget>[
      _metric('Frei verfügbares Cash', portfolio.cash),
      _metric(
        'Investierter Wert',
        portfolio.totalPositionsValue + reservedSales,
      ),
      _metric('Für Käufe reserviertes Cash', reservedCash),
      _metric(
        'Schulden',
        portfolio.totalDebt,
        color: portfolio.totalDebt > 0 ? AppColors.loss : null,
      ),
      if (portfolio.totalLuxuryValue > 0)
        _metric('Luxusbesitz', portfolio.totalLuxuryValue),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: heroDecoration(glow: profitColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nettovermögen',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          AnimatedMoney(
            portfolio.netWorth,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${profit >= 0 ? "+" : ""}${CurrencyFormatter.format(profit)} '
            '(${CurrencyFormatter.formatPercent(profit / 25000)}) seit Start',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: profitColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Basis: 25.000 € Eigenkapital',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          Divider(height: 32, color: AppColors.cardBorder),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final columns = constraints.maxWidth >= 900 * scale
                  ? 4
                  : constraints.maxWidth >= 480 * scale
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 20) / columns;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: width, child: metric),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Nettovermögen = Cash + investierter Wert + reserviertes '
            'Kauf-Cash + Luxusbesitz − Schulden.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          if (reservedSales > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Davon für Verkäufe vorgemerkt: '
              '${CurrencyFormatter.format(reservedSales)}. Bereits im '
              'investierten Wert enthalten.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, double value, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 4),
      Text(
        CurrencyFormatter.format(value),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    ],
  );
}
