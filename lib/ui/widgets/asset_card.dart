import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../logic/portfolio_provider.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;
  const AssetCard({super.key, required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final hasQuote =
        provider.quoteUpdatedAt(asset) != null && asset.currentPrice > 0;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${asset.symbol} · ${asset.type.displayName}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: asset.isWatchlisted
                        ? '${asset.symbol} aus Watchlist entfernen'
                        : '${asset.symbol} zur Watchlist hinzufügen',
                    isSelected: asset.isWatchlisted,
                    color: AppColors.primary,
                    onPressed: () => provider.toggleWatchlist(asset),
                    icon: Icon(
                      asset.isWatchlisted ? Icons.star : Icons.star_border,
                    ),
                  ),
                ],
              ),
              if (asset.marketGroups.isNotEmpty || asset.sector != 'Unbekannt')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    [
                      ...asset.marketGroups,
                      if (asset.sector != 'Unbekannt') asset.sector,
                    ].join(' · '),
                  ),
                ),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    hasQuote
                        ? CurrencyFormatter.formatPrice(asset.currentPrice)
                        : 'Kein Kurs',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasQuote)
                    Text(
                      CurrencyFormatter.formatPercent(asset.change24hPercent),
                      style: TextStyle(
                        color: asset.isPositive
                            ? AppColors.profit
                            : AppColors.loss,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                provider.getMarketStatusString(asset),
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                provider.quoteStatusShort(asset),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
