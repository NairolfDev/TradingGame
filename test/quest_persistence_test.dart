import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/daily_quest.dart';
import 'package:trading_game/logic/quest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('quest progress and claimed rewards are isolated between profiles', () async {
    final service = QuestService();
    await service.initialize(profileId: 'alice');
    service.recordTrade(tradeAmount: 100, isCommodity: false, leverage: 1,
      profit: 0, totalPositionsCount: 3);
    final quest = service.quests.firstWhere((q) => q.type == QuestType.holdAssets);
    expect(service.claimQuest(quest.id, (_, _) {}), isTrue);
    await service.initialize(profileId: 'bob');
    expect(service.quests.firstWhere((q) => q.id == quest.id).isClaimed, isFalse);
    expect(service.quests.first.currentValue, 0);
    await service.initialize(profileId: 'alice');
    expect(service.quests.firstWhere((q) => q.id == quest.id).isClaimed, isTrue);
  });

  test(
    'restarting preserves quest progress and prevents claiming twice',
    () async {
      final service = QuestService();
      await service.initialize();
      service.recordTrade(
        tradeAmount: 1000,
        isCommodity: false,
        leverage: 1,
        profit: 0,
        totalPositionsCount: 3,
      );
      final quest = service.quests.firstWhere(
        (q) => q.type == QuestType.holdAssets,
      );
      expect(service.claimQuest(quest.id, (_, _) {}), isTrue);
      final restarted = QuestService();
      await restarted.initialize();
      expect(
        restarted.claimQuest(quest.id, (_, _) => fail('Duplicate reward')),
        isFalse,
      );
      expect(
        restarted.quests
            .firstWhere((q) => q.type == QuestType.tradeCount)
            .currentValue,
        1,
      );
      expect(restarted.loginStreakDays, 1);
    },
  );

  test(
    'a new calendar day resets quests and advances actual login streak',
    () async {
      final now = DateTime.now();
      final yesterday = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'tg_daily_quest_state': jsonEncode({
          'day': yesterday.toIso8601String(),
          'streak': 2,
          'quests': {
            'quest_1': {'value': 3, 'claimed': true},
          },
        }),
      });
      final service = QuestService();
      await service.initialize();
      expect(service.loginStreakDays, 3);
      expect(service.quests.first.currentValue, 0);
      expect(service.quests.first.isClaimed, isFalse);
    },
  );
}
