import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/markets_screen.dart';

void main() {
  testWidgets('search keeps focus when the keyboard opens and prices update', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
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
        child: const MaterialApp(home: MarketsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.tap(search);
    await tester.pump();
    bool hasFocus() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
    expect(hasFocus(), isTrue);

    // Keyboard opens: the body shrinks well below the old 560px threshold.
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    await tester.pump();
    // enterText would re-focus the field and hide the bug, so check first.
    expect(hasFocus(), isTrue, reason: 'keyboard opening must not drop focus');
    await tester.enterText(search, 'Er');
    await tester.pump(const Duration(milliseconds: 300));
    // A price tick rebuilds the screen while typing.
    portfolio.assets.first.currentPrice *= 1.01;
    portfolio.notifyListeners();
    await tester.pump();
    await tester.enterText(search, 'Ers');
    await tester.pump();

    expect(
      hasFocus(),
      isTrue,
      reason: 'the search field must survive layout changes while typing',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
