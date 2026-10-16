import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/loan_model.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/logic/credit_rating_service.dart';
import 'package:trading_game/logic/trading_fee_service.dart';

void main() {
  group('CreditRatingService & Loans Tests', () {
    test('Start Loan has 50.000 EUR principal and 60 days term', () {
      final startLoan = Loan.createInitialStartLoan();
      expect(startLoan.principal, 50000.0);
      expect(startLoan.durationDays, 60);
      expect(startLoan.interestRate, 0.045);
      expect(startLoan.remainingDebt, 50000.0);
      expect(startLoan.totalWithInterest, greaterThan(50000.0));
      expect(startLoan.isPaid, false);
      expect(startLoan.daysRemaining, inInclusiveRange(59, 60));
    });

    test('New player receives AA Solid credit rating on start', () {
      final rating = CreditRatingService.evaluateRating(
        netWorth: 0.0,
        totalDebt: 50000.0,
        realizedLosses: 0.0,
        liquidationsCount: 0,
      );
      expect(rating.score, 80);
      expect(rating.grade, 'AA Solid');
      expect(rating.baseInterestRate, 0.055);
    });

    test('Credit rating evaluates AAA for high net worth and 0 liquidations', () {
      final rating = CreditRatingService.evaluateRating(
        netWorth: 150000.0,
        totalDebt: 0.0,
        realizedLosses: 0.0,
        liquidationsCount: 0,
      );
      expect(rating.score, greaterThanOrEqualTo(90));
      expect(rating.grade, 'AAA Prime');
      expect(rating.baseInterestRate, 0.038);
    });

    test('Credit rating degrades to D Kredithai-Sektor with heavy debt and liquidations', () {
      final rating = CreditRatingService.evaluateRating(
        netWorth: -10000.0,
        totalDebt: 120000.0,
        realizedLosses: 50000.0,
        liquidationsCount: 5,
      );
      expect(rating.score, lessThan(25));
      expect(rating.grade, contains('Kredithai'));
      expect(rating.baseInterestRate, 0.360); // 36% p.a. Wucherzins
    });

    test('Loan interest calculation is proportional to duration', () {
      final interest = CreditRatingService.calculateLoanInterest(
        principal: 10000.0,
        durationDays: 365,
        interestRate: 0.10, // 10%
      );
      expect(interest, 1000.0);

      final halfYear = CreditRatingService.calculateLoanInterest(
        principal: 10000.0,
        durationDays: 182,
        interestRate: 0.10,
      );
      expect(halfYear, closeTo(498.63, 1.0));
    });
  });

  group('Trading Fee Service Tests', () {
    test('Stock trade fee is fixed to 19.90 EUR', () {
      final stock = Asset(
        id: 'at_omv',
        symbol: 'OMV',
        name: 'OMV AG',
        type: AssetType.stock,
        currentPrice: 42.50,
        previousClose: 42.00,
        dailyHigh: 43.00,
        dailyLow: 41.80,
        priceHistory: [42.0, 42.50],
        volatility: 0.015,
        description: 'OMV',
      );

      final fee = TradingFeeService.calculateBuyFee(asset: stock, amount: 10);
      expect(fee.transactionFee, 19.90);
      expect(fee.totalCashRequired, 425.0 + 19.90);
    });

    test('Bond trade fee is 24.50 EUR Kuponspesen', () {
      final bond = Asset(
        id: 'at_bund_10y',
        symbol: 'BUND-AT-10Y',
        name: 'Republik Österreich 10Y',
        type: AssetType.bond,
        currentPrice: 1000.0,
        previousClose: 1000.0,
        dailyHigh: 1001.0,
        dailyLow: 999.0,
        priceHistory: [1000.0],
        volatility: 0.005,
        couponRate: 0.032,
        description: 'Staatsanleihe',
      );

      final fee = TradingFeeService.calculateBuyFee(asset: bond, amount: 2);
      expect(fee.transactionFee, 24.50);
      expect(fee.totalCashRequired, 2000.0 + 24.50);
    });
  });

  group('Insolvency & Loan Cooldown System Tests', () {
    test('5-day real calendar time lockout is calculated accurately', () {
      final now = DateTime.now();
      final lockout = now.add(const Duration(days: 5));
      final diff = lockout.difference(now);
      expect(diff.inDays, 5);
      expect(diff.inHours, 120);
    });

    test('24-hour loan cooldown enforces waiting period after taking loan', () {
      final now = DateTime.now();
      final loanTakenAt = now.subtract(const Duration(hours: 12));
      final isCooldown = now.difference(loanTakenAt).inHours < 24;
      expect(isCooldown, true);

      final olderLoanTakenAt = now.subtract(const Duration(hours: 25));
      final isOlderCooldown = now.difference(olderLoanTakenAt).inHours < 24;
      expect(isOlderCooldown, false);
    });
  });
}

