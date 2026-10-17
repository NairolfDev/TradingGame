enum RewardKind { buy, profit, loss, quest, achievement, purchase }

/// A moment worth celebrating (or acknowledging) in the UI.
class RewardEvent {
  final RewardKind kind;
  final String title;
  final String detail;
  final double? cash;
  final int prestige;

  const RewardEvent({
    required this.kind,
    required this.title,
    required this.detail,
    this.cash,
    this.prestige = 0,
  });
}
