import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/achievement.dart';
import '../data/mock_data/initial_achievements.dart';
import '../data/repositories/reward_ledger.dart';

class AchievementService {
  static const String _keyBase = 'tg_achievements_v1';
  String _keyAchievements = _keyBase;
  RewardLedger _ledger = LocalRewardLedger();
  bool _checking = false;

  final List<Achievement> _achievements = [];
  void Function(Achievement achievement)? onAchievementUnlocked;

  List<Achievement> get achievements => List.unmodifiable(_achievements);
  int get unlockedCount => _achievements.where((a) => a.isUnlocked).length;
  int get totalCount => _achievements.length;

  /// [profileId] keeps each account's trophies apart on a shared device;
  /// [ledger] knows what this account was already paid on other devices.
  Future<void> initialize({
    String profileId = 'local',
    RewardLedger? ledger,
  }) async {
    _keyAchievements = profileId == 'local'
        ? _keyBase
        : '${_keyBase}_$profileId';
    _ledger = ledger ?? LocalRewardLedger();
    await _load();
    final paid = await _ledger.claimed();
    var changed = false;
    for (var i = 0; i < _achievements.length; i++) {
      final a = _achievements[i];
      // Trophies this device paid before the shared ledger existed are
      // registered now, so no other device pays them again.
      if (a.isUnlocked && !paid.contains('ach:${a.id}')) {
        await _ledger.claim('ach:${a.id}');
      }
      if (!a.isUnlocked && paid.contains('ach:${a.id}')) {
        _achievements[i] = a.copyWith(isUnlocked: true, progress: 1.0);
        changed = true;
      }
    }
    if (changed) await _saveAchievements();
  }

  Future<void> _load() async {
    _achievements.clear();
    final defaultList = InitialAchievements.getAchievements();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAchievements);

    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final savedMap = {
          for (var item in list)
            (item['id'] as String): Achievement.fromJson(
              item as Map<String, dynamic>,
            ),
        };

        for (final def in defaultList) {
          if (savedMap.containsKey(def.id)) {
            _achievements.add(savedMap[def.id]!);
          } else {
            _achievements.add(def);
          }
        }
        return;
      } catch (e) {
        debugPrint('Fehler beim Laden der Achievements: $e');
      }
    }

    _achievements.addAll(defaultList);
  }

  Future<void> checkAchievements({
    required double netWorth,
    required int totalTradesCount,
    required int winningStreakCount,
    required int totalPrestigePoints,
    required double monthlyPassiveIncome,
    required bool hasDebt,
    required int ownedLuxuryCount,
    required bool hasCopyTrade,
    required bool hasBotOrderTriggered,
    required bool hasWonHighLeverage,
    required int leaderboardRank,
    required bool hasSettledSanierungskredit,
    required bool hasTradedOffMarketCrypto,
    int uniqueAssetTypesCount = 0,
    int paidLoansCount = 0,
    int loginStreakDays = 1,
    bool hasDividendPayout = false,
    bool hasActiveSavingsPlanOrMultiBot = false,
  }) async {
    if (_checking) return;
    _checking = true;
    try {
      bool hasAnyNewUnlock = false;
      bool hasAnyProgressChange = false;

      for (int i = 0; i < _achievements.length; i++) {
        final ach = _achievements[i];
        if (ach.isUnlocked) continue;

        bool shouldUnlock = false;
        double newProgress = 0.0;

        switch (ach.id) {
          // 1. Original 15
          case 'trade_first':
            newProgress = (totalTradesCount / 1.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 1) shouldUnlock = true;
            break;
          case 'green_wave':
            newProgress = (winningStreakCount / 3.0).clamp(0.0, 1.0);
            if (winningStreakCount >= 3) shouldUnlock = true;
            break;
          case 'hundred_k':
            newProgress = (netWorth > 0 ? netWorth / 100000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 100000.0) shouldUnlock = true;
            break;
          case 'millionaire':
            newProgress = (netWorth > 0 ? netWorth / 1000000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 1000000.0) shouldUnlock = true;
            break;
          case 'diversified_portfolio':
            newProgress = (uniqueAssetTypesCount / 4.0).clamp(0.0, 1.0);
            if (uniqueAssetTypesCount >= 4) shouldUnlock = true;
            break;
          case 'high_leverage':
            newProgress = hasWonHighLeverage ? 1.0 : 0.0;
            if (hasWonHighLeverage) shouldUnlock = true;
            break;
          case 'debt_free':
            newProgress = (!hasDebt && totalTradesCount >= 2) ? 1.0 : (!hasDebt ? 0.5 : 0.0);
            if (!hasDebt && totalTradesCount >= 2) shouldUnlock = true;
            break;
          case 'good_taste':
            newProgress = (ownedLuxuryCount / 1.0).clamp(0.0, 1.0);
            if (ownedLuxuryCount >= 1) shouldUnlock = true;
            break;
          case 'prestige_king':
            newProgress = (totalPrestigePoints / 1000.0).clamp(0.0, 1.0);
            if (totalPrestigePoints >= 1000) shouldUnlock = true;
            break;
          case 'dividend_lord':
            newProgress = (monthlyPassiveIncome / 500.0).clamp(0.0, 1.0);
            if (monthlyPassiveIncome >= 500.0) shouldUnlock = true;
            break;
          case 'copy_master':
            newProgress = hasCopyTrade ? 1.0 : 0.0;
            if (hasCopyTrade) shouldUnlock = true;
            break;
          case 'comeback_kid':
            newProgress = hasSettledSanierungskredit ? 1.0 : 0.0;
            if (hasSettledSanierungskredit) shouldUnlock = true;
            break;
          case 'night_owl':
            newProgress = hasTradedOffMarketCrypto ? 1.0 : 0.0;
            if (hasTradedOffMarketCrypto) shouldUnlock = true;
            break;
          case 'bot_engineer':
            newProgress = hasBotOrderTriggered ? 1.0 : 0.0;
            if (hasBotOrderTriggered) shouldUnlock = true;
            break;
          case 'top_10_global':
            newProgress = (leaderboardRank > 0 && leaderboardRank <= 10) ? 1.0 : 0.0;
            if (leaderboardRank > 0 && leaderboardRank <= 10) {
              shouldUnlock = true;
            }
            break;

          // 2. Trading Count (5 Achievements)
          case 'trades_10':
            newProgress = (totalTradesCount / 10.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 10) shouldUnlock = true;
            break;
          case 'trades_25':
            newProgress = (totalTradesCount / 25.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 25) shouldUnlock = true;
            break;
          case 'trades_50':
            newProgress = (totalTradesCount / 50.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 50) shouldUnlock = true;
            break;
          case 'trades_100':
            newProgress = (totalTradesCount / 100.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 100) shouldUnlock = true;
            break;
          case 'trades_250':
            newProgress = (totalTradesCount / 250.0).clamp(0.0, 1.0);
            if (totalTradesCount >= 250) shouldUnlock = true;
            break;

          // 3. Win Streaks (3 Achievements)
          case 'streak_5':
            newProgress = (winningStreakCount / 5.0).clamp(0.0, 1.0);
            if (winningStreakCount >= 5) shouldUnlock = true;
            break;
          case 'streak_10':
            newProgress = (winningStreakCount / 10.0).clamp(0.0, 1.0);
            if (winningStreakCount >= 10) shouldUnlock = true;
            break;
          case 'streak_15':
            newProgress = (winningStreakCount / 15.0).clamp(0.0, 1.0);
            if (winningStreakCount >= 15) shouldUnlock = true;
            break;

          // 4. Wealth Milestones (8 Achievements)
          case 'wealth_50k':
            newProgress = (netWorth > 0 ? netWorth / 50000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 50000.0) shouldUnlock = true;
            break;
          case 'wealth_250k':
            newProgress = (netWorth > 0 ? netWorth / 250000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 250000.0) shouldUnlock = true;
            break;
          case 'wealth_500k':
            newProgress = (netWorth > 0 ? netWorth / 500000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 500000.0) shouldUnlock = true;
            break;
          case 'wealth_2_5m':
            newProgress = (netWorth > 0 ? netWorth / 2500000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 2500000.0) shouldUnlock = true;
            break;
          case 'wealth_10m':
            newProgress = (netWorth > 0 ? netWorth / 10000000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 10000000.0) shouldUnlock = true;
            break;
          case 'wealth_50m':
            newProgress = (netWorth > 0 ? netWorth / 50000000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 50000000.0) shouldUnlock = true;
            break;
          case 'wealth_100m':
            newProgress = (netWorth > 0 ? netWorth / 100000000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 100000000.0) shouldUnlock = true;
            break;
          case 'wealth_1b':
            newProgress = (netWorth > 0 ? netWorth / 1000000000.0 : 0.0).clamp(0.0, 1.0);
            if (netWorth >= 1000000000.0) shouldUnlock = true;
            break;

          // 5. Dividends (4 Achievements)
          case 'div_first':
            newProgress = (hasDividendPayout || monthlyPassiveIncome > 0) ? 1.0 : 0.0;
            if (hasDividendPayout || monthlyPassiveIncome > 0) shouldUnlock = true;
            break;
          case 'div_100_mo':
            newProgress = (monthlyPassiveIncome / 100.0).clamp(0.0, 1.0);
            if (monthlyPassiveIncome >= 100.0) shouldUnlock = true;
            break;
          case 'div_2500_mo':
            newProgress = (monthlyPassiveIncome / 2500.0).clamp(0.0, 1.0);
            if (monthlyPassiveIncome >= 2500.0) shouldUnlock = true;
            break;
          case 'div_10000_mo':
            newProgress = (monthlyPassiveIncome / 10000.0).clamp(0.0, 1.0);
            if (monthlyPassiveIncome >= 10000.0) shouldUnlock = true;
            break;

          // 6. Luxury & Prestige (7 Achievements)
          case 'luxury_3':
            newProgress = (ownedLuxuryCount / 3.0).clamp(0.0, 1.0);
            if (ownedLuxuryCount >= 3) shouldUnlock = true;
            break;
          case 'luxury_5':
            newProgress = (ownedLuxuryCount / 5.0).clamp(0.0, 1.0);
            if (ownedLuxuryCount >= 5) shouldUnlock = true;
            break;
          case 'luxury_10':
            newProgress = (ownedLuxuryCount / 10.0).clamp(0.0, 1.0);
            if (ownedLuxuryCount >= 10) shouldUnlock = true;
            break;
          case 'luxury_20':
            newProgress = (ownedLuxuryCount / 20.0).clamp(0.0, 1.0);
            if (ownedLuxuryCount >= 20) shouldUnlock = true;
            break;
          case 'prestige_10k':
            newProgress = (totalPrestigePoints / 10000.0).clamp(0.0, 1.0);
            if (totalPrestigePoints >= 10000) shouldUnlock = true;
            break;
          case 'prestige_100k':
            newProgress = (totalPrestigePoints / 100000.0).clamp(0.0, 1.0);
            if (totalPrestigePoints >= 100000) shouldUnlock = true;
            break;
          case 'prestige_1m':
            newProgress = (totalPrestigePoints / 1000000.0).clamp(0.0, 1.0);
            if (totalPrestigePoints >= 1000000) shouldUnlock = true;
            break;

          // 7. Banking, Quests & Automation (3 Achievements)
          case 'loans_repaid_3':
            newProgress = (paidLoansCount / 3.0).clamp(0.0, 1.0);
            if (paidLoansCount >= 3) shouldUnlock = true;
            break;
          case 'streak_login_7':
            newProgress = (loginStreakDays / 7.0).clamp(0.0, 1.0);
            if (loginStreakDays >= 7) shouldUnlock = true;
            break;
          case 'savings_plan_active':
            newProgress = hasActiveSavingsPlanOrMultiBot ? 1.0 : 0.0;
            if (hasActiveSavingsPlanOrMultiBot) shouldUnlock = true;
            break;
        }

        if (shouldUnlock) {
          // Paid once per account: another device may have paid it already.
          final result = await _ledger.claim('ach:${ach.id}');
          if (result == ClaimResult.failed) continue;
          _achievements[i] = ach.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
            progress: 1.0,
          );
          hasAnyNewUnlock = true;
          if (result == ClaimResult.granted) {
            onAchievementUnlocked?.call(_achievements[i]);
          }
        } else if ((ach.progress - newProgress).abs() > 0.0001) {
          _achievements[i] = ach.copyWith(progress: newProgress);
          hasAnyProgressChange = true;
        }
      }

      if (hasAnyNewUnlock || hasAnyProgressChange) {
        await _saveAchievements();
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_achievements.map((a) => a.toJson()).toList());
    await prefs.setString(_keyAchievements, raw);
  }
}
