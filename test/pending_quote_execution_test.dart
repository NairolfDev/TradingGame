import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/pending_order.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';

class _OpenMarket extends PortfolioProvider {
  _OpenMarket({required super.repository});
  @override
  bool isAssetMarketOpen(Asset asset) => true;
}

void main() {
  testWidgets(
    'pending buy waits for a quote and fills its budget at the new price',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalTradingRepository();
      final stock = (await repository.getAssets()).firstWhere(
        (a) => a.type == AssetType.stock,
      );
      await repository.savePendingOrders([
        PendingOrder(
          id: 'order',
          assetId: stock.id,
          symbol: stock.symbol,
          name: stock.name,
          assetType: stock.type,
          isBuy: true,
          amount: 9.801,
          estimatedPrice: 100,
          totalEstimatedCost: 1000,
        ),
      ]);
      final portfolio = _OpenMarket(repository: repository);

      for (var i = 0; i < 100 && portfolio.isLoading; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(portfolio.isLoading, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(portfolio.pendingOrders, hasLength(1));
      expect(portfolio.positions, isEmpty);
      portfolio.assets.firstWhere((a) => a.id == stock.id).currentPrice = 200;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(portfolio.positions.single.averageBuyPrice, 200);
      expect(
        portfolio.positions.single.amount,
        closeTo((1000 - 19.90) / 200, 1e-9),
      );
      expect(portfolio.pendingOrders, isEmpty);
      expect(portfolio.positions.single.unrealizedPnL, closeTo(0, 1e-9));
      portfolio.dispose();
    },
  );
}
