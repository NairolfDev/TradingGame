import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/empty_state.dart';

/// Entries sorted by net worth or ROI with ranks 1..n. The player's own row
/// shows live metrics; if the player is not listed yet, a row is added.
List<LeaderboardEntry> rankLeaderboard(
  List<LeaderboardEntry> base, {
  required double playerNetWorth,
  required double playerRoiPercent,
  required String playerCity,
  required String playerTitle,
  required String playerBadge,
  bool includePlayer = true,
  double? playerWeeklyRoiPercent,
  double? playerMonthlyRoiPercent,
  String mode = 'allTime',
}) {
  final entries = [
    for (final e in base)
      if (includePlayer || !e.isPlayer)
        LeaderboardEntry(
          id: e.id,
          name: e.isPlayer ? _ownName(e.name) : e.name,
          city: e.city,
          title: e.title,
          badge: e.badge,
          avatarEmoji: e.avatarEmoji,
          strategy: e.strategy,
          netWorth: e.isPlayer ? playerNetWorth : e.netWorth,
          roiPercent: e.isPlayer && playerRoiPercent != 0
              ? playerRoiPercent
              : e.roiPercent,
          weeklyRoiPercent: e.isPlayer
              ? (playerWeeklyRoiPercent ?? e.weeklyRoiPercent)
              : e.weeklyRoiPercent,
          monthlyRoiPercent: e.isPlayer
              ? (playerMonthlyRoiPercent ?? e.monthlyRoiPercent)
              : e.monthlyRoiPercent,
          isPlayer: e.isPlayer,
          luxuryCount: e.luxuryCount,
        ),
  ];
  if (includePlayer && !entries.any((e) => e.isPlayer)) {
    entries.add(
      LeaderboardEntry(
        id: 'player',
        name: 'Du',
        city: playerCity,
        title: playerTitle,
        badge: playerBadge,
        avatarEmoji: '😎',
        strategy: 'Multi-Asset',
        netWorth: playerNetWorth,
        roiPercent: playerRoiPercent,
        weeklyRoiPercent: playerWeeklyRoiPercent,
        monthlyRoiPercent: playerMonthlyRoiPercent,
        isPlayer: true,
      ),
    );
  }
  if (mode == 'weekly') {
    entries.sort((a, b) {
      final aVal = a.weeklyRoiPercent ?? a.roiPercent;
      final bVal = b.weeklyRoiPercent ?? b.roiPercent;
      return bVal.compareTo(aVal);
    });
  } else if (mode == 'monthly') {
    entries.sort((a, b) {
      final aVal = a.monthlyRoiPercent ?? a.roiPercent;
      final bVal = b.monthlyRoiPercent ?? b.roiPercent;
      return bVal.compareTo(aVal);
    });
  } else {
    entries.sort((a, b) => b.netWorth.compareTo(a.netWorth));
  }
  for (var i = 0; i < entries.length; i++) {
    entries[i].rank = i + 1;
  }
  return entries;
}

/// The repository labels the player's row "Du (Name)"; the row gets a "Du"
/// chip instead, so only the name stays.
String _ownName(String name) {
  final m = RegExp(r'^Du \((.+)\)$').firstMatch(name);
  return m?.group(1) ?? name;
}

String _roiText(double roi, {int digits = 2}) =>
    '${roi >= 0 ? '+' : '−'}${roi.abs().toStringAsFixed(digits)} %';

Color _medal(int rank) => switch (rank) {
  1 => AppColors.gold,
  2 => AppColors.accent,
  3 => AppColors.warning,
  _ => AppColors.textSecondary,
};

Color _roiColor(double roi) => roi >= 0 ? AppColors.profit : AppColors.loss;

double _displayRoi(LeaderboardEntry e, String mode) => switch (mode) {
  'weekly' => e.weeklyRoiPercent ?? e.roiPercent,
  'monthly' => e.monthlyRoiPercent ?? e.roiPercent,
  _ => e.roiPercent,
};

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _mode = 'allTime';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final entries = rankLeaderboard(
      provider.leaderboard,
      playerNetWorth: provider.netWorth,
      playerRoiPercent: provider.totalRoiPercent * 100,
      playerWeeklyRoiPercent: provider.weeklyRoiPercent,
      playerMonthlyRoiPercent: provider.monthlyRoiPercent,
      playerCity: provider.playerCountry,
      playerTitle: provider.currentRank.title,
      playerBadge: provider.currentRank.badge,
      includePlayer: provider.isOnLeaderboard,
      mode: _mode,
    );
    final me = entries.where((e) => e.isPlayer).firstOrNull;

    Future<void> reload() async {
      await provider.reloadLeaderboard();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Rangliste aktualisiert.'),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rangliste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rangliste aktualisieren',
            onPressed: reload,
          ),
        ],
      ),
      body: entries.isEmpty || (entries.length < 2 && me != null)
          ? EmptyState(
              icon: Icons.groups_outlined,
              title: 'Noch keine Mitspieler',
              message:
                  'Sobald weitere angemeldete Spieler handeln, erscheinen sie hier.',
              actionLabel: 'Aktualisieren',
              onAction: reload,
            )
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Gesamt'),
                          selected: _mode == 'allTime',
                          onSelected: (selected) {
                            if (selected) setState(() => _mode = 'allTime');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Wochen-Liga (7T)'),
                          selected: _mode == 'weekly',
                          onSelected: (selected) {
                            if (selected) setState(() => _mode = 'weekly');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Monats-Liga (30T)'),
                          selected: _mode == 'monthly',
                          onSelected: (selected) {
                            if (selected) setState(() => _mode = 'monthly');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (me != null)
                    _MyRankCard(me: me, total: entries.length, mode: _mode)
                  else
                    const _JoinHint(),
                  const SizedBox(height: 16),
                  if (entries.length >= 3) ...[
                    _Podium(top3: entries.take(3).toList(), mode: _mode),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _mode == 'weekly'
                              ? 'Wochen-Liga (7 Tage)'
                              : _mode == 'monthly'
                                  ? 'Monats-Liga (30 Tage)'
                                  : 'Gesamtrendite seit Spielstart',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${entries.length} Spieler',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final e in entries) _Tile(entry: e, mode: _mode),
                ],
              ),
            ),
    );
  }
}

class _JoinHint extends StatelessWidget {
  const _JoinHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(
      children: [
        Icon(Icons.lock_outline, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Melde dich an und wähle einen Namen, um in der Rangliste zu erscheinen. Gäste werden nicht gelistet.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _MyRankCard extends StatelessWidget {
  final LeaderboardEntry me;
  final int total;
  final String mode;
  const _MyRankCard({
    required this.me,
    required this.total,
    this.mode = 'allTime',
  });

  @override
  Widget build(BuildContext context) {
    final roi = _displayRoi(me, mode);
    return Semantics(
      container: true,
      label:
          'Dein Rang: Platz ${me.rank} von $total, ${CurrencyFormatter.format(me.netWorth)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dein Rang',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Platz ${me.rank} von $total',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${me.title} · ${me.city}',
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(me.netWorth),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _roiText(roi),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _roiColor(roi),
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

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final String mode;
  const _Podium({required this.top3, this.mode = 'allTime'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumColumn(entry: top3[1], height: 96, mode: mode),
          ),
          Expanded(
            child: _PodiumColumn(entry: top3[0], height: 124, mode: mode),
          ),
          Expanded(
            child: _PodiumColumn(entry: top3[2], height: 80, mode: mode),
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final String mode;
  const _PodiumColumn({
    required this.entry,
    required this.height,
    this.mode = 'allTime',
  });

  @override
  Widget build(BuildContext context) {
    final color = _medal(entry.rank);
    final roi = _displayRoi(entry, mode);
    return Semantics(
      label:
          'Platz ${entry.rank}: ${entry.name}, ${CurrencyFormatter.format(entry.netWorth)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: entry.isPlayer
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            CurrencyFormatter.formatCompact(entry.netWorth),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.rank}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  _roiText(roi, digits: 1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _roiColor(roi),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final LeaderboardEntry entry;
  final String mode;
  const _Tile({required this.entry, this.mode = 'allTime'});

  @override
  Widget build(BuildContext context) {
    final me = entry.isPlayer;
    final roi = _displayRoi(entry, mode);
    return Semantics(
      container: true,
      label:
          'Platz ${entry.rank}: ${entry.name}${me ? ' (du)' : ''}, ${CurrencyFormatter.format(entry.netWorth)}, ${_roiText(roi)}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: me
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: me
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: entry.rank <= 3 ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: _medal(entry.rank),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(entry.avatarEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: me
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (me) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Du',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${entry.title} · ${entry.city}',
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
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(entry.netWorth),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _roiText(roi),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _roiColor(roi),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
