import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/pending_order.dart';
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
  });
}
