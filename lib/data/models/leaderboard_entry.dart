class LeaderboardEntry {
  final String id;
  final String name;
  final String city;
  final String title;
  final String badge;
  final String avatarEmoji;
  final String strategy;
  double netWorth;
  double roiPercent;
  double? weeklyRoiPercent;
  double? monthlyRoiPercent;
  final bool isPlayer;
  int rank;
  int luxuryCount;

  LeaderboardEntry({
    required this.id,
    required this.name,
    required this.city,
    required this.title,
    required this.badge,
    required this.avatarEmoji,
    required this.strategy,
    required this.netWorth,
    required this.roiPercent,
    this.weeklyRoiPercent,
    this.monthlyRoiPercent,
    this.isPlayer = false,
    this.rank = 0,
    this.luxuryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'title': title,
        'badge': badge,
        'avatarEmoji': avatarEmoji,
        'strategy': strategy,
        'netWorth': netWorth,
        'roiPercent': roiPercent,
        if (weeklyRoiPercent != null) 'weeklyRoiPercent': weeklyRoiPercent,
        if (monthlyRoiPercent != null) 'monthlyRoiPercent': monthlyRoiPercent,
        'isPlayer': isPlayer,
        'rank': rank,
        'luxuryCount': luxuryCount,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        title: json['title'] as String,
        badge: json['badge'] as String,
        avatarEmoji: json['avatarEmoji'] as String,
        strategy: json['strategy'] as String,
        netWorth: (json['netWorth'] as num).toDouble(),
        roiPercent: (json['roiPercent'] as num).toDouble(),
        weeklyRoiPercent: (json['weeklyRoiPercent'] as num?)?.toDouble(),
        monthlyRoiPercent: (json['monthlyRoiPercent'] as num?)?.toDouble(),
        isPlayer: json['isPlayer'] as bool? ?? false,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        luxuryCount: (json['luxuryCount'] as num?)?.toInt() ?? 0,
      );
}
