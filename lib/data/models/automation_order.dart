enum AutomationOrderType {
  buyLimit,     // Kaufe wenn Preis <= Zielpreis (Buy at)
  takeProfit,   // Verkaufe Position wenn Gewinnkurs >= Zielpreis (Sell at Profit)
  stopLoss,     // Verkaufe Position wenn Verlustkurs <= Stoppkurs (Sell at Stop Loss)
  trailingStop; // Verkaufe Position wenn Kurs um trailingPercent % vom Hoch fällt

  String get displayName {
    switch (this) {
      case AutomationOrderType.buyLimit:
        return 'Buy-At (Kauf-Limit)';
      case AutomationOrderType.takeProfit:
        return 'Sell-At (Take-Profit)';
      case AutomationOrderType.stopLoss:
        return 'Sell-At (Stop-Loss)';
      case AutomationOrderType.trailingStop:
        return 'Trailing-Stop (%)';
    }
  }
}

class AutomationOrder {
  final String id;
  final String assetId;
  final String symbol;
  final String name;
  final AutomationOrderType orderType;
  double targetPrice;
  final double amount;
  final int slotIndex;
  final DateTime createdAt;
  final double? trailingPercent;
  double? highestObservedPrice;
  bool isTriggered;
  bool isCancelled;
  DateTime? triggeredAt;
  double? triggeredPrice;

  AutomationOrder({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.orderType,
    required this.targetPrice,
    required this.amount,
    required this.slotIndex,
    required this.createdAt,
    this.trailingPercent,
    this.highestObservedPrice,
    this.isTriggered = false,
    this.isCancelled = false,
    this.triggeredAt,
    this.triggeredPrice,
  });

  bool get isActive => !isTriggered && !isCancelled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'symbol': symbol,
        'name': name,
        'orderType': orderType.name,
        'targetPrice': targetPrice,
        'amount': amount,
        'slotIndex': slotIndex,
        'createdAt': createdAt.toIso8601String(),
        if (trailingPercent != null) 'trailingPercent': trailingPercent,
        if (highestObservedPrice != null)
          'highestObservedPrice': highestObservedPrice,
        'isTriggered': isTriggered,
        'isCancelled': isCancelled,
        'triggeredAt': triggeredAt?.toIso8601String(),
        'triggeredPrice': triggeredPrice,
      };

  factory AutomationOrder.fromJson(Map<String, dynamic> json) => AutomationOrder(
        id: json['id'] as String,
        assetId: json['assetId'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        orderType: AutomationOrderType.values.firstWhere(
          (e) => e.name == json['orderType'],
          orElse: () => AutomationOrderType.buyLimit,
        ),
        targetPrice: (json['targetPrice'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        slotIndex: (json['slotIndex'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        trailingPercent: (json['trailingPercent'] as num?)?.toDouble(),
        highestObservedPrice:
            (json['highestObservedPrice'] as num?)?.toDouble(),
        isTriggered: json['isTriggered'] as bool? ?? false,
        isCancelled: json['isCancelled'] as bool? ?? false,
        triggeredAt: json['triggeredAt'] != null
            ? DateTime.parse(json['triggeredAt'] as String)
            : null,
        triggeredPrice: (json['triggeredPrice'] as num?)?.toDouble(),
      );
}
