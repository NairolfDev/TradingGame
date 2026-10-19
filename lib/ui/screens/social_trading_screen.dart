import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/copy_trader.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/empty_state.dart';

/// Public portfolios of other players; copying invests an amount in the same
/// weights.
class SocialTradingScreen extends StatelessWidget {
  const SocialTradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final traders = provider.copyTraders;
    return Scaffold(
      appBar: AppBar(title: const Text('Social- & Copy-Trading')),
      body: traders.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              title: 'Noch keine öffentlichen Portfolios',
              message:
                  'Spieler können ihr Portfolio in den Einstellungen öffentlich machen. '
                  'Dann erscheint es hier und andere können es kopieren.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final t in traders) _TraderCard(trader: t),
              ],
            ),
    );
  }
}

class _TraderCard extends StatelessWidget {
  final CopyTrader trader;
  const _TraderCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final roiColor = trader.roiPercent >= 0 ? AppColors.profit : AppColors.loss;
    final sign = trader.roiPercent >= 0 ? '+' : '−';
    final holdings = trader.portfolioAllocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
            children: [
              Text(trader.avatarEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trader.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${trader.title} · ${trader.riskStyle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${trader.roiPercent.abs().toStringAsFixed(2)} %',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: roiColor,
                    ),
                  ),
                  Text(
                    'Trefferquote ${trader.winRatePercent.toStringAsFixed(0)} %',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (holdings.isEmpty)
            Text(
              'Hält aktuell keine kopierbaren Werte.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in holdings)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${h.key} ${(h.value * 100).toStringAsFixed(0)} %',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Portfolio kopieren'),
              onPressed: holdings.isEmpty
                  ? null
                  : () => _copy(context, trader),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, CopyTrader trader) async {
    final provider = context.read<PortfolioProvider>();
    final max = provider.cash.floorToDouble();
    if (max < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens 500 € frei verfügbar nötig.')),
      );
      return;
    }
    var amount = (max < 1000 ? max : 1000).toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('${trader.name} kopieren'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (max > 500)
                Slider(
                  min: 500,
                  max: max,
                  divisions: ((max - 500) / 100).ceil().clamp(1, 1000),
                  value: amount.clamp(500, max),
                  onChanged: (v) => setState(() => amount = v.roundToDouble()),
                ),
              const Text(
                'Der Betrag wird einmalig in denselben Gewichten angelegt. '
                'Danach läuft dein Portfolio unabhängig.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kopieren'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await provider.copyTrader(trader, amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Portfolio von ${trader.name} kopiert.'
              : (provider.lastAlertMessage ?? 'Kopieren nicht möglich.'),
        ),
      ),
    );
  }
}
