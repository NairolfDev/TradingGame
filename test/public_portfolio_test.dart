import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/copy_trader.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/models/transaction.dart';
import 'package:trading_game/logic/public_portfolio.dart';

Position pos(
  String symbol,
  num amount, {
  AssetType type = AssetType.stock,
  int leverage = 1,
}) => Position(
  id: symbol,
  assetId: symbol,
  symbol: symbol,
  name: symbol,
  type: type,
  amount: amount.toDouble(),
  averageBuyPrice: 10,
  currentPrice: 10,
  leverage: leverage,
);

TransactionRecord sell(double pnl) => TransactionRecord(
  id: '$pnl',
  symbol: 'X',
  name: 'X',
  type: TransactionType.sell,
  amount: 1,
  price: 1,
  totalAmount: 1,
  realizedPnL: pnl,
  timestamp: DateTime(2026, 10, 19),
);

CopyTrader build(List<Position> p, [List<TransactionRecord> t = const []]) =>
    buildPublicPortfolio(
      uid: 'u',
      name: 'Flo',
      title: 'Trader',
      netWorth: 60000,
      roiPercent: 20,
      positions: p,
      transactions: t,
    );

void main() {
  test('weights sum to one, hold no amounts and skip leveraged contracts', () {
    final t = build([
      pos('AAA', 30),
      pos('BBB', 10),
      pos('LEV', 50, leverage: 10),
    ]);
    expect(t.portfolioAllocation.keys, containsAll(['AAA', 'BBB']));
    expect(t.portfolioAllocation.containsKey('LEV'), isFalse);
    expect(
      t.portfolioAllocation.values.fold<double>(0.0, (a, b) => a + b),
      closeTo(1, 1e-9),
    );
    expect(t.portfolioAllocation['AAA'], closeTo(0.75, 1e-9));
    expect(t.riskStyle, 'Aggressiv');
  });

  test('keeps at most eight holdings and the win rate from sells', () {
    final t = build(
      [for (var i = 0; i < 12; i++) pos('S$i', 1.0 + i)],
      [sell(5), sell(-2), sell(3), sell(1)],
    );
    expect(t.portfolioAllocation.length, 8);
    expect(t.winRatePercent, 75);
  });

  test('an empty portfolio has nothing to copy', () {
    expect(build([]).portfolioAllocation, isEmpty);
  });
}
