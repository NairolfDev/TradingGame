import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/leaderboard_entry.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/leaderboard_screen.dart';

LeaderboardEntry entry(
  String id,
  String name,
  double worth, {
  bool me = false,
}) => LeaderboardEntry(
  id: id,
  name: name,
  city: 'Österreich',
  title: 'Retail Trader',
  badge: '',
  avatarEmoji: '👤',
  strategy: 'Multi-Asset',
  netWorth: worth,
  roiPercent: (worth - 50000) / 500,
  isPlayer: me,
);

List<LeaderboardEntry> rank(List<LeaderboardEntry> base, double mine) =>
    rankLeaderboard(
      base,
      playerNetWorth: mine,
      playerRoiPercent: 0,
      playerCity: 'AT',
      playerTitle: 'Anfänger',
      playerBadge: '',
    );

void main() {
  test('ranks by live net worth and strips the "Du (…)" prefix', () {
    final r = rank([
      entry('a', 'Anna', 60000),
      entry('me', 'Du (Flo)', 10000, me: true),
      entry('b', 'Ben', 55000),
    ], 58000);
    expect(r.map((e) => e.name), ['Anna', 'Flo', 'Ben']);
    expect(r.map((e) => e.rank), [1, 2, 3]);
  });

  test('a player missing from the list is added at the right place', () {
    final r = rank([
      entry('a', 'Anna', 60000),
      entry('b', 'Ben', 40000),
    ], 50000);
    expect(r.map((e) => e.name), ['Anna', 'Du', 'Ben']);
    expect(r.firstWhere((e) => e.isPlayer).rank, 2);
  });

  testWidgets('long names do not overflow on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late PortfolioProvider portfolio;
    await tester.runAsync(() async {
      final repo = LocalTradingRepository();
      await repo.saveLeaderboard([
        entry('a', 'Ein sehr sehr langer Spielername ohne Ende', 90000),
        entry('b', 'Bea', 70000),
        entry('c', 'Cem', 60000),
        entry('d', 'Dora', 30000),
      ]);
      portfolio = PortfolioProvider(repository: repo);
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      portfolio.marketEngine.stop();
      portfolio.newsService.dispose();
    });
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: portfolio,
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Dein Rang'), findsOneWidget);
    expect(find.text('Du'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
