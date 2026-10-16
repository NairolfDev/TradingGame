import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/copy_trader.dart';
import '../../logic/portfolio_provider.dart';

class SocialTradingScreen extends StatelessWidget {
  const SocialTradingScreen({super.key});

  void _showCopyDialog(BuildContext context, CopyTrader trader, PortfolioProvider portfolio) {
    double copyAmount = 5000.0;
    if (portfolio.cash < copyAmount) {
      copyAmount = (portfolio.cash * 0.5).clamp(500.0, 50000.0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
          title: Row(
            children: [
              Text(trader.avatarEmoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${trader.name} kopieren',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dein Kapital wird proportional auf das Portfolio von ${trader.name} aufgeteilt:',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...trader.portfolioAllocation.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${(e.value * 100).toStringAsFixed(0)} %', style: const TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              const Text('Investitionssumme:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                '${copyAmount.toStringAsFixed(0)} €',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Slider(
                value: copyAmount.clamp(500.0, portfolio.cash > 500 ? portfolio.cash : 500.0),
                min: 500.0,
                max: (portfolio.cash > 500 ? portfolio.cash : 500.0).clamp(500.0, 100000.0),
                divisions: 20,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => copyAmount = val);
                },
              ),
              Text(
                'Verfügbares Cash: ${portfolio.cash.toStringAsFixed(0)} €',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: portfolio.cash >= copyAmount
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final success = await portfolio.copyTrader(trader, copyAmount);
                      if (success) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text('🤝 Portfolio von ${trader.name} mit ${copyAmount.toStringAsFixed(0)} € erfolgreich kopiert!'),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Jetzt kopieren', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final traders = portfolio.copyTraders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.people_alt, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Social- & Copy-Trading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: traders.length,
        itemBuilder: (context, index) {
          final trader = traders[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withAlpha(80)),
                      ),
                      child: Text(trader.avatarEmoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(trader.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(trader.riskStyle, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(trader.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(trader.bio, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),

                // Stats Bar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('ROI Allzeit', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          Text('+${trader.roiPercent.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.bullish, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Win-Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          Text('${trader.winRatePercent.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Kopierer', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          Text('${trader.followersCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Allocation Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: trader.portfolioAllocation.entries.map((e) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.surface,
                      label: Text(
                        '${e.key} ${(e.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Copy Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCopyDialog(context, trader, portfolio),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('${trader.name} kopieren', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
