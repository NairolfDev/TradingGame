import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan_model.dart';
import '../../data/models/transaction.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/credit_rating_service.dart';
import 'auth_screen.dart';

class BankLoanScreen extends StatefulWidget {
  const BankLoanScreen({super.key});

  @override
  State<BankLoanScreen> createState() => _BankLoanScreenState();
}

class _BankLoanScreenState extends State<BankLoanScreen> {
  double _requestedAmount = 25000.0;
  int _selectedDurationDays = 60; // Standard: 2 Monate
  final List<int> _durations = [14, 30, 60, 90, 180];

  Color _getRatingColor(String grade) {
    if (grade.startsWith('AAA') || grade.startsWith('AA')) {
      return AppColors.profit; // Emerald Green
    } else if (grade.startsWith('BBB')) {
      return AppColors.accent; // Cyan / Blue
    } else if (grade.startsWith('BB')) {
      return AppColors.gold; // Amber
    } else if (grade.startsWith('CCC')) {
      return AppColors.warning;
    } else {
      return AppColors.loss; // Crimson / Red Kredithai
    }
  }

  void _showRepaymentDialog(
    BuildContext context,
    Loan loan,
    PortfolioProvider provider,
  ) {
    double payAmount = loan.remainingDebt.clamp(0.0, provider.cash);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final maxPossible = provider.cash < loan.remainingDebt
                ? provider.cash
                : loan.remainingDebt;
            final canPay = provider.cash > 0 && payAmount > 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kredit tilgen / ablösen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    loan.title,
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),

                  // Restschuld Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Offene Restschuld:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(loan.remainingDebt),
                              style: TextStyle(
                                color: AppColors.loss,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verfügbares Guthaben:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(provider.cash),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Tilgungsbetrag: ${CurrencyFormatter.format(payAmount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (maxPossible > 0) ...[
                    Slider(
                      value: payAmount.clamp(0.0, maxPossible),
                      min: 0.0,
                      max: maxPossible,
                      divisions: maxPossible > 1000 ? 50 : null,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.cardBorder,
                      onChanged: (val) {
                        setSheetState(() {
                          payAmount = val;
                        });
                      },
                    ),
                  ] else ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Kein Guthaben verfügbar. Verkaufe Wertpapiere oder erwirtschafte Rendite.',
                        style: TextStyle(color: AppColors.loss, fontSize: 12),
                      ),
                    ),
                  ],

                  // Schnellwahl-Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickPayButton('25%', () {
                        setSheetState(() {
                          payAmount = (loan.remainingDebt * 0.25).clamp(
                            0.0,
                            maxPossible,
                          );
                        });
                      }),
                      _buildQuickPayButton('50%', () {
                        setSheetState(() {
                          payAmount = (loan.remainingDebt * 0.50).clamp(
                            0.0,
                            maxPossible,
                          );
                        });
                      }),
                      _buildQuickPayButton('Max. möglich', () {
                        setSheetState(() {
                          payAmount = maxPossible;
                        });
                      }),
                      _buildQuickPayButton('Alles (Tilgen)', () {
                        setSheetState(() {
                          payAmount = loan.remainingDebt.clamp(
                            0.0,
                            maxPossible,
                          );
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canPay
                          ? () async {
                              final nav = Navigator.of(ctx);
                              final success = await provider.repayLoan(
                                loan,
                                payAmount,
                              );
                              nav.pop();
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surfaceElevated,
                                    content: Text(
                                      '✅ ${CurrencyFormatter.format(payAmount)} erfolgreich getilgt!',
                                      style: TextStyle(color: AppColors.profit),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.profit,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Jetzt ${CurrencyFormatter.format(payAmount)} zurückzahlen',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickPayButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  void _confirmTakeLoan(
    BuildContext context,
    PortfolioProvider provider,
    AuthProvider auth,
  ) {
    if (auth.currentUser == null || auth.currentUser!.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Anmeldung erforderlich'),
          content: const Text(
            'Kreditverträge und Auszahlungen erfordern ein verknüpftes Spielkonto. Bitte melde dich kurz an.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              child: const Text('Zum Login'),
            ),
          ],
        ),
      );
      return;
    }

    final rating = provider.creditRating;
    final interest = CreditRatingService.calculateLoanInterest(
      principal: _requestedAmount,
      durationDays: _selectedDurationDays,
      interestRate: rating.baseInterestRate,
    );
    final totalRepay = _requestedAmount + interest;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.account_balance, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text(
              'Kreditvertrag bestätigen',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auszahlung auf Depot: +${CurrencyFormatter.format(_requestedAmount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.profit,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Laufzeit:', '$_selectedDurationDays Tage'),
            _buildDetailRow('Bonitätseinstufung:', rating.grade),
            _buildDetailRow(
              'Zinssatz (p.a.):',
              '${(rating.baseInterestRate * 100).toStringAsFixed(1)}%',
            ),
            _buildDetailRow(
              'Errechnete Zinsen:',
              CurrencyFormatter.format(interest),
            ),
            Divider(color: AppColors.cardBorder, height: 20),
            _buildDetailRow(
              'Fällige Gesamtrückzahlung:',
              CurrencyFormatter.format(totalRepay),
              isBold: true,
              valueColor: AppColors.loss,
            ),
            const SizedBox(height: 12),
            Text(
              'Hinweis: Dieser Betrag erhöht deine Verbindlichkeiten und senkt dein Net Worth bis zur Tilgung.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.takeLoan(
                principal: _requestedAmount,
                durationDays: _selectedDurationDays,
              );
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceElevated,
                    content: Text(
                      '🎉 ${CurrencyFormatter.format(_requestedAmount)} wurden deinem Cash-Guthaben gutgeschrieben!',
                      style: TextStyle(color: AppColors.profit),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Kredit verbindlich annehmen'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final auth = context.watch<AuthProvider>();
    final rating = provider.creditRating;
    final ratingColor = _getRatingColor(rating.grade);
    final activeLoans = provider.activeLoans;
    final paidLoans = provider.loans.where((l) => l.isPaid).toList();

    final calcInterest = CreditRatingService.calculateLoanInterest(
      principal: _requestedAmount,
      durationDays: _selectedDurationDays,
      interestRate: rating.baseInterestRate,
    );
    final calcTotalRepay = _requestedAmount + calcInterest;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.account_balance, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'BANK & KREDIT-SCHALTER',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. BONITÄTS HERO CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ratingColor.withValues(alpha: 0.18),
                  AppColors.surfaceElevated,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ratingColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ratingColor.withValues(alpha: 0.1),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DEINE KREDITWÜRDIGKEIT (RATING)',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ratingColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ratingColor),
                      ),
                      child: Text(
                        'Score: ${rating.score}/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ratingColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      rating.grade,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ratingColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rating.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: AppColors.cardBorder, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktueller Kreditzins p.a.:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ratingColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Aktive Gesamtverbindlichkeiten:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(provider.totalDebt),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.loss,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // 2. LAUFENDE KREDITE SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Laufende Kredite (${activeLoans.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (activeLoans.isNotEmpty)
                Text(
                  'Schulden: ${CurrencyFormatter.format(provider.totalDebt)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.loss,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeLoans.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(
                child: Text(
                  'Du hast aktuell keine offenen Kredite oder Schulden. Hervorragend!',
                  style: TextStyle(color: AppColors.profit, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            ...activeLoans.map((loan) {
              final isStartLoan = loan.id.startsWith('initial_start_loan_');
              final daysLeft = loan.daysRemaining;
              final isOverdue = loan.isOverdue;
              final total =
                  loan.principal +
                  (loan.principal *
                      loan.interestRate *
                      (loan.durationDays / 365));
              final paidPercent = total > 0
                  ? (loan.paidAmount / total).clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOverdue
                        ? AppColors.loss
                        : (isStartLoan
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.cardBorder),
                    width: isStartLoan || isOverdue ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                isStartLoan ? '⭐' : '💳',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loan.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isOverdue ? AppColors.loss : AppColors.accent)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOverdue
                                  ? AppColors.loss
                                  : AppColors.accent,
                            ),
                          ),
                          child: Text(
                            isOverdue
                                ? '⚠️ ÜBERFÄLLIG'
                                : '$daysLeft Tage übrig',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOverdue
                                  ? AppColors.loss
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatBox(
                          'Kreditbetrag',
                          CurrencyFormatter.format(loan.principal),
                          AppColors.textSecondary,
                        ),
                        _buildStatBox(
                          'Zins p.a.',
                          '${(loan.interestRate * 100).toStringAsFixed(1)}%',
                          AppColors.accent,
                        ),
                        _buildStatBox(
                          'Offene Restschuld',
                          CurrencyFormatter.format(loan.remainingDebt),
                          AppColors.loss,
                          isHighlight: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: paidPercent,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.profit,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Getilgt: ${CurrencyFormatter.format(loan.paidAmount)} (${(paidPercent * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          'Frist: ${loan.dueDate.day}.${loan.dueDate.month}.${loan.dueDate.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showRepaymentDialog(context, loan, provider),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Kreditrate leisten / Tilgen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms);
            }),
          ],

          if (provider.isInsolvent || provider.isUnderCreditLockout) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privatinsolvenz & Neustart',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (provider.isUnderCreditLockout)
                      Text(
                        'Kreditsperre: noch ${provider.creditLockoutTimeRemaining.inDays} Tage, '
                        '${provider.creditLockoutTimeRemaining.inHours % 24} Stunden und '
                        '${provider.creditLockoutTimeRemaining.inMinutes % 60} Minuten. '
                        'Der Sanierungskredit ist nach Ablauf der Sperre verfügbar.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      )
                    else if (provider.canTakeRecoveryLoan) ...[
                      const Text(
                        'Die Kreditsperre ist abgelaufen. Du kannst einen Sanierungskredit beantragen.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Sanierungskredit: 10.000 €'),
                        onPressed: () async {
                          final success = await provider.takeSanierungsKredit();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sanierungskredit ausgezahlt.'),
                              ),
                            );
                          }
                        },
                      ),
                    ] else ...[
                      Text(
                        'Bei Zahlungsunfähigkeit kannst du Privatinsolvenz anmelden. Danach gilt eine Kreditsperre von fünf Tagen.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Privatinsolvenz anmelden'),
                        onPressed: () => provider.declareInsolvency(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. NEUEN KREDIT AUFNEHMEN (INTERACTIVE LOAN CALCULATOR)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_card, color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Neuen Kredit aufnehmen',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (provider.transactions
                        .where((t) => t.type == TransactionType.loanPayout)
                        .isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '1. Kredit: Max. 25.000 €',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Wähle deinen Wunschbetrag und die Rückzahlungsfrist. Das Geld wird sofort deinem Barkonto gutgeschrieben.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Amount Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kreditbetrag:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(_requestedAmount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final hasTakenLoan = provider.transactions.any(
                      (t) => t.type == TransactionType.loanPayout,
                    );
                    final double maxLimit = hasTakenLoan
                        ? rating.maxBorrowLimit
                        : (rating.maxBorrowLimit < 25000.0
                              ? rating.maxBorrowLimit
                              : 25000.0);
                    final double effectiveAmount = _requestedAmount.clamp(
                      5000.0,
                      maxLimit,
                    );
                    return Slider(
                      value: effectiveAmount,
                      min: 5000.0,
                      max: maxLimit > 5000.0 ? maxLimit : 5000.0,
                      divisions: maxLimit > 5000.0
                          ? ((maxLimit - 5000.0) / 5000.0).round().clamp(1, 50)
                          : 1,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.cardBorder,
                      onChanged: (val) {
                        setState(() {
                          _requestedAmount = val;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Duration Selector Chips
                Text(
                  'Laufzeit / Rückzahlungsfrist:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _durations.map((days) {
                    final isSelected = _selectedDurationDays == days;
                    return ChoiceChip(
                      label: Text(
                        days == 60
                            ? '$days Tage (2 Monate)'
                            : (days == 30 ? '30 Tage (1 Monat)' : '$days Tage'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDurationDays = days;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Calculation Breakdown Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      _buildCalcRow(
                        'Sofortige Auszahlung ins Depot:',
                        '+${CurrencyFormatter.format(_requestedAmount)}',
                        AppColors.profit,
                        isBold: true,
                      ),
                      _buildCalcRow(
                        'Dein Bonitäts-Zinssatz:',
                        '${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a.',
                        ratingColor,
                      ),
                      _buildCalcRow(
                        'Errechnete Zinskosten ($_selectedDurationDays Tage):',
                        '+${CurrencyFormatter.format(calcInterest)}',
                        AppColors.loss,
                      ),
                      Divider(color: AppColors.cardBorder, height: 16),
                      _buildCalcRow(
                        'Gesamtrückzahlung am Fälligkeitstag:',
                        CurrencyFormatter.format(calcTotalRepay),
                        AppColors.textPrimary,
                        isBold: true,
                        fontSize: 14,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.canTakeLoan
                        ? () => _confirmTakeLoan(context, provider, auth)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.canTakeLoan
                          ? AppColors.accent
                          : AppColors.surfaceElevated,
                      foregroundColor: provider.canTakeLoan
                          ? AppColors.onPrimary
                          : AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      provider.isUnderCreditLockout
                          ? '🔒 5-Tage Kreditsperre aktiv (${provider.creditLockoutTimeRemaining.inDays}T ${provider.creditLockoutTimeRemaining.inHours % 24}h)'
                          : (provider.isLoanOnCooldown
                                ? '⏳ Abkühlphase: 24h Sperre (noch ${provider.loanCooldownRemaining.inHours}h)'
                                : (!provider.canTakeLoan
                                      ? '⚠️ Bereits 1 Bankkredit aktiv'
                                      : 'Kredit über ${CurrencyFormatter.format(_requestedAmount)} jetzt beantragen')),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 20),

          // 4. GETILGTE KREDITE (ARCHIV)
          if (paidLoans.isNotEmpty) ...[
            Text(
              'Erfolgreich abbezahlte Kredite (${paidLoans.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...paidLoans.map((loan) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppColors.profit,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loan.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${CurrencyFormatter.format(loan.paidAmount)} voll getilgt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.profit,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(
    String title,
    String value,
    Color color, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCalcRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
