enum LeaderboardTimeframe {
  allTime,
  day,
  week,
  month,
  quarter,
  halfYear,
  year;

  String get displayName {
    switch (this) {
      case LeaderboardTimeframe.allTime:
        return 'All Time';
      case LeaderboardTimeframe.day:
        return 'Tag (24h)';
      case LeaderboardTimeframe.week:
        return 'Woche';
      case LeaderboardTimeframe.month:
        return 'Monat';
      case LeaderboardTimeframe.quarter:
        return 'Quartal';
      case LeaderboardTimeframe.halfYear:
        return 'Halbjahr';
      case LeaderboardTimeframe.year:
        return 'Jahr';
    }
  }

  String get collectionKey {
    switch (this) {
      case LeaderboardTimeframe.allTime:
        return 'leaderboard_all_time';
      case LeaderboardTimeframe.day:
        return 'leaderboard_day';
      case LeaderboardTimeframe.week:
        return 'leaderboard_week';
      case LeaderboardTimeframe.month:
        return 'leaderboard_month';
      case LeaderboardTimeframe.quarter:
        return 'leaderboard_quarter';
      case LeaderboardTimeframe.halfYear:
        return 'leaderboard_half_year';
      case LeaderboardTimeframe.year:
        return 'leaderboard_year';
    }
  }
}
