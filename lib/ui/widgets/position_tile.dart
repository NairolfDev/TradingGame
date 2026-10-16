import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/position.dart';

class PositionTile extends StatelessWidget {
  final Position position;
  final VoidCallback onSell;

  const PositionTile({
    super.key,
    required this.position,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final isPos = position.unrealizedPnL >= 0;
    final pnlColor = isPos ? AppColors.profit : AppColors.loss;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: position.isLeveraged
              ? AppColors.cfd.withValues(alpha: 0.3)
              : AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Symbol & Badge
              Text(
                position.symbol,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (position.isLeveraged) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: position.isShort
                        ? AppColors.loss.withValues(alpha: 0.2)
                        : AppColors.profit.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: position.isShort ? AppColors.loss : AppColors.profit,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${position.leverage}x ${position.isShort ? "SHORT" : "LONG"}',
                    style: TextStyle(
                      color: position.isShort ? AppColors.loss : AppColors.profit,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SPOT',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Value & PnL
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(position.currentValue),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${isPos ? "+" : ""}${CurrencyFormatter.format(position.unrealizedPnL)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pnlColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${CurrencyFormatter.formatPercent(position.unrealizedPnLPercent)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pnlColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menge: ${CurrencyFormatter.formatAmount(position.amount)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Ø Kauf: ${CurrencyFormatter.format(position.averageBuyPrice)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Aktuell: ${CurrencyFormatter.format(position.currentPrice)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Liquidation Warning for leveraged CFDs
          if (position.isLeveraged) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.loss.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.loss.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.loss),
                  const SizedBox(width: 6),
                  Text(
                    'Liquidationspreis: ${CurrencyFormatter.format(position.liquidationPrice)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.loss,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action: Sell / Close
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: onSell,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.loss,
                side: const BorderSide(color: AppColors.loss, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Position Schließen / Verkaufen',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
