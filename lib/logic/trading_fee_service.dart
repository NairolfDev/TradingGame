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
        description = 'Bank- & Börsenspesen (Wiener Börse / XETRA Flat: 19,90 €)';
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
        description = 'Krypto Handelsgebühr (1,2% Spread): ${fee.toStringAsFixed(2)} €';
        break;

      case AssetType.cfd:
        // CFD / Hebel Ordergebühr
        fee = 4.90;
        description = 'CFD Kommission & Kontraktspesen: 4,90 €';
        break;

      case AssetType.commodity:
        // Edelmetall- & Rohstoffspesen
        fee = 14.90;
        description = 'Edelmetall- & Rohstoffspesen (Tresorverwahrung): 14,90 €';
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
