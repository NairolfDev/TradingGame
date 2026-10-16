enum AutomationOrderType {
  buyLimit,   // Kaufe wenn Preis <= Zielpreis (Buy at)
  takeProfit, // Verkaufe Position wenn Gewinnkurs >= Zielpreis (Sell at Profit)
  stopLoss;   // Verkaufe Position wenn Verlustkurs <= Stoppkurs (Sell at Stop Loss)

  String get displayName {
    switch (this) {
      case AutomationOrderType.buyLimit:
        return 'Buy-At (Kauf-Limit)';
      case AutomationOrderType.takeProfit:
        return 'Sell-At (Take-Profit)';
      case AutomationOrderType.stopLoss:
        return 'Sell-At (Stop-Loss)';
    }
  }
}

class AutomationOrder {
  final String id;
  final String assetId;
  final String symbol;
  final String name;
  final AutomationOrderType orderType;
  final double targetPrice;
  final double amount;
  final int slotIndex;
  final DateTime createdAt;
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
        orderType: AutomationOrderType.values.byName(json['orderType'] as String),
        targetPrice: (json['targetPrice'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        slotIndex: (json['slotIndex'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isTriggered: json['isTriggered'] as bool? ?? false,
        isCancelled: json['isCancelled'] as bool? ?? false,
        triggeredAt: json['triggeredAt'] != null
            ? DateTime.parse(json['triggeredAt'] as String)
            : null,
        triggeredPrice: (json['triggeredPrice'] as num?)?.toDouble(),
      );
}
