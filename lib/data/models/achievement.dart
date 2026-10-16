class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconEmoji;
  final double cashReward;
  final int prestigeReward;
  bool isUnlocked;
  DateTime? unlockedAt;
  final double progress; // 0.0 bis 1.0

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconEmoji,
    required this.cashReward,
    required this.prestigeReward,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'iconEmoji': iconEmoji,
        'cashReward': cashReward,
        'prestigeReward': prestigeReward,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'progress': progress,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        iconEmoji: json['iconEmoji'] as String,
        cashReward: (json['cashReward'] as num).toDouble(),
        prestigeReward: (json['prestigeReward'] as num).toInt(),
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      );

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      iconEmoji: iconEmoji,
      cashReward: cashReward,
      prestigeReward: prestigeReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }
}
