import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data/initial_quests.dart';
import '../data/models/daily_quest.dart';

class QuestService {
  final List<DailyQuest> _quests = [];
  int _loginStreakDays = 1;
  int _rotationIndex = 0;
  bool _dailyBonusClaimed = false;
  SharedPreferences? _prefs;
  String? _day;
  String _stateKey = 'tg_daily_quest_state';

  List<DailyQuest> get quests => List.unmodifiable(_quests);
  int get loginStreakDays => _loginStreakDays;
  int get rotationIndex => _rotationIndex;

  bool get isAllDailyQuestsCompleted =>
      _quests.isNotEmpty && _quests.every((q) => q.isCompleted);
  bool get isDailySweepBonusClaimed => _dailyBonusClaimed;
  double get dailySweepBonusCash => 3000.0 + (_loginStreakDays * 500.0);
  int get dailySweepBonusPrestige => 40 + (_loginStreakDays * 10);

  Future<void> initialize({String profileId = 'local'}) async {
    _stateKey = profileId == 'local'
        ? 'tg_daily_quest_state'
        : 'tg_${profileId}_daily_quest_state';
    _day = null;
    _loginStreakDays = 1;
    _rotationIndex = 0;
    _dailyBonusClaimed = false;
    _prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? progressMap;
    try {
      final raw = _prefs!.getString(_stateKey);
      if (raw != null) {
        final state = jsonDecode(raw) as Map<String, dynamic>;
        _day = state['day'] as String?;
        _loginStreakDays = (state['streak'] as num?)?.toInt() ?? 1;
        _rotationIndex = (state['rotationIndex'] as num?)?.toInt() ?? 0;
        _dailyBonusClaimed = state['dailyBonusClaimed'] as bool? ?? false;
        progressMap = state['quests'] as Map<String, dynamic>?;
      }
    } catch (_) {
      _day = null;
      _loginStreakDays = 1;
      _rotationIndex = 0;
      _dailyBonusClaimed = false;
    }

    _refreshDay();

    _quests.clear();
    _quests.addAll(InitialQuests.getDailyQuests(daySeed: _rotationIndex));

    if (progressMap != null) {
      for (final quest in _quests) {
        final saved = progressMap[quest.id] as Map<String, dynamic>?;
        if (saved != null) {
          quest.currentValue = (saved['value'] as num?)?.toDouble() ?? 0;
          quest.isClaimed = saved['claimed'] as bool? ?? false;
        }
      }
    }

    for (final quest in _quests) {
      if (quest.type == QuestType.loginStreak && quest.currentValue < _loginStreakDays) {
        quest.currentValue = _loginStreakDays.toDouble();
      }
    }

    _save();
  }

  void _refreshDay() {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = today.toIso8601String();
    if (_day == day) return;

    final previous = _day == null ? null : DateTime.tryParse(_day!);
    if (_day != null) {
      _rotationIndex += 1;
      _dailyBonusClaimed = false;
    }

    _loginStreakDays =
        previous != null && today.difference(previous).inDays == 1
            ? _loginStreakDays + 1
            : 1;
    _day = day;

    _quests.clear();
    _quests.addAll(InitialQuests.getDailyQuests(daySeed: _rotationIndex));
  }

  void _save() {
    _prefs?.setString(
      _stateKey,
      jsonEncode({
        'day': _day,
        'streak': _loginStreakDays,
        'rotationIndex': _rotationIndex,
        'dailyBonusClaimed': _dailyBonusClaimed,
        'quests': {
          for (final q in _quests)
            q.id: {'value': q.currentValue, 'claimed': q.isClaimed},
        },
      }),
    );
  }

  void recordTrade({
    required double tradeAmount,
    required bool isCommodity,
    required int leverage,
    required double profit,
    required int totalPositionsCount,
  }) {
    _refreshDay();
    for (final quest in _quests) {
      if (quest.isCompleted) continue;

      switch (quest.type) {
        case QuestType.tradeCount:
          if (tradeAmount > 0 && tradeAmount.isFinite) {
            quest.currentValue += 1;
          }
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
    _save();
  }

  bool claimQuest(
    String questId,
    void Function(double cash, int prestige) onReward,
  ) {
    _refreshDay();
    final quest = _quests.where((q) => q.id == questId).firstOrNull;
    if (quest == null) return false;

    if (quest.isCompleted && !quest.isClaimed) {
      quest.isClaimed = true;
      _save();
      onReward(quest.rewardCash, quest.rewardPrestige);
      return true;
    }
    return false;
  }

  bool claimDailySweepBonus(void Function(double cash, int prestige) onReward) {
    _refreshDay();
    if (isAllDailyQuestsCompleted && !_dailyBonusClaimed) {
      _dailyBonusClaimed = true;
      _save();
      onReward(dailySweepBonusCash, dailySweepBonusPrestige);
      return true;
    }
    return false;
  }

  /// UTC day of the current quest set, part of the reward key.
  String get dayKey {
    _refreshDay();
    return _day!.substring(0, 10);
  }

  bool canClaim(String questId) {
    _refreshDay();
    final q = _quests.where((q) => q.id == questId).firstOrNull;
    return q != null && q.isCompleted && !q.isClaimed;
  }

  /// Marks quests as claimed that another device already paid out today.
  void markClaimed(Iterable<String> questIds) {
    _refreshDay();
    for (final q in _quests) {
      if (questIds.contains(q.id)) q.isClaimed = true;
    }
    _save();
  }

  int get completedCount => _quests.where((q) => q.isCompleted).length;
  int get totalCount => _quests.length;
}
