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
  final double? dividendYield; // Für Aktien & ETFs (z. B. 0.072 für 7.2% Dividende p.a.)
  final int maxLeverage; // Für CFDs (z. B. 50x)
  final String category;
  final String? yahooSymbol; // Yahoo Finance Ticker z. B. 'AAPL', 'OMV.VI', 'GC=F'
  final String? coingeckoId; // CoinGecko Coin ID z. B. 'bitcoin', 'ethereum'
  bool isWatchlisted;

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
    this.dividendYield,
    this.maxLeverage = 1,
    this.category = '',
    this.yahooSymbol,
    this.coingeckoId,
    this.isWatchlisted = false,
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
        'dividendYield': dividendYield,
        'maxLeverage': maxLeverage,
        'category': category,
        'yahooSymbol': yahooSymbol,
        'coingeckoId': coingeckoId,
        'isWatchlisted': isWatchlisted,
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
        dividendYield: (json['dividendYield'] as num?)?.toDouble(),
        maxLeverage: (json['maxLeverage'] as num?)?.toInt() ?? 1,
        category: json['category'] as String? ?? '',
        yahooSymbol: json['yahooSymbol'] as String?,
        coingeckoId: json['coingeckoId'] as String?,
        isWatchlisted: json['isWatchlisted'] as bool? ?? false,
      );

  Asset copyWith({
    String? id,
    String? symbol,
    String? name,
    AssetType? type,
    double? currentPrice,
    double? previousClose,
    double? dailyHigh,
    double? dailyLow,
    List<double>? priceHistory,
    double? volatility,
    String? description,
    double? couponRate,
    double? dividendYield,
    int? maxLeverage,
    String? category,
    String? yahooSymbol,
    String? coingeckoId,
    bool? isWatchlisted,
  }) {
    return Asset(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      type: type ?? this.type,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClose: previousClose ?? this.previousClose,
      dailyHigh: dailyHigh ?? this.dailyHigh,
      dailyLow: dailyLow ?? this.dailyLow,
      priceHistory: priceHistory ?? this.priceHistory,
      volatility: volatility ?? this.volatility,
      description: description ?? this.description,
      couponRate: couponRate ?? this.couponRate,
      dividendYield: dividendYield ?? this.dividendYield,
      maxLeverage: maxLeverage ?? this.maxLeverage,
      category: category ?? this.category,
      yahooSymbol: yahooSymbol ?? this.yahooSymbol,
      coingeckoId: coingeckoId ?? this.coingeckoId,
      isWatchlisted: isWatchlisted ?? this.isWatchlisted,
    );
  }

  Asset copyWithPrice(double newPrice) {
    final updatedHistory = List<double>.from(priceHistory)..add(newPrice);
    if (updatedHistory.length > 50) {
      updatedHistory.removeAt(0);
    }
    return copyWith(
      currentPrice: newPrice,
      dailyHigh: newPrice > dailyHigh ? newPrice : dailyHigh,
      dailyLow: newPrice < dailyLow ? newPrice : dailyLow,
      priceHistory: updatedHistory,
    );
  }
}
