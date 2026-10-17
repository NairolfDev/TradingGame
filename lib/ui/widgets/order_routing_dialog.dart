import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction.dart';
import '../../logic/portfolio_provider.dart';

/// The receipt uses saved execution data, never the input preview.
class OrderRoutingDialog extends StatefulWidget {
  final String symbol;
  final String assetName;
  final bool isBuy;
  final double amount;
  final double price;
  final PortfolioProvider provider;
  final Future<bool> Function() onExecute;
  const OrderRoutingDialog({
    super.key,
    required this.symbol,
    required this.assetName,
    required this.isBuy,
    required this.amount,
    required this.price,
    required this.provider,
    required this.onExecute,
  });

  static Future<bool> show({
    required BuildContext context,
    required String symbol,
    required String assetName,
    required bool isBuy,
    required double amount,
    required double price,
    required PortfolioProvider provider,
    required Future<bool> Function() onExecute,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrderRoutingDialog(
          symbol: symbol,
          assetName: assetName,
          isBuy: isBuy,
          amount: amount,
          price: price,
          provider: provider,
          onExecute: onExecute,
        ),
      ) ??
      false;

  @override
  State<OrderRoutingDialog> createState() => _OrderRoutingDialogState();
}

class _OrderRoutingDialogState extends State<OrderRoutingDialog> {
  bool _done = false;
  bool _success = false;
  String _title = 'Order wird verarbeitet';
  String _details = 'Menge und Kurs werden bei Ausführung geprüft.';

  @override
  void initState() {
    super.initState();
    _execute();
  }

  Future<void> _execute() async {
    final provider = widget.provider;
    final transactionIds = provider.transactions.map((t) => t.id).toSet();
    final pendingIds = provider.allPendingOrders.map((o) => o.id).toSet();
    var success = false;
    String? error;
    try {
      success = await widget.onExecute();
    } catch (_) {
      error =
          'Orderstatus konnte nicht bestätigt werden. Prüfe die Aktivität, bevor du erneut bestellst.';
    }
    if (!mounted) return;
    final transaction = provider.transactions
        .where(
          (t) =>
              !transactionIds.contains(t.id) &&
              t.symbol == widget.symbol &&
              t.type ==
                  (widget.isBuy ? TransactionType.buy : TransactionType.sell),
        )
        .firstOrNull;
    final pending = provider.allPendingOrders
        .where(
          (o) =>
              !pendingIds.contains(o.id) &&
              o.symbol == widget.symbol &&
              o.isBuy == widget.isBuy,
        )
        .firstOrNull;
    setState(() {
      _done = true;
      _success = success;
      if (success && transaction != null) {
        _title = widget.isBuy ? 'Kauf ausgeführt' : 'Verkauf ausgeführt';
        _details =
            '${CurrencyFormatter.formatAmount(transaction.amount)} Stück ${transaction.symbol}\n'
            'Ausführungskurs: ${CurrencyFormatter.format(transaction.price)}\n'
            '${widget.isBuy ? "Abgebucht inkl. Gebühren" : "Gutgeschrieben"}: ${CurrencyFormatter.format(transaction.totalAmount)}';
      } else if (success && pending != null) {
        _title = 'Order gespeichert – Ausführung ausstehend';
        _details =
            '${CurrencyFormatter.formatAmount(pending.amount)} Stück ${pending.symbol} beauftragt\n'
            'Geschätzter Betrag: ${CurrencyFormatter.format(pending.totalEstimatedCost)}\n'
            'Endgültige Menge und Kurs findest du nach Ausführung in der Aktivität.';
      } else {
        _title = success ? 'Order übermittelt' : 'Order nicht bestätigt';
        _details =
            error ??
            (success
                ? 'Prüfe den aktuellen Status in der Aktivität.'
                : provider.lastAlertMessage ??
                      'Bitte prüfe Menge, Cash und Handelszeiten.');
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _done,
    child: AlertDialog(
      scrollable: true,
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.assetName),
          const SizedBox(height: 16),
          if (!_done)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(),
            ),
          Semantics(liveRegion: true, child: Text(_details)),
        ],
      ),
      actions: _done
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, _success),
                child: const Text('Fertig'),
              ),
            ]
          : null,
    ),
  );
}
