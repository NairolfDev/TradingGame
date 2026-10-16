class Loan {
  final String id;
  final String title;
  final double principal; // Ursprünglicher Kreditbetrag
  final double interestRate; // z. B. 0.055 für 5.5% p.a.
  double remainingDebt; // Verbleibende Restschuld
  final DateTime takenAt;
  final DateTime dueDate;
  final int durationDays;
  bool isPaid;
  double paidAmount;

  Loan({
    required this.id,
    required this.title,
    required this.principal,
    required this.interestRate,
    required this.remainingDebt,
    required this.takenAt,
    required this.dueDate,
    required this.durationDays,
    this.isPaid = false,
    this.paidAmount = 0.0,
  });

  int get daysRemaining {
    final diff = dueDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get isOverdue => DateTime.now().isAfter(dueDate) && !isPaid;

  int get elapsedDays {
    final diff = DateTime.now().difference(takenAt).inDays;
    return diff > 0 ? (diff > durationDays ? durationDays : diff) : 0;
  }

  double get accruedInterest {
    final days = elapsedDays > 0 ? elapsedDays : 1;
    return principal * interestRate * (days / 365);
  }

  double get totalWithInterest {
    final interest = principal * interestRate * (durationDays / 365);
    return principal + interest;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'principal': principal,
        'interestRate': interestRate,
        'remainingDebt': remainingDebt,
        'takenAt': takenAt.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'durationDays': durationDays,
        'isPaid': isPaid,
        'paidAmount': paidAmount,
      };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        title: json['title'] as String,
        principal: (json['principal'] as num).toDouble(),
        interestRate: (json['interestRate'] as num).toDouble(),
        remainingDebt: (json['remainingDebt'] as num).toDouble(),
        takenAt: DateTime.parse(json['takenAt'] as String),
        dueDate: DateTime.parse(json['dueDate'] as String),
        durationDays: (json['durationDays'] as num).toInt(),
        isPaid: json['isPaid'] as bool? ?? false,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      );

  static Loan createInitialStartLoan() {
    final now = DateTime.now();
    // 25.000 € Startkredit mit 60 Tagen Frist zu 4,5% p.a.
    return Loan(
      id: 'initial_start_loan_25k',
      title: 'Börsenspiel Startkredit (Bank Austria / Erste Group)',
      principal: 25000.0,
      interestRate: 0.045, // 4,5% p.a.
      remainingDebt: 25000.0,
      takenAt: now,
      dueDate: now.add(const Duration(days: 60)),
      durationDays: 60,
    );
  }

  static Loan createSanierungsLoan() {
    final now = DateTime.now();
    // 10.000 € Notfall-Sanierungskredit nach Insolvenz zu 12% p.a.
    return Loan(
      id: 'sanierung_loan_${now.millisecondsSinceEpoch}',
      title: 'Bank Notfall-Sanierungskredit (Zweite Chance)',
      principal: 10000.0,
      interestRate: 0.12, // 12% p.a.
      remainingDebt: 10000.0 * (1 + 0.12 * (90 / 365)),
      takenAt: now,
      dueDate: now.add(const Duration(days: 90)),
      durationDays: 90,
    );
  }
}
