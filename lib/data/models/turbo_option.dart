enum TurboDirection {
  call, // Höher
  put;  // Tiefer
}

class TurboOption {
  final String id;
  final String assetSymbol;
  final String assetName;
  final double entryPrice;
  final TurboDirection direction;
  final double stake;
  final int durationSeconds; // 30 oder 60 Sekunden
  final DateTime startedAt;
  final DateTime endsAt;
  final double payoutMultiplier; // z. B. 1.85 für 85% Gewinn
  double? finalPrice;
  bool isSettled;
  bool isWon;

  TurboOption({
    required this.id,
    required this.assetSymbol,
    required this.assetName,
    required this.entryPrice,
    required this.direction,
    required this.stake,
    required this.durationSeconds,
    required this.startedAt,
    required this.endsAt,
    this.payoutMultiplier = 1.85,
    this.finalPrice,
    this.isSettled = false,
    this.isWon = false,
  });

  double get potentialPayout => stake * payoutMultiplier;

  double get profit => isWon ? (potentialPayout - stake) : -stake;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetSymbol': assetSymbol,
        'assetName': assetName,
        'entryPrice': entryPrice,
        'direction': direction.name,
        'stake': stake,
        'durationSeconds': durationSeconds,
        'startedAt': startedAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'payoutMultiplier': payoutMultiplier,
        'finalPrice': finalPrice,
        'isSettled': isSettled,
        'isWon': isWon,
      };

  factory TurboOption.fromJson(Map<String, dynamic> json) => TurboOption(
        id: json['id'] as String,
        assetSymbol: json['assetSymbol'] as String,
        assetName: json['assetName'] as String,
        entryPrice: (json['entryPrice'] as num).toDouble(),
        direction: TurboDirection.values.byName(json['direction'] as String),
        stake: (json['stake'] as num).toDouble(),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        payoutMultiplier: (json['payoutMultiplier'] as num).toDouble(),
        finalPrice: (json['finalPrice'] as num?)?.toDouble(),
        isSettled: json['isSettled'] as bool? ?? false,
        isWon: json['isWon'] as bool? ?? false,
      );
}
