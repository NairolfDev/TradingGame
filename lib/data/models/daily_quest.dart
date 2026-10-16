enum QuestType {
  tradeCount,
  profitGoal,
  leverageTrade,
  buyCommodity,
  holdAssets,
  loginStreak;
}

class DailyQuest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final double targetValue;
  double currentValue;
  final double rewardCash;
  final int rewardPrestige;
  final String icon;
  bool isClaimed;

  DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.rewardCash,
    required this.rewardPrestige,
    required this.icon,
    this.isClaimed = false,
  });

  bool get isCompleted => currentValue >= targetValue;

  double get progressRatio =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'rewardCash': rewardCash,
        'rewardPrestige': rewardPrestige,
        'icon': icon,
        'isClaimed': isClaimed,
      };

  factory DailyQuest.fromJson(Map<String, dynamic> json) => DailyQuest(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: QuestType.values.byName(json['type'] as String),
        targetValue: (json['targetValue'] as num).toDouble(),
        currentValue: (json['currentValue'] as num).toDouble(),
        rewardCash: (json['rewardCash'] as num).toDouble(),
        rewardPrestige: (json['rewardPrestige'] as num).toInt(),
        icon: json['icon'] as String,
        isClaimed: json['isClaimed'] as bool? ?? false,
      );
}
