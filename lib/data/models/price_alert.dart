enum AlertDirection { above, below }

/// A price alert; evaluated by the app while it runs (no server). Stored in
/// the top-level `priceAlerts` collection.
class PriceAlert {
  final String id;
  final String uid;
  final String assetId;
  final String symbol;
  final String name;
  final String yahooSymbol;
  final AlertDirection direction;
  final double price;
  final bool recurring;
  final bool active;
  final bool armed;
  final DateTime? lastTriggeredAt;

  const PriceAlert({
    required this.id,
    required this.uid,
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.yahooSymbol,
    required this.direction,
    required this.price,
    required this.recurring,
    required this.active,
    this.armed = true,
    this.lastTriggeredAt,
  });

  /// Fields written by the client when it creates an alert.
  Map<String, dynamic> toCreateJson() => {
    'uid': uid,
    'assetId': assetId,
    'symbol': symbol,
    'name': name,
    'yahooSymbol': yahooSymbol,
    'direction': direction.name,
    'price': price,
    'recurring': recurring,
    'active': true,
    'armed': true,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  factory PriceAlert.fromJson(String id, Map<String, dynamic> json) =>
      PriceAlert(
        id: id,
        uid: json['uid'] as String? ?? '',
        assetId: json['assetId'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        yahooSymbol: json['yahooSymbol'] as String? ?? '',
        direction: json['direction'] == 'below'
            ? AlertDirection.below
            : AlertDirection.above,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        recurring: json['recurring'] as bool? ?? false,
        active: json['active'] as bool? ?? false,
        armed: json['armed'] != false,
        lastTriggeredAt: json['lastTriggeredAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['lastTriggeredAt'] as num).toInt(),
              )
            : null,
      );

  /// A recurring alert fires once, then re-arms only after the price crossed
  /// back, so it cannot spam while the price hovers around the threshold.
  ({bool trigger, bool armed}) evaluate(double currentPrice) {
    final hit = firesAt(currentPrice);
    return armed ? (trigger: hit, armed: !hit) : (trigger: false, armed: !hit);
  }

  /// Whether the alert would fire immediately at [currentPrice]; used to warn
  /// the user instead of creating a pointless alert.
  bool firesAt(double currentPrice) => direction == AlertDirection.above
      ? currentPrice >= price
      : currentPrice <= price;
}
