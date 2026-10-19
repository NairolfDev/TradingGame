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
  }) async {
    if (_checking) return;
    _checking = true;
    try {
      bool hasAnyNewUnlock = false;

      for (int i = 0; i < _achievements.length; i++) {
        final ach = _achievements[i];
        if (ach.isUnlocked) continue;

        bool shouldUnlock = false;

        switch (ach.id) {
          case 'trade_first':
            if (totalTradesCount >= 1) shouldUnlock = true;
            break;
          case 'green_wave':
            if (winningStreakCount >= 3) shouldUnlock = true;
            break;
          case 'hundred_k':
            if (netWorth >= 100000.0) shouldUnlock = true;
            break;
          case 'millionaire':
            if (netWorth >= 1000000.0) shouldUnlock = true;
            break;
          case 'diversified_portfolio':
            if (uniqueAssetTypesCount >= 4) shouldUnlock = true;
            break;
          case 'high_leverage':
            if (hasWonHighLeverage) shouldUnlock = true;
            break;
          case 'debt_free':
            if (!hasDebt && totalTradesCount >= 2) shouldUnlock = true;
            break;
          case 'good_taste':
            if (ownedLuxuryCount >= 1) shouldUnlock = true;
            break;
          case 'prestige_king':
            if (totalPrestigePoints >= 1000) shouldUnlock = true;
            break;
          case 'dividend_lord':
            if (monthlyPassiveIncome >= 500.0) shouldUnlock = true;
            break;
          case 'copy_master':
            if (hasCopyTrade) shouldUnlock = true;
            break;
          case 'comeback_kid':
            if (hasSettledSanierungskredit) shouldUnlock = true;
            break;
          case 'night_owl':
            if (hasTradedOffMarketCrypto) shouldUnlock = true;
            break;
          case 'bot_engineer':
            if (hasBotOrderTriggered) shouldUnlock = true;
            break;
          case 'top_10_global':
            if (leaderboardRank > 0 && leaderboardRank <= 10) {
              shouldUnlock = true;
            }
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
        }
      }

      if (hasAnyNewUnlock) {
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
