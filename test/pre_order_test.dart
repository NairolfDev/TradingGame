import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/pending_order.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';

void main() {
  late PortfolioProvider portfolio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    portfolio = PortfolioProvider(repository: LocalTradingRepository());
    while (portfolio.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    portfolio.marketEngine.stop();
    portfolio.newsService.dispose();
  });
  tearDown(() => portfolio.dispose());

  PendingOrder preOrder() {
    // Crypto trades around the clock, so its "opening" has already happened.
    final btc = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    return PendingOrder(
      id: 'pre',
      assetId: btc.id,
      symbol: btc.symbol,
      name: btc.name,
      assetType: btc.type,
      isBuy: true,
      amount: 0.01,
      estimatedPrice: btc.currentPrice,
      totalEstimatedCost: 0.01 * btc.currentPrice,
      executionReason: 'Wartet auf Börsenöffnung',
    );
  }

  test(
    'a pre-order becomes a normal order at the open, not an instant fill',
    () async {
      await portfolio.setRealisticOrderDelay(true);
      final order = preOrder();
      expect(order.isPreOrder, isTrue);
      await portfolio.processPendingOrdersForTest([order]);
      expect(order.status, PendingOrderStatus.pending);
      expect(order.isPreOrder, isFalse);
      final wait = order.scheduledExecutionTime!.difference(DateTime.now());
      expect(wait.inMinutes, inInclusiveRange(4, 15));
      expect(order.executionReason, 'Im Orderbuch');
      expect(order.brokerVenue, 'Crypto Liquidity Pool');
    },
  );

  test('without routing delay a pre-order fills at the open', () async {
    await portfolio.setRealisticOrderDelay(false);
    final order = preOrder();
    await portfolio.processPendingOrdersForTest([order]);
    expect(order.status, PendingOrderStatus.executed);
  });
}
