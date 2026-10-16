import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/rank_badge.dart';
import '../widgets/position_tile.dart';
import '../widgets/pending_order_card.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final netWorth = provider.netWorth;
    final roi = provider.totalRoiPercent;
    final isPosRoi = roi >= 0;
    final rank = provider.currentRank;
    final nextRank = provider.nextRank;
    final progress = provider.rankProgress;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Top Bar: Titel, Rang-Badge und Börsenzeit-Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRADING GAME',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Österreich Börsenspiel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  RankBadge(rank: rank, compact: true),
                ],
              ),

              const SizedBox(height: 16),

              // Alert Banner (falls vorhanden)
              if (provider.lastAlertMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.lastAlertMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: AppColors.textMuted,
                        onPressed: provider.clearAlert,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              // Net Worth Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF16233B),
                      Color(0xFF0F1726),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GESAMTVERMÖGEN (NET WORTH)',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPosRoi ? AppColors.profit : AppColors.loss)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPosRoi
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 12,
                                color:
                                    isPosRoi ? AppColors.profit : AppColors.loss,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                CurrencyFormatter.formatPercent(roi),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPosRoi
                                      ? AppColors.profit
                                      : AppColors.loss,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(netWorth),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Handelskapital: ${CurrencyFormatter.format(provider.cash + provider.totalPositionsValue + provider.totalLuxuryValue)} • Reingewinn: ${netWorth >= 0 ? "+" : ""}${CurrencyFormatter.format(netWorth)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: netWorth >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.cardBorder, height: 1),
                    const SizedBox(height: 14),

                    // Portfolio Aufteilung: Cash, Wertpapiere, Luxusgüter, Schulden
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(
                          'Cash',
                          CurrencyFormatter.format(provider.cash),
                          AppColors.accent,
                        ),
                        _buildStatColumn(
                          'Wertpapiere',
                          CurrencyFormatter.format(provider.totalPositionsValue),
                          AppColors.primary,
                        ),
                        _buildStatColumn(
                          'Luxusbesitz',
                          CurrencyFormatter.format(provider.totalLuxuryValue),
                          AppColors.gold,
                        ),
                        _buildStatColumn(
                          'Schulden',
                          '-${CurrencyFormatter.format(provider.totalDebt)}',
                          provider.totalDebt > 0 ? AppColors.loss : AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 12),

              // Bank & Kredit Schnelleinstieg Card
              InkWell(
                onTap: () => onNavigateTab(2), // Tab 2 = Bank & Kredite
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: provider.totalDebt > 0
                          ? AppColors.loss.withValues(alpha: 0.35)
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Bank & Kredit-Schalter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    provider.creditRating.grade,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              provider.totalDebt > 0
                                  ? 'Restschuld: ${CurrencyFormatter.format(provider.totalDebt)} (${provider.activeLoans.length} Kredite) • Jetzt tilgen'
                                  : 'Keine Schulden • Kredit aufnehmen ab ${(provider.creditRating.baseInterestRate * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: provider.totalDebt > 0 ? AppColors.loss : AppColors.textSecondary,
                                fontWeight: provider.totalDebt > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 14),

              // Rang-Fortschrittsleiste
              Container(
                padding: const EdgeInsets.all(14),
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
                            Text(rank.badge,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              rank.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: rank.color,
                              ),
                            ),
                          ],
                        ),
                        if (nextRank != null) ...[
                          Text(
                            'Nächster Rang: ${nextRank.title}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            '👑 Höchster Rang erreicht!',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(rank.color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prestige-Punkte: ${provider.totalPrestigePoints} 💎',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (nextRank != null) ...[
                          Text(
                            'Noch ${CurrencyFormatter.format(nextRank.minNetWorth - netWorth)} bis Rang-Up',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Börsensimulations-Info & Schnelltest-Modus
              // Anstehende Vorab-Orders (falls vorhanden)
              if (provider.pendingOrders.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '🕒 Vorab-Orders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${provider.pendingOrders.length}',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Warten auf Marktöffnung',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...provider.pendingOrders.map(
                  (order) => PendingOrderCard(
                    order: order,
                    onCancel: () => provider.cancelPendingOrder(order),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Offene Positionen
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Offene Positionen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (provider.positions.isNotEmpty)
                    Text(
                      '${provider.positions.length} Positionen',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (provider.positions.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.show_chart,
                          size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'Noch keine offenen Positionen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Starte deinen ersten Trade in Aktien, Krypto, ETFs, CFDs oder Anleihen!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => onNavigateTab(1), // Zu Märkte
                        icon: const Icon(Icons.trending_up, size: 16),
                        label: const Text('Märkte durchsuchen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...provider.positions.map(
                  (pos) => PositionTile(
                    position: pos,
                    onSell: () => _showSellDialog(context, pos, provider),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showSellDialog(
      BuildContext context, dynamic position, PortfolioProvider provider) {
    double amountToSell = position.amount;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final portionPnL = (amountToSell / position.amount) *
                position.unrealizedPnL;
            final isPnLPos = portionPnL >= 0;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Position Schließen: ${position.symbol}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aktueller PnL: ${isPnLPos ? "+" : ""}${CurrencyFormatter.format(portionPnL)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPnLPos ? AppColors.profit : AppColors.loss,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Menge: ${CurrencyFormatter.formatAmount(amountToSell)} / ${CurrencyFormatter.formatAmount(position.amount)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Slider(
                    value: amountToSell,
                    min: 0.0001,
                    max: position.amount,
                    divisions: 100,
                    activeColor: AppColors.loss,
                    onChanged: (val) {
                      setModalState(() {
                        amountToSell = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await provider.executeSell(
                          position: position,
                          sellAmount: amountToSell,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loss,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verkauf Bestätigen',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
