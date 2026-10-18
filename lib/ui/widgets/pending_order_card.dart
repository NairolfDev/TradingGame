import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/market_schedule.dart';
import '../../data/models/pending_order.dart';

class PendingOrderCard extends StatelessWidget {
  final PendingOrder order;
  final VoidCallback onCancel;

  /// Clock for the "opens next" text; defaults to the current time.
  final DateTime? now;

  const PendingOrderCard({
    super.key,
    required this.order,
    required this.onCancel,
    this.now,
  });

  /// When the market of a waiting order opens next, e.g.
  /// "Wall Street · Öffnet Montag um 15:30 Uhr".
  Widget _nextOpening() {
    final schedule = MarketSchedule.forSymbol(order.symbol, order.assetType);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        schedule.nextOpeningLine(now),
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.schedule, color: AppColors.warning),
              Text(
                '${order.isBuy ? "Kauf" : "Verkauf"} ${order.symbol}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (order.leverage > 1) Text('${order.leverage}x Hebel'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.isBuy
                ? 'Reserviertes Cash: ${CurrencyFormatter.format(order.totalEstimatedCost)}'
                : 'Reservierte Menge: ${CurrencyFormatter.formatAmount(order.amount)} Stk.',
          ),
          if (order.isBuy)
            Text(
              'Geplante Menge: ${CurrencyFormatter.formatAmount(order.amount)} Stk.',
            ),
          const SizedBox(height: 8),
          Text(
            order.scheduledExecutionTime != null
                ? 'Im Orderbuch · Ausführung in etwa '
                      '${order.minutesRemaining == 0 ? "< 1" : order.minutesRemaining} Min. '
                      '(${order.brokerVenue ?? "Börsenplatz"})'
                : 'Wartet auf die nächste Börsenöffnung',
            style: TextStyle(fontSize: 14, color: AppColors.warning),
          ),
          if (order.scheduledExecutionTime == null) _nextOpening(),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.loss,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.all(12),
            ),
            child: const Text('Order stornieren'),
          ),
        ],
      ),
    ),
  );
}
