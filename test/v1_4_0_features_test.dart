import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/pending_order.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/models/savings_plan.dart';
import 'package:trading_game/logic/savings_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.0 Features: Realistic Order Delay & Savings Plans', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PendingOrder supports scheduled execution time and minutesRemaining', () {
      final scheduled = DateTime.now().add(const Duration(minutes: 10));
      final order = PendingOrder(
        id: 'order_1',
        assetId: 'omv_at',
        symbol: 'OMV.VI',
        name: 'OMV AG',
        assetType: AssetType.stock,
        isBuy: true,
        amount: 10.0,
        estimatedPrice: 42.50,
        totalEstimatedCost: 425.0,
        createdAt: DateTime.now(),
        scheduledExecutionTime: scheduled,
        executionReason: 'Realistic Orderbook Delay',
        brokerVenue: 'Wiener Börse (Xetra)',
      );

      expect(order.scheduledExecutionTime, isNotNull);
      expect(order.minutesRemaining, inInclusiveRange(9, 10));
      expect(order.brokerVenue, 'Wiener Börse (Xetra)');

      final json = order.toJson();
      final restored = PendingOrder.fromJson(json);
      expect(restored.id, order.id);
      expect(restored.scheduledExecutionTime, isNotNull);
      expect(restored.brokerVenue, 'Wiener Börse (Xetra)');
    });

    test('SavingsPlanService creates, toggles, and tracks DCA plans', () async {
      final service = SavingsPlanService();
      await service.initialize();

      expect(service.plans.isEmpty, isTrue);

      final plan = await service.createPlan(
        assetSymbol: 'BTC',
        assetName: 'Bitcoin',
        amountEur: 100.0,
        frequency: SavingsPlanFrequency.daily,
      );

      expect(service.plans.length, 1);
      expect(plan.assetSymbol, 'BTC');
      expect(plan.amountEur, 100.0);
      expect(plan.isActive, isTrue);

      // Toggle plan
      await service.togglePlan(plan.id);
      expect(service.plans.first.isActive, isFalse);

      // Toggle back
      await service.togglePlan(plan.id);
      expect(service.plans.first.isActive, isTrue);

      // Check due plans
      final duePlans = service.getDuePlans();
      expect(duePlans.length, 1);

      // Record execution
      await service.markExecuted(plan.id, 100.0);
      expect(service.plans.first.totalInvested, 100.0);

      // Now not due immediately
      expect(service.getDuePlans().isEmpty, isTrue);

      // Delete plan
      await service.deletePlan(plan.id);
      expect(service.plans.isEmpty, isTrue);
    });

    test('Short position is treated as leveraged margin contract and calculates PnL correctly', () {
      final short1x = Position(
        id: 'short_1',
        assetId: 'btc',
        symbol: 'BTC',
        name: 'Bitcoin',
        type: AssetType.crypto,
        amount: 1.0,
        averageBuyPrice: 100.0,
        currentPrice: 90.0,
        leverage: 1,
        isShort: true,
      );

      expect(short1x.isLeveraged, isTrue);
      expect(short1x.collateral, 100.0);
      expect(short1x.liquidationPrice, closeTo(190.0, 0.01));
      // Price dropped from 100 to 90 -> profit of +10 EUR
      expect(short1x.unrealizedPnL, closeTo(10.0, 0.01));
      expect(short1x.currentValue, closeTo(110.0, 0.01));

      // Price rose from 100 to 110 -> loss of -10 EUR
      final shortLoss = short1x.copyWith(currentPrice: 110.0);
      expect(shortLoss.unrealizedPnL, closeTo(-10.0, 0.01));
      expect(shortLoss.currentValue, closeTo(90.0, 0.01));

      // Partial sell scaling: 50% sold, remaining collateral is scaled
      final remainingPos = short1x.copyWith(
        amount: 0.5,
        collateral: short1x.collateral * 0.5,
      );
      expect(remainingPos.amount, 0.5);
      expect(remainingPos.collateral, 50.0);
    });
  });
}
