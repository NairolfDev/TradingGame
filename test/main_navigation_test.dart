import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:trading_game/ui/screens/more_screen.dart';
import 'package:trading_game/logic/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/core/constants/app_theme.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/auth_provider.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/main_screen.dart';

class _SignedOut extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

void main() {
  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets(
      'navigation keeps market search and exposes secondary pages at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        late PortfolioProvider portfolio;
        late AuthProvider auth;
        await tester.runAsync(() async {
          portfolio = PortfolioProvider(repository: LocalTradingRepository());
          auth = AuthProvider(firebaseAuth: _SignedOut());
          while (portfolio.isLoading || auth.isLoading) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          portfolio.marketEngine.stop();
          portfolio.newsService.dispose();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: portfolio),
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider(create: (_) => ThemeController()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: const TextScaler.linear(2),
                ),
                child: const MainScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        final prefix = width >= 1000 ? 'desktop-destination-' : 'destination-';
        await tester.tap(find.byKey(ValueKey('${prefix}1')));
        await tester.pump();
        final search = find.widgetWithText(
          TextField,
          'Instrument suchen',
        );
        await tester.enterText(search, 'Erste');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(ValueKey('${prefix}4')));
        await tester.pump();
        expect(find.text('Bank & Kredite'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Einstellungen'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(MoreScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Einstellungen'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('${prefix}1')));
        await tester.pump();
        expect(tester.widget<TextField>(search).controller!.text, 'Erste');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        portfolio.dispose();
        auth.dispose();
      },
    );
  }
}
