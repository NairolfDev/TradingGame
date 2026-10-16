import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
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
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Text('Wall Street Pass & Quests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  colors: [Colors.amber.shade900.withAlpha(120), AppColors.surfaceElevated],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withAlpha(100), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.amber, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            '$streakDays-Tage Trading-Streak!',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('AKTIV', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Handele täglich, um Login-Boni und exklusive Wall Street Belohnungen freizuschalten.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                              color: isUnlocked ? Colors.amber : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: isUnlocked ? Colors.amberAccent : Colors.white24),
                            ),
                            child: Icon(
                              isUnlocked ? Icons.check : Icons.lock,
                              size: 18,
                              color: isUnlocked ? Colors.black : Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tag $day',
                            style: TextStyle(
                              fontSize: 10,
                              color: isUnlocked ? Colors.amber : Colors.white38,
                              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tägliche Herausforderungen:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Reset: 24h',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
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
                        ? Colors.white12
                        : (isDone ? AppColors.primary : Colors.white10),
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
                            color: isDone ? AppColors.primary.withAlpha(30) : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDone ? Icons.verified : Icons.flag,
                            color: isDone ? AppColors.primary : Colors.white70,
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
                                  color: isClaimed ? Colors.white54 : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                quest.description,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: quest.progressRatio,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? AppColors.primary : Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.attach_money, size: 16, color: Colors.amber),
                            Text(
                              '+${quest.rewardCash.toStringAsFixed(0)} €',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.workspace_premium, size: 16, color: AppColors.primary),
                            Text(
                              '+${quest.rewardPrestige} Prestige',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                            ),
                          ],
                        ),
                        if (isClaimed)
                          const Text(
                            'Abgeholt ✓',
                            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
                          )
                        else if (isDone)
                          ElevatedButton(
                            onPressed: () {
                              portfolio.claimDailyQuest(quest.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text('🎁 Belohnung für "${quest.title}" erhalten!'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Belohnung abholen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else
                          Text(
                            '${quest.currentValue.toStringAsFixed(0)} / ${quest.targetValue.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
