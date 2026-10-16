enum AssetType {
  stock,
  crypto,
  etf,
  cfd,
  bond,
  commodity;

  String get displayName {
    switch (this) {
      case AssetType.stock:
        return 'Aktien';
      case AssetType.crypto:
        return 'Krypto';
      case AssetType.etf:
        return 'ETFs';
      case AssetType.cfd:
        return 'CFD / Hebel';
      case AssetType.bond:
        return 'Anleihen';
      case AssetType.commodity:
        return 'Edelmetalle & Rohstoffe';
    }
  }
}

class Asset {
  final String id;
  final String symbol;
  final String name;
  final AssetType type;
  double currentPrice;
  double previousClose;
  double dailyHigh;
  double dailyLow;
  List<double> priceHistory;
  final double volatility;
  final String description;
  final double? couponRate; // Für Anleihen (z. B. 0.035 für 3.5%)
  final int maxLeverage; // Für CFDs (z. B. 50x)
  final String category;

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.currentPrice,
    required this.previousClose,
    required this.dailyHigh,
    required this.dailyLow,
    required this.priceHistory,
    required this.volatility,
    required this.description,
    this.couponRate,
    this.maxLeverage = 1,
    this.category = '',
  });

  double get change24h => currentPrice - previousClose;

  double get change24hPercent =>
      previousClose > 0 ? (change24h / previousClose) : 0.0;

  bool get isPositive => change24h >= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'type': type.name,
        'currentPrice': currentPrice,
        'previousClose': previousClose,
        'dailyHigh': dailyHigh,
        'dailyLow': dailyLow,
        'priceHistory': priceHistory,
        'volatility': volatility,
        'description': description,
        'couponRate': couponRate,
        'maxLeverage': maxLeverage,
        'category': category,
      };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        type: AssetType.values.byName(json['type'] as String),
        currentPrice: (json['currentPrice'] as num).toDouble(),
        previousClose: (json['previousClose'] as num).toDouble(),
        dailyHigh: (json['dailyHigh'] as num).toDouble(),
        dailyLow: (json['dailyLow'] as num).toDouble(),
        priceHistory: (json['priceHistory'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [(json['currentPrice'] as num).toDouble()],
        volatility: (json['volatility'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        couponRate: (json['couponRate'] as num?)?.toDouble(),
        maxLeverage: (json['maxLeverage'] as num?)?.toInt() ?? 1,
        category: json['category'] as String? ?? '',
      );

  Asset copyWithPrice(double newPrice) {
    final updatedHistory = List<double>.from(priceHistory)..add(newPrice);
    if (updatedHistory.length > 50) {
      updatedHistory.removeAt(0);
    }
    return Asset(
      id: id,
      symbol: symbol,
      name: name,
      type: type,
      currentPrice: newPrice,
      previousClose: previousClose,
      dailyHigh: newPrice > dailyHigh ? newPrice : dailyHigh,
      dailyLow: newPrice < dailyLow ? newPrice : dailyLow,
      priceHistory: updatedHistory,
      volatility: volatility,
      description: description,
      couponRate: couponRate,
      maxLeverage: maxLeverage,
      category: category,
    );
  }
}
