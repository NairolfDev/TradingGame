enum SavingsPlanFrequency {
  daily,
  weekly,
  monthly;

  String get displayName {
    switch (this) {
      case SavingsPlanFrequency.daily:
        return 'Täglich';
      case SavingsPlanFrequency.weekly:
        return 'Wöchentlich';
      case SavingsPlanFrequency.monthly:
        return 'Monatlich';
    }
  }
}

class SavingsPlan {
  final String id;
  final String assetSymbol;
  final String assetName;
  final double amountEur;
  final SavingsPlanFrequency frequency;
  final DateTime createdAt;
  DateTime? lastExecutedAt;
  double totalInvested;
  bool isActive;

  SavingsPlan({
    required this.id,
    required this.assetSymbol,
    required this.assetName,
    required this.amountEur,
    required this.frequency,
    DateTime? createdAt,
    this.lastExecutedAt,
    this.totalInvested = 0.0,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetSymbol': assetSymbol,
        'assetName': assetName,
        'amountEur': amountEur,
        'frequency': frequency.name,
        'createdAt': createdAt.toIso8601String(),
        'lastExecutedAt': lastExecutedAt?.toIso8601String(),
        'totalInvested': totalInvested,
        'isActive': isActive,
      };

  factory SavingsPlan.fromJson(Map<String, dynamic> json) => SavingsPlan(
        id: json['id'] as String,
        assetSymbol: json['assetSymbol'] as String,
        assetName: json['assetName'] as String,
        amountEur: (json['amountEur'] as num).toDouble(),
        frequency: SavingsPlanFrequency.values.byName(json['frequency'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastExecutedAt: json['lastExecutedAt'] != null
            ? DateTime.parse(json['lastExecutedAt'] as String)
            : null,
        totalInvested: (json['totalInvested'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] as bool? ?? true,
      );
}
