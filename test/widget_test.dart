import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/logic/market_engine.dart';
import 'package:trading_game/main.dart';

void main() {
  testWidgets('TradingGameApp launches smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TradingGameApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Verify main screen renders
    expect(find.text('TRADING GAME'), findsWidgets);

    // Stop background engine timer before disposing test
    MarketEngine().stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
