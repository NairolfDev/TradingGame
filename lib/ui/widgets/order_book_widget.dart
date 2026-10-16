import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';

class OrderBookWidget extends StatelessWidget {
  final Asset asset;

  const OrderBookWidget({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final price = asset.currentPrice;
    final spreadPct = asset.type == AssetType.crypto
        ? 0.0015
        : (asset.type == AssetType.stock ? 0.0008 : 0.0020);
    final spreadEur = price * spreadPct;

    final baseVol = (price * 320.0 + 850.0).clamp(100.0, 100000.0);

    // Generiere 5 realistische Bid (Käufer) und Ask (Verkäufer) Levels
    final bids = List.generate(5, (index) {
      final p = price - (spreadEur / 2) - (price * 0.0007 * (index + 1));
      final vol = ((baseVol / 500) * (1.2 - index * 0.15) + (index * 13)).abs();
      return _OrderLevel(price: p, volume: vol.clamp(5, 50000).toDouble());
    });

    final asks = List.generate(5, (index) {
      final p = price + (spreadEur / 2) + (price * 0.0007 * (index + 1));
      final vol = ((baseVol / 520) * (1.1 - index * 0.12) + (index * 11)).abs();
      return _OrderLevel(price: p, volume: vol.clamp(5, 50000).toDouble());
    });

    final totalBidVol = bids.fold(0.0, (sum, b) => sum + b.volume);
    final totalAskVol = asks.fold(0.0, (sum, a) => sum + a.volume);
    final totalVol = totalBidVol + totalAskVol;
    final buyRatio = totalVol > 0 ? (totalBidVol / totalVol) : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_rows_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Orderbuch (Level 2 Markttiefe)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Spread: ${CurrencyFormatter.formatPrice(spreadEur)} (${(spreadPct * 100).toStringAsFixed(2)}%)',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buy/Sell Orderbuch Druck-Balken
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (buyRatio * 100).toInt().clamp(5, 95),
                    child: Container(color: AppColors.bullish),
                  ),
                  Expanded(
                    flex: ((1 - buyRatio) * 100).toInt().clamp(5, 95),
                    child: Container(color: AppColors.bearish),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kaufdruck ${(buyRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10, color: AppColors.bullish, fontWeight: FontWeight.bold),
              ),
              Text(
                'Verkaufsdruck ${((1 - buyRatio) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10, color: AppColors.bearish, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tabellen-Header
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Geld (Bid)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 3,
                child: Text('Menge', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Text('Brief (Ask)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 3,
                child: Text('Menge', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
            ],
          ),
          const Divider(color: AppColors.cardBorder, height: 12),

          // 5 Zeilen
          ...List.generate(5, (i) {
            final bid = bids[i];
            final ask = asks[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      CurrencyFormatter.formatPrice(bid.price),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bullish,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      CurrencyFormatter.formatAmount(bid.volume),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Text(
                      CurrencyFormatter.formatPrice(ask.price),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bearish,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      CurrencyFormatter.formatAmount(ask.volume),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderLevel {
  final double price;
  final double volume;

  _OrderLevel({required this.price, required this.volume});
}
