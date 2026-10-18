import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/ui/widgets/motion_safe.dart';

void main() {
  Widget host({required bool reduceMotion}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => const Text('hallo').motionSafe(
          context,
          effects: [FadeEffect(duration: 400.ms, delay: 100.ms)],
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

  testWidgets('reduce motion shows the end state immediately', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    expect(opacity(tester), 1.0);
    await tester.pump(const Duration(seconds: 1));
    expect(opacity(tester), 1.0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without reduce motion the effect still fades in', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: false));
    expect(opacity(tester), lessThan(1.0));
    // flutter_animate starts through a timer and a ticker: pump in small steps.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(opacity(tester), 1.0);
    await tester.pumpWidget(const SizedBox());
  });
}
