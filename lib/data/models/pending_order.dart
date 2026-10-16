import 'asset.dart';

enum PendingOrderStatus {
  pending,
  executed,
  cancelled;

  String get displayName {
    switch (this) {
      case PendingOrderStatus.pending:
        return 'Wartet auf Börsenöffnung';
      case PendingOrderStatus.executed:
        return 'Ausgeführt';
      case PendingOrderStatus.cancelled:
        return 'Storniert';
    }
  }
}

class PendingOrder {
  final String id;
  final String assetId;
  final String symbol;
  final String name;
  final AssetType assetType;
  final bool isBuy; // true = Buy, false = Sell
  final double amount;
  final double estimatedPrice;
  final double totalEstimatedCost;
  final int leverage;
  final bool isShort;
  final DateTime createdAt;
  final DateTime? scheduledExecutionTime;
  final String? executionReason;
  final String? brokerVenue;
  PendingOrderStatus status;
  DateTime? executedAt;
  double? executedPrice;

  PendingOrder({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.isBuy,
    required this.amount,
    required this.estimatedPrice,
    required this.totalEstimatedCost,
    this.leverage = 1,
    this.isShort = false,
    DateTime? createdAt,
    this.scheduledExecutionTime,
    this.executionReason,
    this.brokerVenue,
    this.status = PendingOrderStatus.pending,
    this.executedAt,
    this.executedPrice,
  }) : createdAt = createdAt ?? DateTime.now();

  int get minutesRemaining {
    if (scheduledExecutionTime == null) return 0;
    final diff = scheduledExecutionTime!.difference(DateTime.now()).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'symbol': symbol,
        'name': name,
        'assetType': assetType.name,
        'isBuy': isBuy,
        'amount': amount,
        'estimatedPrice': estimatedPrice,
        'totalEstimatedCost': totalEstimatedCost,
        'leverage': leverage,
        'isShort': isShort,
        'createdAt': createdAt.toIso8601String(),
        'scheduledExecutionTime': scheduledExecutionTime?.toIso8601String(),
        'executionReason': executionReason,
        'brokerVenue': brokerVenue,
        'status': status.name,
        'executedAt': executedAt?.toIso8601String(),
        'executedPrice': executedPrice,
      };

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        id: json['id'] as String,
        assetId: json['assetId'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        assetType: AssetType.values.byName(json['assetType'] as String),
        isBuy: json['isBuy'] as bool,
        amount: (json['amount'] as num).toDouble(),
        estimatedPrice: (json['estimatedPrice'] as num).toDouble(),
        totalEstimatedCost: (json['totalEstimatedCost'] as num).toDouble(),
        leverage: (json['leverage'] as num?)?.toInt() ?? 1,
        isShort: json['isShort'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        scheduledExecutionTime: json['scheduledExecutionTime'] != null
            ? DateTime.parse(json['scheduledExecutionTime'] as String)
            : null,
        executionReason: json['executionReason'] as String?,
        brokerVenue: json['brokerVenue'] as String?,
        status: PendingOrderStatus.values.byName(json['status'] as String),
        executedAt: json['executedAt'] != null
            ? DateTime.parse(json['executedAt'] as String)
            : null,
        executedPrice: (json['executedPrice'] as num?)?.toDouble(),
      );
}
