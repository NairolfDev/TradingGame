import '../models/asset.dart';
import 'stock_catalog_data.dart';

class StockCatalog {
  static const generatedAt = '2026-10-16';

  static List<Asset> merge(List<Asset> existing) {
    final bySymbol = {for (final asset in existing) asset.symbol: asset};
    for (final row in stockCatalogRows) {
      final old = bySymbol[row[0]];
      bySymbol[row[0]] = Asset(
        id:
            old?.id ??
            'catalog_stock_${row[0].toLowerCase().replaceAll('.', '_')}',
        symbol: row[0],
        name: row[1],
        type: AssetType.stock,
        currentPrice: 0,
        previousClose: 0,
        dailyHigh: 0,
        dailyLow: 0,
        priceHistory: [],
        volatility: 0,
        description:
            '${row[2]} · Katalogstand ${row[6]}. Kurse werden bei Bedarf abgerufen.',
        category: '${row[2]} / ${row[3]}',
        yahooSymbol: row[0],
        isWatchlisted: old?.isWatchlisted ?? false,
        marketGroups: [row[2]],
        sector: row[3],
        industry: row[4],
        country: row[5],
        catalogDate: row[6],
      );
    }
    return bySymbol.values.toList();
  }
}
