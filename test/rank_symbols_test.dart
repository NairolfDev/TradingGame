import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/rank_info.dart';
import 'package:trading_game/ui/widgets/rank_badge.dart';

void main() {
  test('every rank has its own vector symbol', () {
    final symbols = RankInfo.ranks.map((r) => r.symbol.codePoint).toSet();
    expect(symbols.length, RankInfo.ranks.length);
  });

  testWidgets('the rank badge draws an icon, not an emoji', (tester) async {
    for (final rank in RankInfo.ranks) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RankBadge(rank: rank))),
      );
      expect(find.byIcon(rank.symbol), findsWidgets, reason: rank.title);
      expect(find.text(rank.badge), findsNothing, reason: rank.title);
    }
  });
}
