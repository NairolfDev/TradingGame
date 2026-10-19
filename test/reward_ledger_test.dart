import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/reward_ledger.dart';
import 'package:trading_game/logic/achievement_service.dart';

/// Shared by "two devices" of one account.
class _Ledger implements RewardLedger {
  final paid = <String>{};
  bool offline = false;
  @override
  Future<ClaimResult> claim(String key) async {
    if (offline) return ClaimResult.failed;
    return paid.add(key) ? ClaimResult.granted : ClaimResult.alreadyClaimed;
  }

  @override
  Future<Set<String>> claimed() async => {...paid};
}

Future<void> check(AchievementService s) => s.checkAchievements(
  netWorth: 50000,
  totalTradesCount: 1,
  winningStreakCount: 0,
  totalPrestigePoints: 0,
  monthlyPassiveIncome: 0,
  hasDebt: false,
  ownedLuxuryCount: 0,
  hasCopyTrade: false,
  hasBotOrderTriggered: false,
  hasWonHighLeverage: false,
  leaderboardRank: 1,
  hasSettledSanierungskredit: false,
  hasTradedOffMarketCrypto: false,
);

void main() {
  test('an achievement pays out once across devices of one account', () async {
    final ledger = _Ledger();
    final paidOn = <String, List<String>>{'web': [], 'android': []};
    for (final device in paidOn.keys) {
      // Every device has its own local storage.
      SharedPreferences.setMockInitialValues({});
      final s = AchievementService()
        ..onAchievementUnlocked = (a) => paidOn[device]!.add(a.id);
      await s.initialize(profileId: 'uid1', ledger: ledger);
      await check(s);
    }
    expect(paidOn['web'], containsAll(['trade_first', 'top_10_global']));
    expect(paidOn['android'], isEmpty);
  });

  test('offline unlocks wait instead of paying twice later', () async {
    SharedPreferences.setMockInitialValues({});
    final ledger = _Ledger()..offline = true;
    final paid = <String>[];
    final s = AchievementService()..onAchievementUnlocked = (a) => paid.add(a.id);
    await s.initialize(profileId: 'uid2', ledger: ledger);
    await check(s);
    expect(paid, isEmpty);
    expect(s.unlockedCount, 0);
    ledger.offline = false;
    await check(s);
    expect(paid, contains('top_10_global'));
  });
}
