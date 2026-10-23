import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/game_fx.dart';
import '../../logic/portfolio_provider.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final quests = portfolio.dailyQuests;
    final streakDays = portfolio.loginStreakDays;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.gold, size: 26),
            SizedBox(width: 8),
            Text(
              'Wall Street Pass & Quests',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Login Streak Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldDark.withAlpha(120),
                    AppColors.surfaceElevated,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gold.withAlpha(100),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: AppColors.gold,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$streakDays-Tage Trading-Streak!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'AKTIV',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Handele täglich, um Login-Boni und exklusive Wall Street Belohnungen freizuschalten.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      final isUnlocked = day <= streakDays;
                      return Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? AppColors.gold
                                  : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isUnlocked
                                    ? AppColors.gold
                                    : AppColors.textPrimary.withValues(
                                        alpha: 0.24,
                                      ),
                              ),
                            ),
                            child: Icon(
                              isUnlocked ? Icons.check : Icons.lock,
                              size: 18,
                              color: isUnlocked
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.38,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tag $day',
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnlocked
                                  ? AppColors.gold
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.38,
                                    ),
                              fontWeight: isUnlocked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Tägliche Missionen Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tägliche Herausforderungen:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withAlpha(80)),
                  ),
                  child: Text(
                    'Reset: 24h',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Jeden Tag 3 neue Aufgaben aus dem großen Quest-Pool',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // 3. Quests List
            ...quests.map((quest) {
              final isDone = quest.isCompleted;
              final isClaimed = quest.isClaimed;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isClaimed
                        ? AppColors.textPrimary.withValues(alpha: 0.12)
                        : (isDone
                              ? AppColors.primary
                              : AppColors.textPrimary.withValues(alpha: 0.1)),
                    width: isDone && !isClaimed ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.primary.withAlpha(30)
                                : AppColors.textPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDone ? Icons.verified : Icons.flag,
                            color: isDone
                                ? AppColors.primary
                                : AppColors.textPrimary.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isClaimed
                                      ? AppColors.textPrimary.withValues(
                                          alpha: 0.54,
                                        )
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                quest.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress Bar
                    GameProgressBar(
                      value: quest.progressRatio,
                      color: isDone ? AppColors.primary : AppColors.gold,
                      height: 6,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            Text(
                              '+${quest.rewardCash.toStringAsFixed(0)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.workspace_premium,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            Text(
                              '+${quest.rewardPrestige} Prestige',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (isClaimed)
                          Text(
                            'Abgeholt ✓',
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.38,
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        else if (isDone)
                          ElevatedButton(
                            onPressed: () {
                              portfolio.claimDailyQuest(quest.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text(
                                    '🎁 Belohnung für "${quest.title}" erhalten!',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Belohnung abholen',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Text(
                            '${quest.currentValue.toStringAsFixed(0)} / ${quest.targetValue.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.54,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // 4. Tages-Meisterbonus (3/3 Quests erledigt) Card
            Builder(
              builder: (context) {
                final completedCount =
                    quests.where((q) => q.isCompleted).length;
                final allDone = completedCount >= 3;
                final ratio = quests.isNotEmpty
                    ? (completedCount / quests.length).clamp(0.0, 1.0)
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withAlpha(allDone ? 60 : 25),
                        AppColors.surfaceElevated,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(allDone ? 180 : 70),
                      width: allDone ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                allDone ? '👑' : '🎯',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tages-Meisterbonus (3/3 Quests)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: allDone
                                  ? AppColors.gold.withAlpha(50)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: allDone
                                    ? AppColors.gold
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Text(
                              '$completedCount / 3 erledigt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: allDone
                                    ? AppColors.gold
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GameProgressBar(
                        value: ratio,
                        color: AppColors.gold,
                        height: 6,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        allDone
                            ? '🎉 Glückwunsch! Alle 3 Tages-Quests abgeschlossen – Extra-Cash & Prestige-Bonus gesichert!'
                            : 'Schließe heute alle 3 täglichen Quests ab, um einen automatischen Extra-Cash & Prestige-Bonus zu erhalten!',
                        style: TextStyle(
                          fontSize: 12,
                          color: allDone
                              ? AppColors.gold
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
