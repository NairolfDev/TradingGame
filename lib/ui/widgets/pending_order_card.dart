import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/pending_order.dart';

class PendingOrderCard extends StatelessWidget {
  final PendingOrder order;
  final VoidCallback onCancel;

  const PendingOrderCard({
    super.key,
    required this.order,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule,
              color: AppColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Order Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${order.isBuy ? "Kauf" : "Verkauf"} ${order.symbol}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (order.leverage > 1) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${order.leverage}x Hebel)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.cfd,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.formatAmount(order.amount)} Stk. • Reserviert: ${CurrencyFormatter.format(order.totalEstimatedCost)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⏳ Wird bei Börsenöffnung ausgeführt',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stornieren Button
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.loss,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Stornieren',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
