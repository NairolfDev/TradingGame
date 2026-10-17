import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/loan_model.dart';
import 'package:trading_game/data/models/market_schedule.dart';
import 'package:trading_game/logic/notification_planner.dart';

Loan loan(String id, DateTime due, {bool paid = false}) => Loan(
  id: id,
  title: 'Kredit $id',
  principal: 1000,
  interestRate: 0.05,
  remainingDebt: 1050.5,
  takenAt: DateTime(2026, 1, 1),
  dueDate: due,
  durationDays: 30,
  isPaid: paid,
);

void main() {
  test('market events skip weekends and carry order counts', () {
    // Friday 2026-10-16, 18:00: Vienna already closed, next is Monday 09:00.
    final plan = planMarketNotifications(
      regions: {MarketRegion.viennaEurope, MarketRegion.crypto24_7},
      from: DateTime(2026, 10, 16, 18),
      pendingOrders: {MarketRegion.viennaEurope: 2},
      eventsPerRegion: 2,
    );
    expect(plan.length, 2);
    expect(plan.first.at, DateTime(2026, 10, 19, 9));
    expect(plan.first.title, 'Wiener Börse / Xetra öffnet');
    expect(plan.first.body, contains('2 offene Orders'));
    expect(plan.last.at, DateTime(2026, 10, 19, 17, 30));
    expect(plan.last.title, contains('schließt'));
    expect(plan.every((p) => p.category == NotificationCategory.markets), true);
  });

  test('only future moments are planned and ids are unique', () {
    final plan = planMarketNotifications(
      regions: {
        MarketRegion.viennaEurope,
        MarketRegion.usWallStreet,
        MarketRegion.asiaTokyoHongKong,
      },
      from: DateTime(2026, 10, 14, 12), // Wednesday midday
    );
    expect(plan.every((p) => p.at.isAfter(DateTime(2026, 10, 14, 12))), true);
    expect(plan.map((p) => p.id).toSet().length, plan.length);
    expect(plan.length, 12);
  });

  test('crypto and empty regions plan nothing', () {
    expect(
      planMarketNotifications(
        regions: {MarketRegion.crypto24_7},
        from: DateTime(2026, 10, 14),
      ),
      isEmpty,
    );
  });

  test('loan reminders: day before and due, skipping paid and past', () {
    final now = DateTime(2026, 10, 17, 12);
    final plan = planLoanNotifications([
      loan('a', DateTime(2026, 10, 20, 12)),
      loan('b', DateTime(2026, 10, 17, 18)), // due in 6h: no "tomorrow" hint
      loan('c', DateTime(2026, 10, 1), paid: false), // overdue: nothing new
      loan('d', DateTime(2026, 10, 25), paid: true),
    ], now);
    expect(plan.map((p) => p.title), [
      'Kredit jetzt fällig', // b at 18:00
      'Kredit morgen fällig', // a at 19.10. 12:00
      'Kredit jetzt fällig', // a at 20.10. 12:00
    ]);
    expect(plan.first.body, contains('1050,50 €'));
    expect(plan.map((p) => p.id).toSet().length, plan.length);
  });
}
