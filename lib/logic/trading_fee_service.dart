import '../data/models/asset.dart';

class OrderFeeBreakdown {
  final double assetCost;
  final double transactionFee;
  final String feeDescription;
  final double totalCashRequired;

  const OrderFeeBreakdown({
    required this.assetCost,
    required this.transactionFee,
    required this.feeDescription,
    required this.totalCashRequired,
  });
}

class TradingFeeService {
  /// Largest affordable quantity, including the same fees charged at execution.
  static double maximumBuyAmount({
    required Asset asset,
    required double cash,
    int leverage = 1,
  }) {
    if (!cash.isFinite ||
        cash <= 0 ||
        !asset.currentPrice.isFinite ||
        asset.currentPrice <= 0 ||
        leverage < 1 ||
        leverage > asset.maxLeverage) {
      return 0;
    }
    var lower = 0.0;
    if (cash <=
        calculateBuyFee(
          asset: asset,
          amount: 0,
          leverage: leverage,
        ).transactionFee) {
      return 0;
    }
    var upper = cash / asset.currentPrice * leverage;
    if (!upper.isFinite) return 0;
    // Keep the affordable side of the boundary; decimal rounding can overspend.
    for (var i = 0; i < 80; i++) {
      final middle = lower + (upper - lower) / 2;
      if (middle == lower || middle == upper) break;
      final cost = calculateBuyFee(
        asset: asset,
        amount: middle,
        leverage: leverage,
      ).totalCashRequired;
      if (cost.isFinite && cost <= cash) {
        lower = middle;
      } else {
        upper = middle;
      }
    }
    return lower;
  }

  /// Berechnet realistische Transaktionskosten nach österreichischem Broker-Standard
  static OrderFeeBreakdown calculateBuyFee({
    required Asset asset,
    required double amount,
    int leverage = 1,
  }) {
    final rawAssetCost = (amount * asset.currentPrice) / leverage;

    double fee = 0.0;
    String description = '';

    switch (asset.type) {
      case AssetType.stock:
        // Klassische Banken / Wiener Börse Gebühr: ca. 19,90 € Spesen
        fee = 19.90;
        description =
            'Bank- & Börsenspesen (Wiener Börse / XETRA Flat: 19,90 €)';
        break;

      case AssetType.bond:
        // Rentenhandel / Anleihen Courtage an der Wiener Börse
        fee = 24.50;
        description = 'Renten-Courtage & Verwahrspesen: 24,50 €';
        break;

      case AssetType.etf:
        // ETF Sparplan- & Ordergebühr
        fee = 9.90;
        description = 'ETF Ausführungsgebühr: 9,90 €';
        break;

      case AssetType.crypto:
        // Krypto Handelskommission (1,2% Spread)
        fee = (rawAssetCost * 0.012).clamp(1.50, 150.0);
        description =
            'Krypto Handelsgebühr (1,2% Spread): ${fee.toStringAsFixed(2)} €';
        break;

      case AssetType.cfd:
        // CFD / Hebel Ordergebühr
        fee = 4.90;
        description = 'CFD Kommission & Kontraktspesen: 4,90 €';
        break;

      case AssetType.commodity:
        // Edelmetall- & Rohstoffspesen
        fee = 14.90;
        description =
            'Edelmetall- & Rohstoffspesen (Tresorverwahrung): 14,90 €';
        break;
    }

    return OrderFeeBreakdown(
      assetCost: rawAssetCost,
      transactionFee: fee,
      feeDescription: description,
      totalCashRequired: rawAssetCost + fee,
    );
  }

  static double calculateSellFee(AssetType type, double proceeds) {
    switch (type) {
      case AssetType.stock:
        return 19.90;
      case AssetType.bond:
        return 24.50;
      case AssetType.etf:
        return 9.90;
      case AssetType.crypto:
        return (proceeds * 0.012).clamp(1.50, 150.0);
      case AssetType.cfd:
        return 4.90;
      case AssetType.commodity:
        return 14.90;
    }
  }
}
