import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/core/constants/app_colors.dart';
import 'package:trading_game/data/models/reward_event.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/logic/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme controller switches all four palettes and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeController(platformBrightness: () => Brightness.dark);
    await Future<void>.delayed(Duration.zero);
    expect(AppColors.palette, same(AppPalette.gameDark));
    expect(AppColors.isGamer, isTrue);

    await theme.setDark(false);
    expect(AppColors.palette, same(AppPalette.gameLight));
    await theme.setStyle(AppStyle.schlicht);
    expect(AppColors.palette, same(AppPalette.simpleLight));
    expect(AppColors.isGamer, isFalse);
    await theme.setDark(true);
    expect(AppColors.palette, same(AppPalette.simpleDark));

    final restored = ThemeController(platformBrightness: () => Brightness.dark);
    await Future<void>.delayed(Duration.zero);
    expect(restored.style, AppStyle.schlicht);
    expect(restored.isDark, isTrue);
    await theme.setStyle(AppStyle.gamer); // reset global palette
    theme.dispose();
    restored.dispose();
  });

  test('buy and sell emit reward events with realized result', () async {
    SharedPreferences.setMockInitialValues({});
    final portfolio = PortfolioProvider(repository: LocalTradingRepository());
    while (portfolio.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    portfolio.marketEngine.stop();
    portfolio.newsService.dispose();
    await portfolio.setRealisticOrderDelay(false);
    final events = <RewardEvent>[];
    final sub = portfolio.rewards.listen(events.add);

    final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    expect(await portfolio.executeBuy(asset: asset, amount: 0.01), isTrue);
    asset.currentPrice *= 1.5;
    final position = portfolio.positions.firstWhere(
      (p) => p.assetId == asset.id,
    );
    expect(
      await portfolio.executeSell(position: position, sellAmount: 0.01),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);

    final trades = events
        .where((e) => e.kind != RewardKind.achievement)
        .toList();
    expect(trades.first.kind, RewardKind.buy);
    expect(trades.first.cash, lessThan(0));
    expect(trades.last.kind, RewardKind.profit);
    expect(trades.last.cash, greaterThan(0));
    await sub.cancel();
    portfolio.dispose();
  });
}
