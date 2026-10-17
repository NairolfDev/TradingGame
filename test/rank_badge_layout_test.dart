import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/rank_info.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/prestige_shop_screen.dart';
import 'package:trading_game/ui/widgets/rank_badge.dart';

void main() {
  testWidgets('prestige rank header fits a phone with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'tg_cash_balance': 200000.0});
    late PortfolioProvider portfolio;
    await tester.runAsync(() async {
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
    });
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: portfolio,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PrestigeShopScreen(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Senior Portfolio Manager'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final compact in [false, true]) {
    testWidgets('rank titles wrap in narrow badges (compact: $compact)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final rank in RankInfo.ranks) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SizedBox(
                    width: 218,
                    child: RankBadge(rank: rank, compact: compact),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: rank.title);
        final title = find.text(rank.title);
        expect(title, findsOneWidget);
        final text = tester.widget<Text>(title);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(rank.title))),
          findsWidgets,
        );
        final badgeRect = tester.getRect(find.byType(RankBadge));
        final titleRect = tester.getRect(title);
        expect(titleRect.left, greaterThanOrEqualTo(badgeRect.left));
        expect(titleRect.right, lessThanOrEqualTo(badgeRect.right));
      }
      semantics.dispose();
    });
  }
}
