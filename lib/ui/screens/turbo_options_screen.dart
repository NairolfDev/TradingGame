import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/turbo_option.dart';
import '../../logic/portfolio_provider.dart';

class TurboOptionsScreen extends StatefulWidget {
  const TurboOptionsScreen({super.key});

  @override
  State<TurboOptionsScreen> createState() => _TurboOptionsScreenState();
}

class _TurboOptionsScreenState extends State<TurboOptionsScreen> {
  String _selectedSymbol = 'BTC';
  double _stake = 100.0;
  int _durationSeconds = 60;

  final List<String> _tradableSymbols = ['BTC', 'XAU/EUR', 'BRENT', 'OMV.VI', 'NVDA'];
  final List<double> _stakePresets = [50.0, 100.0, 250.0, 500.0, 1000.0];

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final asset = portfolio.assets.firstWhere(
      (a) => a.symbol == _selectedSymbol,
      orElse: () => portfolio.assets.first,
    );

    final activeOptions = portfolio.activeTurboOptions;
    final settledOptions = portfolio.settledTurboOptions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text(
              '60s Turbo-Optionen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${portfolio.cash.toStringAsFixed(0)} €',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Asset Auswahl
            const Text(
              'Basiswert wählen:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tradableSymbols.map((sym) {
                  final isSelected = sym == _selectedSymbol;
                  final a = portfolio.assets.firstWhere((item) => item.symbol == sym, orElse: () => asset);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$sym (${a.currentPrice.toStringAsFixed(1)} €)'),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSymbol = sym);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Live Preis & Chart Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            '${asset.currentPrice.toStringAsFixed(2)} €',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (asset.isPositive ? AppColors.bullish : AppColors.bearish).withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${asset.isPositive ? '+' : ''}${(asset.change24hPercent * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: asset.isPositive ? AppColors.bullish : AppColors.bearish,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚡ Payout: 185% (85% Reingewinn bei richtiger Prognose)',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Laufzeit & Einsatz
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Laufzeit:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [30, 60].map((sec) {
                          final isSelected = _durationSeconds == sec;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              onPressed: () => setState(() => _durationSeconds = sec),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSelected ? AppColors.primary.withAlpha(40) : null,
                                side: BorderSide(color: isSelected ? AppColors.primary : Colors.white24),
                              ),
                              child: Text(
                                '${sec}s',
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Einsatz:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${_stake.toStringAsFixed(0)} €',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Einsatz Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _stakePresets.map((amt) {
                  final isSelected = _stake == amt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('${amt.toStringAsFixed(0)} €'),
                      backgroundColor: isSelected ? AppColors.primary : AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onPressed: () => setState(() => _stake = amt),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Action Buttons (Call / Put)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: portfolio.cash >= _stake
                        ? () {
                            final ok = portfolio.placeTurboOption(
                              assetSymbol: asset.symbol,
                              assetName: asset.name,
                              entryPrice: asset.currentPrice,
                              direction: TurboDirection.call,
                              stake: _stake,
                              durationSeconds: _durationSeconds,
                            );
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.bullish,
                                  content: Text('🟢 ${_durationSeconds}s CALL auf ${asset.symbol} platziert!'),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bullish,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, size: 24, color: Colors.black),
                            SizedBox(width: 6),
                            Text('HÖHER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('+85% Gewinn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: portfolio.cash >= _stake
                        ? () {
                            final ok = portfolio.placeTurboOption(
                              assetSymbol: asset.symbol,
                              assetName: asset.name,
                              entryPrice: asset.currentPrice,
                              direction: TurboDirection.put,
                              stake: _stake,
                              durationSeconds: _durationSeconds,
                            );
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.bearish,
                                  content: Text('🔴 ${_durationSeconds}s PUT auf ${asset.symbol} platziert!'),
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bearish,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, size: 24, color: Colors.white),
                            SizedBox(width: 6),
                            Text('TIEFER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('+85% Gewinn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 5. Aktive Optionen
            if (activeOptions.isNotEmpty) ...[
              const Text(
                'Laufende Turbo-Optionen:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              ...activeOptions.map((opt) {
                final remainingSec = opt.endsAt.difference(DateTime.now()).inSeconds.clamp(0, 100);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        opt.direction == TurboDirection.call ? Icons.arrow_upward : Icons.arrow_downward,
                        color: opt.direction == TurboDirection.call ? AppColors.bullish : AppColors.bearish,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${opt.assetSymbol} (${opt.direction == TurboDirection.call ? 'CALL' : 'PUT'})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Einstieg: ${opt.entryPrice.toStringAsFixed(2)} € | Einsatz: ${opt.stake.toStringAsFixed(0)} €',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${remainingSec}s',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // 6. Historie der Blitz-Optionen
            if (settledOptions.isNotEmpty) ...[
              const Text(
                'Kürzliche Ergebnisse:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              ...settledOptions.take(5).map((opt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (opt.isWon ? AppColors.bullish : AppColors.bearish).withAlpha(70),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        opt.isWon ? Icons.check_circle : Icons.cancel,
                        color: opt.isWon ? AppColors.bullish : AppColors.bearish,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${opt.assetSymbol} • ${opt.direction == TurboDirection.call ? 'CALL' : 'PUT'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Start: ${opt.entryPrice.toStringAsFixed(2)} € ➔ Ende: ${(opt.finalPrice ?? 0).toStringAsFixed(2)} €',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        opt.isWon
                            ? '+${(opt.profit).toStringAsFixed(2)} €'
                            : '-${opt.stake.toStringAsFixed(2)} €',
                        style: TextStyle(
                          color: opt.isWon ? AppColors.bullish : AppColors.bearish,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
