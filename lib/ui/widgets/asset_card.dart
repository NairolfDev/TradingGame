import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../logic/portfolio_provider.dart';
import 'mini_chart.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;

  const AssetCard({
    super.key,
    required this.asset,
    required this.onTap,
  });

  Color _getCategoryColor(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return AppColors.stock;
      case AssetType.crypto:
        return AppColors.crypto;
      case AssetType.etf:
        return AppColors.etf;
      case AssetType.cfd:
        return AppColors.cfd;
      case AssetType.bond:
        return AppColors.bond;
      case AssetType.commodity:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final isOpen = provider.isAssetMarketOpen(asset);
    final statusString = provider.getMarketStatusString(asset);
    final isPos = asset.isPositive;
    final hasQuote = provider.quoteUpdatedAt(asset) != null && asset.currentPrice > 0;
    final catColor = _getCategoryColor(asset.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon / Category Indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: catColor.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                asset.symbol.length > 4
                    ? asset.symbol.substring(0, 3)
                    : asset.symbol,
                style: TextStyle(
                  color: catColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name, Symbol & Market Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asset.symbol,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (asset.maxLeverage > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.cfd.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.cfd.withValues(alpha: 0.5),
                                width: 0.8),
                          ),
                          child: Text(
                            '${asset.maxLeverage}x',
                            style: const TextStyle(
                              color: AppColors.cfd,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Börsenstatus-Pill
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen ? AppColors.profit : AppColors.loss,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${isOpen ? 'Börse offen' : statusString} · ${provider.quoteStatus(asset)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isOpen ? AppColors.profit : AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Mini Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: provider.quoteUpdatedAt(asset) == null
                  ? const SizedBox(width: 60, child: Center(child: Text('—', style: TextStyle(color: AppColors.textMuted))))
                  : MiniChart(data: asset.priceHistory, isPositive: isPos),
            ),

            // Price & 24h PnL
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasQuote ? CurrencyFormatter.format(asset.currentPrice) : '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: (isPos ? AppColors.profit : AppColors.loss)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasQuote ? CurrencyFormatter.formatPercent(asset.change24hPercent) : 'Kein Kurs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPos ? AppColors.profit : AppColors.loss,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
