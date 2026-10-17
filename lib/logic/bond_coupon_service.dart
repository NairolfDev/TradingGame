import '../data/models/position.dart';

class BondCouponService {
  /// Actual/365 accrual; the cursor advances only when this amount is credited.
  static double accrued({
    required Position position,
    required double annualRate,
    required DateTime paidThrough,
    required DateTime now,
  }) {
    final start = paidThrough.isAfter(position.openedAt)
        ? paidThrough
        : position.openedAt;
    final elapsed = now.difference(start).inMicroseconds;
    if (elapsed <= 0 ||
        !position.amount.isFinite ||
        position.amount <= 0 ||
        !position.currentPrice.isFinite ||
        position.currentPrice <= 0 ||
        !annualRate.isFinite ||
        annualRate <= 0) {
      return 0;
    }
    final payout =
        position.amount *
        position.currentPrice *
        annualRate *
        (elapsed / (Duration.microsecondsPerDay * 365));
    return payout.isFinite ? payout : 0;
  }
}
