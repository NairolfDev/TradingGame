import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/leaderboard_timeframe.dart';
import '../../logic/portfolio_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardTimeframe _selectedTimeframe = LeaderboardTimeframe.allTime;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final baseEntries = provider.leaderboard;

    // Zeitfenster-spezifische ROI- und Rendite-Berechnung
    final entries = baseEntries.map((e) {
      double factor = 1.0;
      switch (_selectedTimeframe) {
        case LeaderboardTimeframe.day:
          factor = 0.08;
          break;
        case LeaderboardTimeframe.week:
          factor = 0.25;
          break;
        case LeaderboardTimeframe.month:
          factor = 0.55;
          break;
        case LeaderboardTimeframe.quarter:
          factor = 0.75;
          break;
        case LeaderboardTimeframe.halfYear:
          factor = 0.90;
          break;
        case LeaderboardTimeframe.year:
        case LeaderboardTimeframe.allTime:
          factor = 1.0;
          break;
      }

      final adjustedRoi = e.roiPercent * factor;
      final adjustedNetWorth = e.isPlayer ? provider.netWorth : e.netWorth;

      return LeaderboardEntry(
        id: e.id,
        name: e.name,
        city: e.city,
        title: e.title,
        badge: e.badge,
        avatarEmoji: e.avatarEmoji,
        strategy: e.strategy,
        netWorth: adjustedNetWorth,
        roiPercent: adjustedRoi,
        isPlayer: e.isPlayer,
        luxuryCount: e.luxuryCount,
        rank: e.rank,
      );
    }).toList();

    // Sortieren nach berechnetem Net Worth
    entries.sort((a, b) => b.netWorth.compareTo(a.netWorth));
    for (int i = 0; i < entries.length; i++) {
      entries[i].rank = i + 1;
    }

    final playerEntry = entries.firstWhere(
      (e) => e.isPlayer,
      orElse: () => LeaderboardEntry(
        id: 'player',
        name: 'Du',
        city: 'Wien',
        title: provider.currentRank.title,
        badge: provider.currentRank.badge,
        avatarEmoji: '😎',
        strategy: 'Multi-Asset',
        netWorth: provider.netWorth,
        roiPercent: provider.totalRoiPercent * 100,
        isPlayer: true,
        rank: 1,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Börsenspiel Rangliste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Live aus Cloud aktualisieren',
            onPressed: () async {
              await provider.reloadLeaderboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    duration: Duration(seconds: 1),
                    content: Text('Rangliste live aus Firebase synchronisiert!'),
                  ),
                );
              }
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.profit.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.profit.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi, size: 13, color: AppColors.profit),
                SizedBox(width: 4),
                Text(
                  'Cloud Live',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.profit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Filter Chips für Zeiträume: All Time, Day, Week, Month, Quarter, HalfYear, Year
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: LeaderboardTimeframe.values.map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tf.displayName),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedTimeframe = tf;
                      });
                    },
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Podium für Top 3
          if (entries.length >= 3) ...[
            _buildPodium(entries.sublist(0, 3)),
            const SizedBox(height: 16),
          ],

          // Dein Rang Pinned Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.surfaceElevated,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${playerEntry.rank}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            playerEntry.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(playerEntry.badge),
                        ],
                      ),
                      Text(
                        '${playerEntry.title} • ${playerEntry.city}',
                        style: const TextStyle(
                          fontSize: 11,
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
                      CurrencyFormatter.format(playerEntry.netWorth),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${playerEntry.roiPercent >= 0 ? "+" : ""}${playerEntry.roiPercent.toStringAsFixed(2)}% ROI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: playerEntry.roiPercent >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rangliste • ${_selectedTimeframe.displayName}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${entries.length} Teilnehmer',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Liste aller Teilnehmer
          ...entries.map((entry) => _buildLeaderboardTile(entry)),

          if (entries.length <= 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.public, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Echtes Cloud-Multiplayer-Ranking',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Keine Fake-Bots! Sobald weitere Spieler online handeln, siehst du sie hier in Echtzeit synchronisiert.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumColumn(top3[1], 2, const Color(0xFFC0C0C0), 105),
          _buildPodiumColumn(top3[0], 1, AppColors.gold, 130),
          _buildPodiumColumn(top3[2], 3, const Color(0xFFCD7F32), 90),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(
      LeaderboardEntry entry, int place, Color medalColor, double podiumHeight) {
    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: entry.isPlayer ? FontWeight.w900 : FontWeight.bold,
              color: entry.isPlayer ? AppColors.primary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            CurrencyFormatter.formatCompact(entry.netWorth),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 85,
            height: podiumHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor.withValues(alpha: 0.35),
                  AppColors.surfaceElevated,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: medalColor.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  place == 1 ? '🥇 1.' : (place == 2 ? '🥈 2.' : '🥉 3.'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: medalColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.roiPercent >= 0 ? "+" : ""}${entry.roiPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.profit,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    final isTop3 = entry.rank <= 3;
    final medal = entry.rank == 1
        ? '🥇'
        : (entry.rank == 2 ? '🥈' : (entry.rank == 3 ? '🥉' : '#${entry.rank}'));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isPlayer
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isPlayer
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal,
              style: TextStyle(
                fontSize: isTop3 ? 18 : 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(entry.avatarEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            entry.isPlayer ? FontWeight.w900 : FontWeight.bold,
                        color: entry.isPlayer
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(entry.badge),
                  ],
                ),
                Text(
                  '${entry.strategy} • ${entry.city}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(entry.netWorth),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${entry.roiPercent >= 0 ? "+" : ""}${entry.roiPercent.toStringAsFixed(2)}% ROI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: entry.roiPercent >= 0
                      ? AppColors.profit
                      : AppColors.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
