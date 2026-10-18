import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/auth_provider.dart';
import 'package:trading_game/logic/bank_hours.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/bank_loan_screen.dart';

class _SignedOut extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bank is open Monday to Friday only', () {
    // 2026-10-12 is a Monday.
    for (var d = 12; d <= 16; d++) {
      expect(
        BankHours.isOpen(DateTime(2026, 10, d, 3)),
        isTrue,
        reason: 'day $d',
      );
      expect(BankHours.isOpen(DateTime(2026, 10, d, 23, 59)), isTrue);
    }
    expect(BankHours.isOpen(DateTime(2026, 10, 17, 12)), isFalse); // Saturday
    expect(BankHours.isOpen(DateTime(2026, 10, 18, 12)), isFalse); // Sunday
  });

  group('taking a loan', () {
    late PortfolioProvider portfolio;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
      portfolio.newsService.dispose();
    });
    tearDown(() => portfolio.dispose());

    test('is refused on the weekend with a clear reason', () async {
      portfolio.bankClock = () => DateTime(2026, 10, 17, 12);
      final before = portfolio.cash;
      final loansBefore = portfolio.loans.length;
      expect(portfolio.isBankOpen, isFalse);
      expect(portfolio.canTakeLoan, isFalse);
      expect(
        await portfolio.takeLoan(principal: 1000, durationDays: 30),
        isFalse,
      );
      expect(portfolio.lastAlertMessage, contains('Montag bis Freitag'));
      expect(portfolio.cash, before);
      expect(portfolio.loans.length, loansBefore);
    });

    test('works on a weekday', () async {
      portfolio.bankClock = () => DateTime(2026, 10, 14, 12);
      final loansBefore = portfolio.loans.length;
      expect(portfolio.canTakeLoan, isTrue);
      expect(
        await portfolio.takeLoan(principal: 1000, durationDays: 30),
        isTrue,
      );
      expect(portfolio.loans.length, loansBefore + 1);
    });

    test('repaying stays possible on the weekend', () async {
      portfolio.bankClock = () => DateTime(2026, 10, 14, 12);
      await portfolio.takeLoan(principal: 1000, durationDays: 30);
      final loan = portfolio.loans.first;
      portfolio.bankClock = () => DateTime(2026, 10, 17, 12);
      expect(await portfolio.repayLoan(loan, 100), isTrue);
    });
  });
  for (final weekend in [true, false]) {
    testWidgets(
      weekend
          ? 'the bank screen explains the weekend and disables the request'
          : 'the bank screen is quiet on a weekday',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(400, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
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
        addTearDown(portfolio.dispose);
        addTearDown(auth.dispose);
        portfolio.bankClock = () =>
            weekend ? DateTime(2026, 10, 17, 12) : DateTime(2026, 10, 14, 12);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: portfolio),
              ChangeNotifierProvider.value(value: auth),
            ],
            child: const MaterialApp(home: BankLoanScreen()),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.textContaining('Montag bis Freitag'),
          weekend ? findsOneWidget : findsNothing,
        );
        final button = find.widgetWithText(
          ElevatedButton,
          weekend ? 'Bank geschlossen · wieder ab Montag' : 'Kredit über',
          skipOffstage: false,
        );
        if (weekend) {
          expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
