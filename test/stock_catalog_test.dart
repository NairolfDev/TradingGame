import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/catalog/stock_catalog.dart';
import 'package:trading_game/data/catalog/stock_catalog_data.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';

void main() {
  test(
    'complete sourced stock universes have unique symbols and no seed quotes',
    () {
      final assets = StockCatalog.merge(InitialAssets.getAssets());
      for (final entry in {
        'Nasdaq': 3540,
        'DAX': 40,
        'ATX': 20,
        'Nikkei 225': 225,
      }.entries) {
        final members = assets.where(
          (asset) => asset.marketGroups.contains(entry.key),
        );
        expect(members.length, entry.value);
        expect(
          members.every(
            (asset) => asset.currentPrice == 0 && asset.priceHistory.isEmpty,
          ),
          isTrue,
        );
        expect(members.every((asset) => asset.catalogDate.isNotEmpty), isTrue);
      }
      expect(
        stockCatalogRows.map((row) => row[0]).toSet().length,
        stockCatalogRows.length,
      );
      expect(
        assets.firstWhere((a) => a.symbol == 'NVDA').sector,
        'Technologie',
      );
      expect(
        assets.firstWhere((a) => a.symbol == 'SAP.DE').sector,
        'Unbekannt',
      );
      expect(assets.any((a) => a.symbol == '285A.T'), isTrue);
    },
  );

  test(
    'catalog migration preserves asset identity/watchlist and metadata round trips',
    () {
      final old = InitialAssets.getAssets().firstWhere(
        (a) => a.symbol == 'EBS.VI',
      );
      final migrated = StockCatalog.merge([old.copyWith(isWatchlisted: true)]);
      final asset = migrated.firstWhere((a) => a.symbol == old.symbol);
      expect(asset.id, old.id);
      expect(asset.isWatchlisted, isTrue);
      final restored = Asset.fromJson(
        asset.copyWith(currentPrice: 123).toJson(),
      );
      expect(restored.marketGroups, ['ATX']);
      expect(restored.country, 'AT');
      expect(restored.currentPrice, 123);
    },
  );
}
