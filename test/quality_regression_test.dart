import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PortfolioProvider portfolio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    portfolio = PortfolioProvider(repository: LocalTradingRepository());
    while (portfolio.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    portfolio.marketEngine.stop();
    portfolio.newsService.dispose();
    await portfolio.setRealisticOrderDelay(false);
  });

  tearDown(() => portfolio.dispose());

  test('start loan does not block the first additional bank loan', () {
    expect(portfolio.canTakeLoan, isTrue);
  });

  test(
    'fresh offline profile receives no fabricated global ranking reward',
    () {
      expect(portfolio.cash, LocalTradingRepository.initialStartingCash);
      expect(portfolio.loginStreakDays, 1);
    expect(portfolio.totalRoiPercent, 0);
      final tradeQuest = portfolio.dailyQuests.firstWhere(
        (q) => q.id == 'quest_1',
      );
      expect(tradeQuest.currentValue, 0);
    },
  );

  test('invalid buy quantities and leverage do not change cash', () async {
    final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    final cash = portfolio.cash;
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(await portfolio.executeBuy(asset: asset, amount: amount), isFalse);
    }
    expect(
      await portfolio.executeBuy(asset: asset, amount: 0.01, leverage: 0),
      isFalse,
    );
    expect(
      await portfolio.executeBuy(asset: asset, amount: 0.01, leverage: 999),
      isFalse,
    );
    expect(portfolio.cash, cash);
    expect(portfolio.positions, isEmpty);
  });

  test(
    'a sold position cannot be sold again using its old reference',
    () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      expect(await portfolio.executeBuy(asset: asset, amount: 0.01), isTrue);
      final position = portfolio.positions.last;
      expect(
        await portfolio.executeSell(
          position: position,
          sellAmount: position.amount,
        ),
        isTrue,
      );
      final cash = portfolio.cash;
      expect(
        await portfolio.executeSell(
          position: position,
          sellAmount: position.amount,
        ),
        isFalse,
      );
      expect(portfolio.cash, cash);
    },
  );

  test('invalid loan amounts and duration are rejected', () async {
    final cash = portfolio.cash;
    for (final principal in [-1.0, 0.0, double.nan, double.infinity]) {
      expect(
        await portfolio.takeLoan(principal: principal, durationDays: 30),
        isFalse,
      );
    }
    expect(
      await portfolio.takeLoan(principal: 1000, durationDays: -1),
      isFalse,
    );
    expect(portfolio.cash, cash);
  });

  test('recovery loan cannot be used outside insolvency', () async {
    final cash = portfolio.cash;
    expect(await portfolio.takeSanierungsKredit(), isFalse);
    expect(portfolio.cash, cash);
  });

  test('dividends can only be claimed once per calendar month', () {
    // Explicit simulation fixture: sourced stock catalogs do not invent yields.
    final asset = portfolio.assets.first.copyWith(
      dividendYield: 0.05,
      currentPrice: 100,
    );
    portfolio.assets[0] = asset;
    // Use an owned spot position so the payout exercises real dividend calculation.
    portfolio.positions.add(
      Position(
        id: 'dividend-test',
        assetId: asset.id,
        symbol: asset.symbol,
        name: asset.name,
        type: asset.type,
        amount: 10,
        averageBuyPrice: asset.currentPrice,
        currentPrice: asset.currentPrice,
      ),
    );
    portfolio.payoutSimulatedDividends();
    final cash = portfolio.cash;
    portfolio.payoutSimulatedDividends();
    expect(portfolio.cash, cash);
    expect(
      portfolio.transactions.where((t) => t.symbol == 'DIV'),
      hasLength(1),
    );
  });

  test('no fabricated copy traders are offered', () {
    expect(portfolio.copyTraders, isEmpty);
  });

  test('concurrent sells cannot spend the same position twice', () async {
    final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    await portfolio.executeBuy(asset: asset, amount: 0.01);
    final position = portfolio.positions.last;
    final results = await Future.wait([
      portfolio.executeSell(position: position, sellAmount: position.amount),
      portfolio.executeSell(position: position, sellAmount: position.amount),
    ]);
    expect(results.where((r) => r), hasLength(1));
  });

  test('cash reserved for a pending order remains part of net worth', () async {
    final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    await portfolio.setRealisticOrderDelay(true);
    final before = portfolio.netWorth;
    await portfolio.executeBuy(asset: asset, amount: 0.01);
    expect(portfolio.netWorth, before);
  });

  test(
    'buy confirmation uses current catalog asset rather than a stale copy',
    () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      final stale = asset.copyWith(currentPrice: 1);
      expect(await portfolio.executeBuy(asset: stale, amount: 0.01), isTrue);
      expect(portfolio.positions.last.averageBuyPrice, asset.currentPrice);
    },
  );

  test(
    'recovery loan is available after the declared five day lockout',
    () async {
      await portfolio.repository.saveInsolvencyStatus(
        isInsolvent: true,
        lockoutUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
      portfolio.dispose();
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(portfolio.canTakeRecoveryLoan, isTrue);
      expect(await portfolio.takeSanierungsKredit(), isTrue);
      expect(await portfolio.takeSanierungsKredit(), isFalse);
    },
  );

  test(
    'declared insolvency blocks recovery during the five day lockout',
    () async {
      await portfolio.declareInsolvency();
      expect(portfolio.canTakeRecoveryLoan, isFalse);
      expect(await portfolio.takeSanierungsKredit(), isFalse);
    },
  );
}
