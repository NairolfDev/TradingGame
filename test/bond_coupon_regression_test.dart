import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/models/transaction.dart';
import 'package:trading_game/logic/bond_coupon_service.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';

class _OpenMarketPortfolio extends PortfolioProvider {
  _OpenMarketPortfolio({required super.repository});
  @override
  bool isAssetMarketOpen(Asset asset) => true;
}

Future<_OpenMarketPortfolio> _load(LocalTradingRepository repository) async {
  final portfolio = _OpenMarketPortfolio(repository: repository);
  while (portfolio.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  portfolio.marketEngine.stop();
  portfolio.newsService.dispose();
  await portfolio.setRealisticOrderDelay(false);
  return portfolio;
}

Position _position(Asset bond, DateTime openedAt, {double amount = 100}) =>
    Position(
      id: 'bond-position',
      assetId: bond.id,
      symbol: bond.symbol,
      name: bond.name,
      type: bond.type,
      amount: amount,
      averageBuyPrice: bond.currentPrice,
      currentPrice: bond.currentPrice,
      openedAt: openedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'actual elapsed holding time, cursor and finite inputs bound coupon accrual',
    () {
      final now = DateTime.utc(2026, 10, 16);
      final position = Position(
        id: 'test',
        assetId: 'bond',
        symbol: 'BOND',
        name: 'Bond',
        type: AssetType.bond,
        amount: 100,
        averageBuyPrice: 100,
        currentPrice: 100,
        openedAt: now.subtract(const Duration(days: 365)),
      );
      double accrued(DateTime from, DateTime until) =>
          BondCouponService.accrued(
            position: position,
            annualRate: 0.05,
            paidThrough: from,
            now: until,
          );
      expect(accrued(position.openedAt, now), closeTo(500, 1e-10));
      expect(
        accrued(now.subtract(const Duration(seconds: 50)), now),
        closeTo(500 * 50 / (365 * 86400), 1e-12),
      );
      expect(accrued(now, now), 0);
      expect(accrued(now.add(const Duration(days: 1)), now), 0);
      expect(
        accrued(position.openedAt.subtract(const Duration(days: 365)), now),
        closeTo(500, 1e-10),
      );
      position.currentPrice = double.nan;
      expect(accrued(position.openedAt, now), 0);
    },
  );

  test(
    'offline holding accrues once and cursor survives restart and history trimming',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalTradingRepository('coupon-profile');
      final bond = (await repository.getAssets()).firstWhere(
        (a) => a.type == AssetType.bond,
      );
      await repository.savePositions([
        _position(bond, DateTime.now().subtract(const Duration(days: 365))),
      ]);
      var portfolio = await _load(repository);
      var liveBond = portfolio.assets.firstWhere((a) => a.id == bond.id);
      await portfolio.executeBuy(asset: liveBond, amount: 1);
      final coupons = portfolio.transactions
          .where((t) => t.type == TransactionType.couponPayout)
          .toList();
      expect(coupons, hasLength(1));
      final annual = 100 * bond.currentPrice * (bond.couponRate ?? 0.035);
      expect(coupons.single.totalAmount, closeTo(annual, 0.0001));
      final paidCash = portfolio.cash;
      portfolio.dispose();
      // Cursor persistence must not rely on the repository's 200-row history.
      await repository.saveAllTransactions([]);
      portfolio = await _load(repository);
      liveBond = portfolio.assets.firstWhere((a) => a.id == bond.id);
      await portfolio.executeSell(
        position: portfolio.positions.single,
        sellAmount: 1,
      );
      final newCoupons = portfolio.transactions.where(
        (t) => t.type == TransactionType.couponPayout,
      );
      expect(
        newCoupons.fold<double>(0, (sum, t) => sum + t.totalAmount),
        lessThan(0.001),
      );
      expect(portfolio.cash, closeTo(paidCash + liveBond.currentPrice, 0.001));
      portfolio.dispose();
    },
  );

  test(
    'top-ups settle old quantity first; partial sales settle before reducing it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalTradingRepository('changes');
      final bond = (await repository.getAssets()).firstWhere(
        (a) => a.type == AssetType.bond,
      );
      await repository.savePositions([
        _position(bond, DateTime.now().subtract(const Duration(days: 365))),
      ]);
      final portfolio = await _load(repository);
      addTearDown(portfolio.dispose);
      final liveBond = portfolio.assets.firstWhere((a) => a.id == bond.id);
      await portfolio.executeBuy(asset: liveBond, amount: 100);
      final annual = 100 * bond.currentPrice * (bond.couponRate ?? 0.035);
      expect(
        portfolio.transactions
            .firstWhere((t) => t.type == TransactionType.couponPayout)
            .totalAmount,
        closeTo(annual, 0.0001),
      );
      expect(portfolio.positions.single.amount, 200);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'tg_coupon_cursor_changes_bond-position',
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      await portfolio.executeSell(
        position: portfolio.positions.single,
        sellAmount: 150,
      );
      expect(
        portfolio.transactions
            .firstWhere((t) => t.type == TransactionType.couponPayout)
            .totalAmount,
        closeTo(annual * 2 / 365, 0.0001),
      );
      expect(portfolio.positions.single.amount, 50);
      await prefs.setString(
        'tg_coupon_cursor_changes_bond-position',
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      await portfolio.executeSell(
        position: portfolio.positions.single,
        sellAmount: 50,
      );
      expect(
        portfolio.transactions
            .firstWhere((t) => t.type == TransactionType.couponPayout)
            .totalAmount,
        closeTo(annual * 0.5 / 365, 0.0001),
      );
      expect(portfolio.positions, isEmpty);
    },
  );

  test(
    'profiles with the same position id keep separate accrual cursors',
    () async {
      SharedPreferences.setMockInitialValues({});
      for (final user in ['first', 'second']) {
        final repository = LocalTradingRepository(user);
        final bond = (await repository.getAssets()).firstWhere(
          (a) => a.type == AssetType.bond,
        );
        await repository.savePositions([
          _position(bond, DateTime.now().subtract(const Duration(days: 1))),
        ]);
        final portfolio = await _load(repository);
        final liveBond = portfolio.assets.firstWhere((a) => a.id == bond.id);
        await portfolio.executeSell(
          position: portfolio.positions.single,
          sellAmount: 1,
        );
        expect(
          portfolio.transactions
              .firstWhere((t) => t.type == TransactionType.couponPayout)
              .totalAmount,
          closeTo(
            100 * liveBond.currentPrice * (liveBond.couponRate ?? 0.035) / 365,
            0.0001,
          ),
        );
        portfolio.dispose();
      }
    },
  );

  testWidgets('fifty seconds holding does not pay ten days of bond interest', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalTradingRepository();
    final assets = await repository.getAssets();
    final bond = assets.firstWhere((a) => a.type == AssetType.bond);
    await repository.savePositions([
      Position(
        id: 'new-bond',
        assetId: bond.id,
        symbol: bond.symbol,
        name: bond.name,
        type: bond.type,
        amount: 100,
        averageBuyPrice: bond.currentPrice,
        currentPrice: bond.currentPrice,
        openedAt: DateTime.now(),
      ),
    ]);
    final portfolio = PortfolioProvider(repository: repository);

    for (var i = 0; i < 100 && portfolio.isLoading; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(portfolio.isLoading, isFalse);
    portfolio.newsService.dispose();
    final cash = portfolio.cash;
    await tester.pump(const Duration(seconds: 50));
    await tester.pump();
    expect(portfolio.cash - cash, lessThan(0.10));
    portfolio.dispose();
  });
}
