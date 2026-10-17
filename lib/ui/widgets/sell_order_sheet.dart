import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/position.dart';
import '../../logic/portfolio_provider.dart';
import 'order_entry.dart';
import 'order_routing_dialog.dart';

class SellOrderSheet extends StatefulWidget {
  final Position position;
  final PortfolioProvider provider;
  const SellOrderSheet({
    super.key,
    required this.position,
    required this.provider,
  });

  static Future<void> show({
    required BuildContext context,
    required Position position,
    required PortfolioProvider provider,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: SellOrderSheet(position: position, provider: provider),
    ),
  );

  @override
  State<SellOrderSheet> createState() => _SellOrderSheetState();
}

class _SellOrderSheetState extends State<SellOrderSheet> {
  double? _fraction = 1;
  double _amount = 0;
  double? _euros;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final position = provider.positions
        .where((p) => p.id == widget.position.id)
        .firstOrNull;
    final asset = provider.assets
        .where((a) => a.id == widget.position.assetId)
        .firstOrNull;
    final current = position?.copyWith(currentPrice: asset?.currentPrice);
    final quantity = current?.amount ?? 0;
    final unitValue = quantity > 0 ? current!.currentValue / quantity : 0.0;
    final amount = _fraction != null
        ? quantity * _fraction!
        : _euros != null && unitValue > 0
        ? _euros! / unitValue
        : _amount;
    final hasQuote =
        asset != null && asset.currentPrice.isFinite && asset.currentPrice > 0;
    final marketOpen = asset != null && provider.isAssetMarketOpen(asset);
    final valid =
        !_busy &&
        !provider.isLoading &&
        hasQuote &&
        marketOpen &&
        amount.isFinite &&
        amount > 0 &&
        amount <= quantity;
    final proceeds = amount * unitValue;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.position.symbol} verkaufen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Schließen',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Bestand: ${CurrencyFormatter.formatAmount(quantity)} Stück',
                ),
                const SizedBox(height: 8),
                Text(
                  asset == null
                      ? 'Kein Kurs verfügbar'
                      : provider.quoteStatus(asset),
                ),
                if (!marketOpen)
                  const Text(
                    'Markt geschlossen. Verkauf während der Handelszeiten möglich.',
                  ),
                const SizedBox(height: 16),
                OrderEntry(
                  amount: amount,
                  fraction: _fraction,
                  enabled: !_busy && hasQuote,
                  euroLabel: 'Erwarteter Rückfluss in EUR',
                  fractionLabel: 'Anteil deines Bestands',
                  amountForEuros: (euros) =>
                      unitValue > 0 ? euros / unitValue : 0,
                  eurosForAmount: (value) => value * unitValue,
                  amountForFraction: (fraction) => quantity * fraction,
                  onChanged: (value, fraction, euros) => setState(() {
                    _amount = value;
                    _fraction = fraction;
                    _euros = euros;
                  }),
                ),
                const SizedBox(height: 20),
                Text('Gebühren: ${CurrencyFormatter.format(0)}'),
                Text(
                  'Voraussichtlicher Rückfluss: ${CurrencyFormatter.format(proceeds)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Enthaltener Gewinn/Verlust: ${CurrencyFormatter.format(quantity > 0 ? current!.unrealizedPnL * amount / quantity : 0)}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die endgültige Menge und der Rückfluss werden bei Ausführung ermittelt.',
                ),
                if (amount > quantity)
                  Text(
                    'Die Menge übersteigt deinen Bestand.',
                    style: TextStyle(color: AppColors.loss),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loss,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: !valid
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final fraction = _fraction;
                          final success = await OrderRoutingDialog.show(
                            context: context,
                            symbol: current!.symbol,
                            assetName: current.name,
                            isBuy: false,
                            amount: amount,
                            price: asset.currentPrice,
                            provider: provider,
                            onExecute: () => provider.executeSell(
                              position: current,
                              sellAmount: amount,
                              sellFraction: fraction,
                            ),
                          );
                          if (!context.mounted) return;
                          if (success) {
                            Navigator.pop(context);
                          } else {
                            setState(() => _busy = false);
                          }
                        },
                  child: const Text('Verkauf verbindlich bestätigen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
