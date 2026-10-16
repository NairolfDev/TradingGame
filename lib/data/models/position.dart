import 'asset.dart';

class Position {
  final String id;
  final String assetId;
  final String symbol;
  final String name;
  final AssetType type;
  double amount; // Anzahl Anteile / Coins / Kontrakte
  double averageBuyPrice;
  double currentPrice;
  final int leverage; // 1 = Spot, >1 = CFD Hebel
  final bool isShort; // true = Short CFD, false = Long
  final double collateral; // Hinterlegte Margin bei Hebelprodukten
  final double liquidationPrice; // Kurs bei dem die Position zwangsliquidiert wird
  final DateTime openedAt;

  Position({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.type,
    required this.amount,
    required this.averageBuyPrice,
    required this.currentPrice,
    this.leverage = 1,
    this.isShort = false,
    double? collateral,
    double? liquidationPrice,
    DateTime? openedAt,
  })  : collateral = collateral ?? (amount * averageBuyPrice),
        liquidationPrice = liquidationPrice ??
            _calculateLiquidationPrice(
              buyPrice: averageBuyPrice,
              leverage: leverage,
              isShort: isShort,
            ),
        openedAt = openedAt ?? DateTime.now();

  static double _calculateLiquidationPrice({
    required double buyPrice,
    required int leverage,
    required bool isShort,
  }) {
    if (leverage <= 1) return 0.0;
    // Bei 90% Verlust des Collaterals erfolgt die Liquidation
    final maxLossFactor = 0.90 / leverage;
    if (isShort) {
      return buyPrice * (1 + maxLossFactor);
    } else {
      return buyPrice * (1 - maxLossFactor);
    }
  }

  bool get isLeveraged => leverage > 1;

  double get unrealizedPnL {
    if (!isLeveraged) {
      return (currentPrice - averageBuyPrice) * amount;
    } else {
      if (isShort) {
        return ((averageBuyPrice - currentPrice) / averageBuyPrice) *
            collateral *
            leverage;
      } else {
        return ((currentPrice - averageBuyPrice) / averageBuyPrice) *
            collateral *
            leverage;
      }
    }
  }

  double get unrealizedPnLPercent {
    final base = isLeveraged ? collateral : (amount * averageBuyPrice);
    if (base <= 0) return 0.0;
    return unrealizedPnL / base;
  }

  double get currentValue {
    if (!isLeveraged) {
      return amount * currentPrice;
    } else {
      final val = collateral + unrealizedPnL;
      return val > 0 ? val : 0.0;
    }
  }

  bool get isLiquidated {
    if (!isLeveraged) return false;
    if (isShort) {
      return currentPrice >= liquidationPrice;
    } else {
      return currentPrice <= liquidationPrice;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'symbol': symbol,
        'name': name,
        'type': type.name,
        'amount': amount,
        'averageBuyPrice': averageBuyPrice,
        'currentPrice': currentPrice,
        'leverage': leverage,
        'isShort': isShort,
        'collateral': collateral,
        'liquidationPrice': liquidationPrice,
        'openedAt': openedAt.toIso8601String(),
      };

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        id: json['id'] as String,
        assetId: json['assetId'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        type: AssetType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        averageBuyPrice: (json['averageBuyPrice'] as num).toDouble(),
        currentPrice: (json['currentPrice'] as num).toDouble(),
        leverage: (json['leverage'] as num?)?.toInt() ?? 1,
        isShort: json['isShort'] as bool? ?? false,
        collateral: (json['collateral'] as num?)?.toDouble(),
        liquidationPrice: (json['liquidationPrice'] as num?)?.toDouble(),
        openedAt: json['openedAt'] != null
            ? DateTime.parse(json['openedAt'] as String)
            : DateTime.now(),
      );

  Position copyWith({
    double? amount,
    double? averageBuyPrice,
    double? currentPrice,
  }) {
    return Position(
      id: id,
      assetId: assetId,
      symbol: symbol,
      name: name,
      type: type,
      amount: amount ?? this.amount,
      averageBuyPrice: averageBuyPrice ?? this.averageBuyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      leverage: leverage,
      isShort: isShort,
      collateral: collateral,
      liquidationPrice: liquidationPrice,
      openedAt: openedAt,
    );
  }
}
