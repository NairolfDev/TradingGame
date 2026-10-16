class CreditRating {
  final int score; // 0 - 100
  final String grade; // AAA, A, BBB, BB, CCC, D
  final String description;
  final double baseInterestRate; // p.a.

  const CreditRating({
    required this.score,
    required this.grade,
    required this.description,
    required this.baseInterestRate,
  });
}

class CreditRatingService {
  /// Berechnet die Bonität des Spielers anhand seiner Trading-Historie und Schulden
  static CreditRating evaluateRating({
    required double netWorth,
    required double totalDebt,
    required double realizedLosses,
    required int liquidationsCount,
  }) {
    int score = 80; // Solider Startwert (AA Solid für jeden Neustarter)

    // Positiver Net Worth belohnt solide Trader
    if (netWorth >= 100000) {
      score += 15;
    } else if (netWorth >= 30000) {
      score += 8;
    } else if (netWorth < -35000) {
      score -= 30; // Tief überschuldet
    } else if (netWorth < -10000) {
      score -= 15;
    }

    // Hebel-Liquidationsabzug (Zocken mit 50x CFDs zerstört die Bonität!)
    score -= (liquidationsCount * 15);

    // Schuldenlast: Belastung über den 50k Startkredit hinaus
    if (totalDebt > 120000) {
      score -= 30;
    } else if (totalDebt > 75000) {
      score -= 15;
    } else if (totalDebt <= 0 && netWorth > 10000) {
      // Schuldenfreiheit & solider Gewinn belohnen
      score += 10;
    }

    // Verlustabzug
    if (realizedLosses > 30000) {
      score -= 20;
    } else if (realizedLosses > 10000) {
      score -= 10;
    }

    score = score.clamp(5, 100);

    if (score >= 90) {
      return const CreditRating(
        score: 95,
        grade: 'AAA Prime',
        description: 'Exzellente Bonität. Beste Zinsen am Markt.',
        baseInterestRate: 0.038, // 3,8% p.a.
      );
    } else if (score >= 75) {
      return CreditRating(
        score: score,
        grade: 'AA Solid',
        description: 'Sehr solide Bonität der österreichischen Großbanken.',
        baseInterestRate: 0.055, // 5,5% p.a.
      );
    } else if (score >= 60) {
      return CreditRating(
        score: score,
        grade: 'BBB Standard',
        description: 'Durchschnittliche Kreditwürdigkeit mit moderatem Risikoaufschlag.',
        baseInterestRate: 0.089, // 8,9% p.a.
      );
    } else if (score >= 40) {
      return CreditRating(
        score: score,
        grade: 'BB Risikobehaftet',
        description: 'Erhöhte Verluste oder Hebel-Liquidationsspuren. Hohe Zinsen.',
        baseInterestRate: 0.145, // 14,5% p.a.
      );
    } else if (score >= 25) {
      return CreditRating(
        score: score,
        grade: 'CCC Hochrisiko',
        description: 'Schwere finanzielle Schieflage. Banken verlangen Notfallzuschlag.',
        baseInterestRate: 0.225, // 22,5% p.a.
      );
    } else {
      return CreditRating(
        score: score,
        grade: 'D Kredithai-Sektor',
        description: 'Faktisch pleite. Kredite werden nur noch zu Wucherzinsen vergeben!',
        baseInterestRate: 0.360, // 36,0% p.a.
      );
    }
  }

  static double calculateLoanInterest({
    required double principal,
    required int durationDays,
    required double interestRate,
  }) {
    return principal * interestRate * (durationDays / 365);
  }
}
