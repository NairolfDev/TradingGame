import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/rank_badge.dart';
import '../widgets/position_tile.dart';
import '../widgets/pending_order_card.dart';
import '../widgets/breaking_news_ticker.dart';
import '../widgets/order_routing_dialog.dart';
import 'achievements_screen.dart';
import 'quests_screen.dart';
import 'social_trading_screen.dart';
import 'dividends_screen.dart';

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
          onRefresh: () async {
            await provider.fetchLiveMarketQuotes();
            await provider.reloadLeaderboard();
          },
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Top Bar: Titel, Rang-Badge und Börsenzeit-Toggle
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
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

              // Breaking News Ticker (Marktbewegende Eilmeldungen)
              if (provider.latestBreakingNews != null) ...[
                BreakingNewsTicker(
                  news: provider.latestBreakingNews,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: provider.latestBreakingNews!.isBullish
                                ? AppColors.bullish
                                : AppColors.bearish,
                            width: 1.2,
                          ),
                        ),
                        title: Row(
                          children: [
                            Icon(
                              Icons.bolt,
                              color: provider.latestBreakingNews!.isBullish
                                  ? AppColors.bullish
                                  : AppColors.bearish,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Markt-Eilmeldung',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.latestBreakingNews!.headline,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.latestBreakingNews!.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Marktauswirkung: ${(provider.latestBreakingNews!.priceImpact * 100).toStringAsFixed(1)}% auf ${provider.latestBreakingNews!.affectedSymbol ?? "Gesamtmarkt"}',
                                style: TextStyle(
                                  color: provider.latestBreakingNews!.isBullish
                                      ? AppColors.bullish
                                      : AppColors.bearish,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Schließen'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween, runSpacing: 8, spacing: 12,
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
                            mainAxisSize: MainAxisSize.min,
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
                      'Handelskapital: ${CurrencyFormatter.format(provider.cash + provider.totalPositionsValue + provider.pendingOrderValue + provider.totalLuxuryValue)} • Reingewinn: ${provider.netProfit >= 0 ? "+" : ""}${CurrencyFormatter.format(provider.netProfit)}',
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
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 600 ? 4 : 2;
                      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
                      return Wrap(spacing: 16, runSpacing: 16, children: [
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
                      ].map((child) => SizedBox(width: width, child: child)).toList());
                    }),
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
                            Wrap(
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween, runSpacing: 8, spacing: 12,
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween, runSpacing: 8, spacing: 12,
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

              // 4 Neue Power-Features (Turbo-Optionen, Quests, Copy-Trading, Dividenden)
              Wrap(
                alignment: WrapAlignment.spaceBetween, runSpacing: 8, spacing: 12,
                children: [
                  const Text(
                    '⚡ Trading- & Game-Features',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NEU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Trophäen & Erfolge',
                      subtitle: 'Prestige & Badges',
                      detail: '${provider.achievementService.unlockedCount} / ${provider.achievementService.totalCount} frei',
                      icon: Icons.military_tech,
                      color: AppColors.accentGold,
                      badge: provider.achievementService.unlockedCount > 0
                          ? '🏆 ${provider.achievementService.unlockedCount}'
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Wall Street Pass',
                      subtitle: 'Quests & Streak',
                      detail: '${provider.loginStreakDays} Tage 🔥',
                      icon: Icons.emoji_events,
                      color: Colors.amber,
                      badge: provider.dailyQuests.where((q) => q.isCompleted && !q.isClaimed).isNotEmpty
                          ? '🎁 Belohnung'
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuestsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Copy-Trading',
                      subtitle: 'Öffentliche Portfolios',
                      detail: '${provider.copyTraders.length} Profile',
                      icon: Icons.people_alt,
                      color: Colors.lightBlueAccent,
                      badge: 'Social',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SocialTradingScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Dividenden',
                      subtitle: 'Passiver Cashflow',
                      detail: CurrencyFormatter.format(provider.monthlyPassiveIncome),
                      icon: Icons.payments,
                      color: Colors.greenAccent,
                      badge: provider.monthlyPassiveIncome > 0 ? 'Ausschütten' : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DividendsScreen()),
                      ),
                    ),
                  ),
                ],
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
    double sellFraction = 1;

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
                    value: sellFraction,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: AppColors.loss,
                    onChanged: (val) {
                      setModalState(() {
                        sellFraction = val;
                        amountToSell = position.amount * val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: sellFraction > 0 ? () async {
                        Navigator.pop(ctx);
                        await OrderRoutingDialog.show(
                          context: context,
                          symbol: position.symbol,
                          assetName: position.name,
                          isBuy: false,
                          amount: amountToSell,
                          price: position.currentPrice,
                          onExecute: () => provider.executeSell(
                            position: position,
                            sellAmount: amountToSell,
                            sellFraction: sellFraction,
                          ),
                        );
                      } : null,
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

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String detail,
    required IconData icon,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge != null ? color.withValues(alpha: 0.5) : AppColors.cardBorder,
            width: badge != null ? 1.2 : 1,
          ),
          boxShadow: badge != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
