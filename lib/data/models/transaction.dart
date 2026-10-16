enum TransactionType {
  buy,
  sell,
  liquidation,
  couponPayout,
  luxuryPurchase,
  loanPayout,
  loanRepayment;

  String get displayName {
    switch (this) {
      case TransactionType.buy:
        return 'Kauf';
      case TransactionType.sell:
        return 'Verkauf';
      case TransactionType.liquidation:
        return 'Zwangsliquidation';
      case TransactionType.couponPayout:
        return 'Anleihen-Zinskupon';
      case TransactionType.luxuryPurchase:
        return 'Prestige-Kauf';
      case TransactionType.loanPayout:
        return 'Kreditaufnahme';
      case TransactionType.loanRepayment:
        return 'Kredittilgung';
    }
  }
}

class TransactionRecord {
  final String id;
  final String symbol;
  final String name;
  final TransactionType type;
  final double amount;
  final double price;
  final double totalAmount; // Gesamtsumme inkl. Cash-Fluss
  final double? realizedPnL;
  final DateTime timestamp;
  final String? note;

  TransactionRecord({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.amount,
    required this.price,
    required this.totalAmount,
    this.realizedPnL,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'type': type.name,
        'amount': amount,
        'price': price,
        'totalAmount': totalAmount,
        'realizedPnL': realizedPnL,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        type: TransactionType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        price: (json['price'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        realizedPnL: (json['realizedPnL'] as num?)?.toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String?,
      );
}
