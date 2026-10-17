import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/position.dart';

class PositionTile extends StatelessWidget {
  final Position position;
  final VoidCallback onSell;

  const PositionTile({super.key, required this.position, required this.onSell});

  @override
  Widget build(BuildContext context) {
    final profit = position.unrealizedPnL;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  position.symbol,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  position.isLeveraged
                      ? '${position.leverage}x ${position.isShort ? "SHORT" : "LONG"}'
                      : 'SPOT',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              position.name,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(position.currentValue),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${profit >= 0 ? "+" : ""}${CurrencyFormatter.format(profit)} '
              '(${CurrencyFormatter.formatPercent(position.unrealizedPnLPercent)}) '
              'nicht realisiert',
              style: TextStyle(
                fontSize: 14,
                color: profit >= 0 ? AppColors.profit : AppColors.loss,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Menge: ${CurrencyFormatter.formatAmount(position.amount)}',
                ),
                Text(
                  'Ø Kauf: ${CurrencyFormatter.format(position.averageBuyPrice)}',
                ),
                Text(
                  'Aktuell: ${CurrencyFormatter.format(position.currentPrice)}',
                ),
              ],
            ),
            if (position.isLeveraged) ...[
              const SizedBox(height: 12),
              Text(
                'Liquidationspreis: '
                '${CurrencyFormatter.format(position.liquidationPrice)}',
                style: TextStyle(color: AppColors.loss),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSell,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.loss,
                  side: BorderSide(color: AppColors.loss),
                  padding: const EdgeInsets.all(12),
                ),
                child: Text(
                  position.isLeveraged ? 'Position schließen' : 'Verkaufen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
