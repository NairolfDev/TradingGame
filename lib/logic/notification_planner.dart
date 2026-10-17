import '../data/models/loan_model.dart';
import '../data/models/market_schedule.dart';

enum NotificationCategory { alerts, orders, markets, loans }

extension NotificationCategoryLabel on NotificationCategory {
  String get label => switch (this) {
    NotificationCategory.alerts => 'Kursalarme',
    NotificationCategory.orders => 'Orders ausgeführt',
    NotificationCategory.markets => 'Börse öffnet/schließt',
    NotificationCategory.loans => 'Kredite & Erfolge',
  };
}

/// A local notification to be scheduled by the platform.
class PlannedNotification {
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final NotificationCategory category;
  const PlannedNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.category,
  });
}

const _scheduledRegions = [
  MarketRegion.viennaEurope,
  MarketRegion.usWallStreet,
  MarketRegion.asiaTokyoHongKong,
];

/// Next open/close moments (device-local time, like [MarketSchedule]) for the
/// given regions. [pendingOrders] tailors the opening text.
List<PlannedNotification> planMarketNotifications({
  required Set<MarketRegion> regions,
  required DateTime from,
  Map<MarketRegion, int> pendingOrders = const {},
  int eventsPerRegion = 4,
}) {
  final planned = <PlannedNotification>[];
  for (final region in _scheduledRegions.where(regions.contains)) {
    final hours = MarketSchedule(region).tradingMinutes!;
    final events = <({DateTime at, bool open})>[];
    for (var d = 0; d < 10 && events.length < eventsPerRegion; d++) {
      final day = DateTime(from.year, from.month, from.day + d);
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        continue;
      }
      DateTime at(int minutes) =>
          DateTime(day.year, day.month, day.day, 0, minutes);
      for (final e in [
        (at: at(hours.open), open: true),
        (at: at(hours.close), open: false),
      ]) {
        if (e.at.isAfter(from) && events.length < eventsPerRegion) {
          events.add(e);
        }
      }
    }
    final pending = pendingOrders[region] ?? 0;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      planned.add(
        PlannedNotification(
          id: 100 + _scheduledRegions.indexOf(region) * 10 + i,
          at: e.at,
          category: NotificationCategory.markets,
          title: '${region.shortName} ${e.open ? 'öffnet' : 'schließt'}',
          body: !e.open
              ? 'Der Handel ist für heute beendet.'
              : pending > 0
              ? '$pending offene Order${pending == 1 ? '' : 's'} '
                    'werden ausgeführt, sobald die App läuft.'
              : 'Jetzt kannst du handeln.',
        ),
      );
    }
  }
  return planned..sort((a, b) => a.at.compareTo(b.at));
}

/// Reminders one day before and at the due moment of every unpaid loan.
List<PlannedNotification> planLoanNotifications(
  List<Loan> loans,
  DateTime now,
) {
  final planned = <PlannedNotification>[];
  final open = loans.where((l) => !l.isPaid).take(10).toList();
  for (var i = 0; i < open.length; i++) {
    final loan = open[i];
    final due = loan.dueDate;
    final debt = loan.remainingDebt.toStringAsFixed(2).replaceAll('.', ',');
    final early = due.subtract(const Duration(days: 1));
    if (early.isAfter(now)) {
      planned.add(
        PlannedNotification(
          id: 200 + i * 2,
          at: early,
          category: NotificationCategory.loans,
          title: 'Kredit morgen fällig',
          body: '„${loan.title}“: Restschuld $debt €.',
        ),
      );
    }
    if (due.isAfter(now)) {
      planned.add(
        PlannedNotification(
          id: 201 + i * 2,
          at: due,
          category: NotificationCategory.loans,
          title: 'Kredit jetzt fällig',
          body: '„${loan.title}“: Restschuld $debt €. Bitte zurückzahlen.',
        ),
      );
    }
  }
  return planned..sort((a, b) => a.at.compareTo(b.at));
}
