import '../data/mock_data/initial_quests.dart';
import '../data/models/daily_quest.dart';

class QuestService {
  final List<DailyQuest> _quests = [];
  int _loginStreakDays = 3;

  List<DailyQuest> get quests => List.unmodifiable(_quests);
  int get loginStreakDays => _loginStreakDays;

  void incrementStreak() {
    _loginStreakDays++;
  }

  void initialize() {
    if (_quests.isEmpty) {
      _quests.addAll(InitialQuests.getDailyQuests());
    }
  }

  void recordTrade({
    required double tradeAmount,
    required bool isCommodity,
    required int leverage,
    required double profit,
    required int totalPositionsCount,
  }) {
    for (final quest in _quests) {
      if (quest.isCompleted) continue;

      switch (quest.type) {
        case QuestType.tradeCount:
          quest.currentValue += 1;
          break;
        case QuestType.buyCommodity:
          if (isCommodity) {
            quest.currentValue += tradeAmount;
          }
          break;
        case QuestType.leverageTrade:
          if (leverage >= 10) {
            quest.currentValue += 1;
          }
          break;
        case QuestType.profitGoal:
          if (profit > 0) {
            quest.currentValue += profit;
          }
          break;
        case QuestType.holdAssets:
          quest.currentValue = totalPositionsCount.toDouble();
          break;
        case QuestType.loginStreak:
          quest.currentValue = _loginStreakDays.toDouble();
          break;
      }
    }
  }

  bool claimQuest(String questId, void Function(double cash, int prestige) onReward) {
    final quest = _quests.where((q) => q.id == questId).firstOrNull;
    if (quest == null) return false;

    if (quest.isCompleted && !quest.isClaimed) {
      quest.isClaimed = true;
      onReward(quest.rewardCash, quest.rewardPrestige);
      return true;
    }
    return false;
  }

  int get completedCount => _quests.where((q) => q.isCompleted).length;
  int get totalCount => _quests.length;
}
