import '../models/daily_quest.dart';

class InitialQuests {
  static List<DailyQuest> getDailyQuests() {
    return [
      DailyQuest(
        id: 'quest_1',
        title: '📈 Der agile Day-Trader',
        description: 'Führe heute mindestens 3 beliebige Trades an der Börse aus.',
        type: QuestType.tradeCount,
        targetValue: 3,
        currentValue: 0,
        rewardCash: 2500.0,
        rewardPrestige: 25,
        icon: 'trending_up',
      ),
      DailyQuest(
        id: 'quest_2',
        title: '🥇 Krisenschutz-Investor',
        description: 'Kaufe Gold, Silber oder ein anderes Edelmetall/Rohstoff im Wert von mind. 2.500 €.',
        type: QuestType.buyCommodity,
        targetValue: 2500.0,
        currentValue: 0,
        rewardCash: 1800.0,
        rewardPrestige: 30,
        icon: 'diamond',
      ),
      DailyQuest(
        id: 'quest_3',
        title: '⚡ Hebel-Meister',
        description: 'Eröffne eine CFD-Hebelposition mit mindestens 10-fachem Hebel.',
        type: QuestType.leverageTrade,
        targetValue: 1,
        currentValue: 0,
        rewardCash: 4000.0,
        rewardPrestige: 50,
        icon: 'flash_on',
      ),
      DailyQuest(
        id: 'quest_4',
        title: '💰 Profit-Jäger',
        description: 'Erziele heute mindestens 1.500 € realisierten Kursgewinn.',
        type: QuestType.profitGoal,
        targetValue: 1500.0,
        currentValue: 0,
        rewardCash: 3500.0,
        rewardPrestige: 40,
        icon: 'monetization_on',
      ),
      DailyQuest(
        id: 'quest_5',
        title: '🏦 Zins- & Dividenden-Sammler',
        description: 'Halte mindestens 2 verschiedene Aktien oder Anleihen in deinem Portfolio.',
        type: QuestType.holdAssets,
        targetValue: 2,
        currentValue: 0,
        rewardCash: 2000.0,
        rewardPrestige: 20,
        icon: 'account_balance',
      ),
    ];
  }
}
