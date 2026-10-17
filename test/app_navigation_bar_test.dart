import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/ui/widgets/app_navigation_bar.dart';

void main() {
  testWidgets(
    'five destinations remain readable at 375px and double text size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              bottomNavigationBar: AppNavigationBar(
                selectedIndex: 0,
                onSelected: (index) => selected = index,
              ),
            ),
          ),
        ),
      );
      for (final label in [
        'Übersicht',
        'Märkte',
        'Portfolio',
        'Aktivität',
        'Mehr',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Portfolio'));
      expect(selected, 2);
      await tester.tap(find.text('Mehr'));
      expect(selected, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
