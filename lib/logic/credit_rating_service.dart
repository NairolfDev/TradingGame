class CreditRating {
  final int score; // 0 - 100
  final String grade; // AAA, A, BBB, BB, CCC, D
  final String description;
  final double baseInterestRate; // p.a.
  final double maxBorrowLimit; // Maximaler Kreditrahmen pro weiterem Kredit
  final double prestigeRateDiscount;
  final double prestigeLimitBonus;

  const CreditRating({
    required this.score,
    required this.grade,
    required this.description,
    required this.baseInterestRate,
    required this.maxBorrowLimit,
    this.prestigeRateDiscount = 0.0,
    this.prestigeLimitBonus = 0.0,
  });
}

class CreditRatingService {
  /// Berechnet die Bonität des Spielers anhand seiner Trading-Historie und Schulden
  static CreditRating evaluateRating({
    required double netWorth,
    required double totalDebt,
    required double realizedLosses,
    required int liquidationsCount,
    int activeLoansCount = 0,
    int prestigePoints = 0,
    int paidLoansCount = 0,
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

    // Schuldenlast: Belastung über den Startkredit hinaus
    if (totalDebt > 120000) {
      score -= 30;
    } else if (totalDebt > 75000) {
      score -= 15;
    } else if (totalDebt <= 0 && netWorth > 10000) {
      // Schuldenfreiheit & solider Gewinn belohnen
      score += 10;
    }

    // Zusätzlicher Malus für viele parallel laufende Kredite
    if (activeLoansCount > 1) {
      score -= (activeLoansCount - 1) * 10;
    }

    // Verlustabzug
    if (realizedLosses > 30000) {
      score -= 20;
    } else if (realizedLosses > 10000) {
      score -= 10;
    }

    if (prestigePoints > 0 || paidLoansCount > 0) {
      score += (prestigePoints ~/ 40).clamp(0, 25) +
          (paidLoansCount * 4).clamp(0, 20);
    }

    score = score.clamp(5, 100);

    // Progressive Zinsanpassung: Mit jedem weiteren aktiven Kredit steigen die Zinsen spürbar!
    double extraLoanSurcharge =
        activeLoansCount > 1 ? (activeLoansCount - 1) * 0.05 : 0.0;
    if (prestigePoints >= 500 && extraLoanSurcharge > 0) {
      extraLoanSurcharge *= 0.25; // 75% Reduktion für prestigeträchtige Trader
    }

    double prestigeLimitBonus = 0.0;
    if (prestigePoints > 0 || paidLoansCount > 0 || netWorth > 150000.0) {
      if (prestigePoints > 0) {
        prestigeLimitBonus += prestigePoints * 500.0 * (score / 50.0);
      }
      if (netWorth > 150000.0) {
        prestigeLimitBonus += (netWorth - 150000.0) * 1.5;
      }
      if (paidLoansCount > 0) {
        prestigeLimitBonus += paidLoansCount * 25000.0;
      }
    }

    final String grade;
    final String description;
    final double rawRate;
    final double rawLimit;
    final int returnedScore;

    if (score >= 90) {
      returnedScore = 95;
      grade = 'AAA Prime';
      description = 'Exzellente Bonität. Beste Zinsen am Markt.';
      rawRate = 0.038 + extraLoanSurcharge; // ab 3,8% p.a.
      rawLimit = 150000.0;
    } else if (score >= 75) {
      returnedScore = score;
      grade = 'AA Solid';
      description = 'Sehr solide Bonität der österreichischen Großbanken.';
      rawRate = 0.055 + extraLoanSurcharge; // ab 5,5% p.a.
      rawLimit = 75000.0;
    } else if (score >= 60) {
      returnedScore = score;
      grade = 'BBB Standard';
      description =
          'Durchschnittliche Kreditwürdigkeit mit moderatem Risikoaufschlag.';
      rawRate = 0.089 + extraLoanSurcharge; // ab 8,9% p.a.
      rawLimit = 50000.0;
    } else if (score >= 40) {
      returnedScore = score;
      grade = 'BB Risikobehaftet';
      description =
          'Erhöhte Verluste oder Hebel-Liquidationsspuren. Hohe Zinsen.';
      rawRate = 0.145 + extraLoanSurcharge; // ab 14,5% p.a.
      rawLimit = 25000.0;
    } else if (score >= 25) {
      returnedScore = score;
      grade = 'CCC Hochrisiko';
      description =
          'Schwere finanzielle Schieflage. Banken verlangen Notfallzuschlag.';
      rawRate = 0.225 + extraLoanSurcharge; // ab 22,5% p.a.
      rawLimit = 15000.0;
    } else {
      returnedScore = score;
      grade = 'D Kredithai-Sektor';
      description =
          'Faktisch pleite. Kredite werden nur noch zu Wucherzinsen vergeben!';
      rawRate = 0.360 + extraLoanSurcharge; // ab 36,0% p.a.
      rawLimit = 10000.0;
    }

    double prestigeRateDiscount = 0.0;
    double finalInterestRate = rawRate;

    if (prestigePoints > 0 || paidLoansCount > 0) {
      final discountFactor = (
        (prestigePoints / 1000.0) * 0.55 +
        (paidLoansCount * 0.04) +
        ((score - 50).clamp(0, 50) / 50.0 * 0.16)
      ).clamp(0.0, 0.75);

      final discounted = rawRate * (1.0 - discountFactor);
      finalInterestRate = discounted < 0.008 ? 0.008 : discounted;
      prestigeRateDiscount = rawRate - finalInterestRate;
    }

    return CreditRating(
      score: returnedScore,
      grade: grade,
      description: description,
      baseInterestRate: finalInterestRate,
      maxBorrowLimit: rawLimit + prestigeLimitBonus,
      prestigeRateDiscount: prestigeRateDiscount,
      prestigeLimitBonus: prestigeLimitBonus,
    );
  }

  static double calculateLoanInterest({
    required double principal,
    required int durationDays,
    required double interestRate,
  }) {
    return principal * interestRate * (durationDays / 365);
  }
}
