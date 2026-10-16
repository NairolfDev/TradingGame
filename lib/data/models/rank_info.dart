import 'package:flutter/material.dart';

class RankInfo {
  final int level;
  final String title;
  final double minNetWorth;
  final String badge;
  final Color color;
  final String description;

  const RankInfo({
    required this.level,
    required this.title,
    required this.minNetWorth,
    required this.badge,
    required this.color,
    required this.description,
  });

  static const List<RankInfo> ranks = [
    RankInfo(
      level: 1,
      title: 'Börsen-Praktikant',
      minNetWorth: -999999999.0,
      badge: '☕',
      color: Color(0xFF8B9CB2),
      description: 'Lerne die Grundlagen, starte mit 50.000 € Kredit und sammle Erfahrung.',
    ),
    RankInfo(
      level: 2,
      title: 'Junior Retail Trader',
      minNetWorth: 10000.0,
      badge: '📈',
      color: Color(0xFF00B0FF),
      description: 'Erste 10.000 € Reingewinn erzielt. Eigene Markt-Strategie greift.',
    ),
    RankInfo(
      level: 3,
      title: 'Floor Broker',
      minNetWorth: 50000.0,
      badge: '💼',
      color: Color(0xFF00E676),
      description: '50.000 € Reinvermögen! Startkredit voll reingeholt, nun schuldenfrei.',
    ),
    RankInfo(
      level: 4,
      title: 'Senior Portfolio Manager',
      minNetWorth: 150000.0,
      badge: '🏆',
      color: Color(0xFFFFD700),
      description: 'Verwaltet ein sechsstelliges Reinvermögen mit kühlem Kopf.',
    ),
    RankInfo(
      level: 5,
      title: 'Hedgefonds-Direktor',
      minNetWorth: 500000.0,
      badge: '👑',
      color: Color(0xFFFF7A00),
      description: 'Nutzt aggressive Hebel, bewegt Märkte nach Belieben.',
    ),
    RankInfo(
      level: 6,
      title: 'Wall Street Legende',
      minNetWorth: 1000000.0,
      badge: '💎',
      color: Color(0xFFAB47BC),
      description: 'Millionär. Luxus-Penthouses und Sportwagen zieren deinen Alltag.',
    ),
    RankInfo(
      level: 7,
      title: 'Finanz-Oligarch',
      minNetWorth: 2500000.0,
      badge: '🔱',
      color: Color(0xFFE040FB),
      description: 'Die weltweiten Börsen tanzen nach deiner Pfeife. Unantastbar.',
    ),
  ];

  static RankInfo getRankForNetWorth(double netWorth) {
    RankInfo current = ranks.first;
    for (final rank in ranks) {
      if (netWorth >= rank.minNetWorth) {
        current = rank;
      }
    }
    return current;
  }

  static RankInfo? getNextRank(double netWorth) {
    for (final rank in ranks) {
      if (netWorth < rank.minNetWorth) {
        return rank;
      }
    }
    return null; // Höchster Rang bereits erreicht
  }
}
