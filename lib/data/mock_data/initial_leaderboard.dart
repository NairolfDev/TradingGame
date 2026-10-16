import '../models/leaderboard_entry.dart';

class InitialLeaderboard {
  /// Keine Mock-Bots: Nur echte Online-Spieler aus dem Firebase Cloud Leaderboard
  static List<LeaderboardEntry> getCompetitors() {
    return [];
  }
}
