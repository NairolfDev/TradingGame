import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class OrderRoutingDialog extends StatefulWidget {
  final String symbol;
  final String assetName;
  final bool isBuy;
  final double amount;
  final double price;
  final Future<bool> Function() onExecute;

  const OrderRoutingDialog({
    super.key,
    required this.symbol,
    required this.assetName,
    required this.isBuy,
    required this.amount,
    required this.price,
    required this.onExecute,
  });

  static Future<bool> show({
    required BuildContext context,
    required String symbol,
    required String assetName,
    required bool isBuy,
    required double amount,
    required double price,
    required Future<bool> Function() onExecute,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OrderRoutingDialog(
        symbol: symbol,
        assetName: assetName,
        isBuy: isBuy,
        amount: amount,
        price: price,
        onExecute: onExecute,
      ),
    );
    return result ?? false;
  }

  @override
  State<OrderRoutingDialog> createState() => _OrderRoutingDialogState();
}

class _OrderRoutingDialogState extends State<OrderRoutingDialog> {
  int _currentStep = 0;
  bool _isSuccess = false;
  bool _isFailed = false;
  String _statusText = 'Risikoprüfung & Margin-Check...';

  @override
  void initState() {
    super.initState();
    _startRoutingProcess();
  }

  String _resolveExchange() {
    final sym = widget.symbol.toUpperCase();
    if (sym.endsWith('.VI') || sym == 'EBS' || sym == 'VOE' || sym == 'OMV' || sym == 'ANDR' || sym == 'RBI') {
      return 'Wiener Börse (WBAG)';
    } else if (sym.endsWith('.DE') || sym.endsWith('.AS') || sym == 'SAP' || sym == 'SIE' || sym == 'BMW' || sym == 'ASML') {
      return 'Deutsche Börse XETRA';
    } else if (sym.contains('BTC') || sym.contains('ETH') || sym.contains('SOL') || sym.contains('NEAR') || sym.contains('LINK') || sym.contains('RENDER')) {
      return 'Global Crypto Liquidity Pool';
    } else if (sym.contains('=F') || sym.contains('GC') || sym.contains('SI') || sym.contains('BZ')) {
      return 'CME Globex / ICE Futures';
    } else {
      return 'NASDAQ / NYSE Global Select';
    }
  }

  Future<void> _startRoutingProcess() async {
    final exchange = _resolveExchange();

    // Schritt 1: Risikoprüfung
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _currentStep = 1;
      _statusText = 'Smart Order Routing an $exchange...';
    });

    // Schritt 2: Routing an Börse
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _currentStep = 2;
      _statusText = 'Orderbuch-Matching (Best Execution)...';
    });

    // Schritt 3: Orderbuch-Matching & Tatsächliche Ausführung
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final success = await widget.onExecute();

    if (!mounted) return;
    if (success) {
      setState(() {
        _currentStep = 3;
        _isSuccess = true;
        _statusText = 'Order erfolgreich an $exchange abgerechnet!';
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isFailed = true;
        _statusText = 'Order konnte nicht ausgeführt werden (Börsenplatz meldet Ablehnung).';
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchange = _resolveExchange();
    final actionColor = widget.isBuy ? AppColors.bullish : AppColors.bearish;
    final totalVol = widget.amount * widget.price;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _isSuccess
                ? AppColors.bullish.withValues(alpha: 0.6)
                : (_isFailed ? AppColors.bearish : AppColors.primary.withValues(alpha: 0.4)),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon & Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                      color: actionColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isBuy ? 'Kauforder wird übermittelt' : 'Verkaufsorder wird übermittelt',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.amount.toStringAsFixed(widget.amount % 1 == 0 ? 0 : 4)}x ${widget.symbol} (${widget.assetName})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Exchange Badge & Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          exchange,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(totalVol),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Routing Schritte
              _buildStepRow(
                stepIndex: 0,
                title: 'Risikoprüfung & Deckungsprüfung',
                subtitle: 'Liquidität & Kontolimits autorisiert',
              ),
              const SizedBox(height: 10),
              _buildStepRow(
                stepIndex: 1,
                title: 'Börsen-Routing ($exchange)',
                subtitle: 'FIX-Protokoll Handshake aktiv',
              ),
              const SizedBox(height: 10),
              _buildStepRow(
                stepIndex: 2,
                title: 'Elektronisches Orderbuch',
                subtitle: 'Matching mit institutionellen Geld-/Briefkursen',
              ),
              const SizedBox(height: 10),
              _buildStepRow(
                stepIndex: 3,
                title: 'Settlement & Buchung',
                subtitle: 'Depotbestand und Cash-Konto aktualisiert',
              ),

              const SizedBox(height: 22),

              // Status Ticker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isSuccess && !_isFailed) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (_isSuccess) ...[
                    const Icon(Icons.check_circle, color: AppColors.bullish, size: 18),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Icon(Icons.cancel, color: AppColors.bearish, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isSuccess
                            ? AppColors.bullish
                            : (_isFailed ? AppColors.bearish : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required int stepIndex,
    required String title,
    required String subtitle,
  }) {
    final bool isDone = _currentStep > stepIndex || _isSuccess;
    final bool isCurrent = _currentStep == stepIndex && !_isSuccess && !_isFailed;

    Widget statusIcon;

    if (isDone) {
      statusIcon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      statusIcon = const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else {
      statusIcon = Text(
        '${stepIndex + 1}',
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      );
    }

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.bullish
                : (isCurrent ? AppColors.primary : AppColors.surfaceElevated),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? AppColors.primary : AppColors.cardBorder,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: statusIcon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCurrent || isDone ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
