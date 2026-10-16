class CopyTrader {
  final String id;
  final String name;
  final String title;
  final String avatarEmoji;
  final double netWorth;
  final double roiPercent;
  final double winRatePercent;
  final String bio;
  final String riskStyle; // 'Konservativ', 'Ausgewogen', 'Aggressiv', 'Krypto-Whale'
  final Map<String, double> portfolioAllocation; // z.B. {'XAU/EUR': 0.40, 'BTC': 0.35, ...}
  final int followersCount;

  const CopyTrader({
    required this.id,
    required this.name,
    required this.title,
    required this.avatarEmoji,
    required this.netWorth,
    required this.roiPercent,
    required this.winRatePercent,
    required this.bio,
    required this.riskStyle,
    required this.portfolioAllocation,
    required this.followersCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'avatarEmoji': avatarEmoji,
        'netWorth': netWorth,
        'roiPercent': roiPercent,
        'winRatePercent': winRatePercent,
        'bio': bio,
        'riskStyle': riskStyle,
        'portfolioAllocation': portfolioAllocation,
        'followersCount': followersCount,
      };

  factory CopyTrader.fromJson(Map<String, dynamic> json) => CopyTrader(
        id: json['id'] as String,
        name: json['name'] as String,
        title: json['title'] as String,
        avatarEmoji: json['avatarEmoji'] as String,
        netWorth: (json['netWorth'] as num).toDouble(),
        roiPercent: (json['roiPercent'] as num).toDouble(),
        winRatePercent: (json['winRatePercent'] as num).toDouble(),
        bio: json['bio'] as String,
        riskStyle: json['riskStyle'] as String,
        portfolioAllocation: Map<String, double>.from(
            (json['portfolioAllocation'] as Map<dynamic, dynamic>)
                .map((k, v) => MapEntry(k as String, (v as num).toDouble()))),
        followersCount: (json['followersCount'] as num).toInt(),
      );
}
