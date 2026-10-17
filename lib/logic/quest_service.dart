import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data/initial_quests.dart';
import '../data/models/daily_quest.dart';

class QuestService {
  final List<DailyQuest> _quests = [];
  int _loginStreakDays = 1;
  SharedPreferences? _prefs;
  String? _day;
  String _stateKey = 'tg_daily_quest_state';

  List<DailyQuest> get quests => List.unmodifiable(_quests);
  int get loginStreakDays => _loginStreakDays;

  Future<void> initialize({String profileId = 'local'}) async {
    _stateKey = profileId == 'local' ? 'tg_daily_quest_state' : 'tg_${profileId}_daily_quest_state';
    _day = null;
    _loginStreakDays = 1;
    _prefs = await SharedPreferences.getInstance();
    _quests.clear();
    _quests.addAll(InitialQuests.getDailyQuests());
    try {
      final raw = _prefs!.getString(_stateKey);
      if (raw != null) {
        final state = jsonDecode(raw) as Map<String, dynamic>;
        _day = state['day'] as String?;
        _loginStreakDays = (state['streak'] as num?)?.toInt() ?? 1;
        final progress = state['quests'] as Map<String, dynamic>? ?? {};
        for (final quest in _quests) {
          final saved = progress[quest.id] as Map<String, dynamic>?;
          quest.currentValue = (saved?['value'] as num?)?.toDouble() ?? 0;
          quest.isClaimed = saved?['claimed'] as bool? ?? false;
        }
      }
    } catch (_) {
      _day = null;
      _loginStreakDays = 1;
    }
    _refreshDay();
    _save();
  }

  void _refreshDay() {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = today.toIso8601String();
    if (_day == day) return;
    final previous = _day == null ? null : DateTime.tryParse(_day!);
    _loginStreakDays =
        previous != null && today.difference(previous).inDays == 1
        ? _loginStreakDays + 1
        : 1;
    _day = day;
    for (final quest in _quests) {
      quest.currentValue = 0;
      quest.isClaimed = false;
    }
  }

  void _save() {
    _prefs?.setString(
      _stateKey,
      jsonEncode({
        'day': _day,
        'streak': _loginStreakDays,
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

  int get completedCount => _quests.where((q) => q.isCompleted).length;
  int get totalCount => _quests.length;
}
