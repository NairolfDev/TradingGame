import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

/// Shared quantity/budget input. Fractions remain intent until execution.
class OrderEntry extends StatefulWidget {
  final double amount;
  final double? fraction;
  final double Function(double euros) amountForEuros;
  final double Function(double amount) eurosForAmount;
  final double Function(double fraction) amountForFraction;
  final void Function(double amount, double? fraction, double? euros) onChanged;
  final bool enabled;
  final String euroLabel;
  final String fractionLabel;

  const OrderEntry({
    super.key,
    required this.amount,
    required this.fraction,
    required this.amountForEuros,
    required this.eurosForAmount,
    required this.amountForFraction,
    required this.onChanged,
    this.enabled = true,
    this.euroLabel = 'Budget inkl. Gebühren',
    this.fractionLabel = 'Anteil des verfügbaren Cash',
  });

  @override
  State<OrderEntry> createState() => _OrderEntryState();
}

class _OrderEntryState extends State<OrderEntry> {
  late final TextEditingController _controller;
  bool _euros = false;

  String _text(double value) => value.isFinite
      ? value
            .toStringAsFixed(_euros ? 2 : 8)
            .replaceFirst(RegExp(r'\.?0+$'), '')
      : '';

  void _sync() {
    final value = _euros ? widget.eurosForAmount(widget.amount) : widget.amount;
    _controller.text = value == 0 ? '' : _text(value);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _sync();
  }

  @override
  void didUpdateWidget(OrderEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction != null &&
        (oldWidget.amount != widget.amount ||
            oldWidget.fraction != widget.fraction)) {
      _sync();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final euros in [false, true])
            ChoiceChip(
              label: Text(euros ? 'EUR' : 'Stück'),
              selected: _euros == euros,
              onSelected: !widget.enabled
                  ? null
                  : (_) => setState(() {
                      _euros = euros;
                      _sync();
                    }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _euros ? widget.euroLabel : 'Menge in Stück',
          suffixText: _euros ? 'EUR' : 'Stück',
          helperText: _euros
              ? '≈ ${CurrencyFormatter.formatAmount(widget.amount)} Stück'
              : '≈ ${CurrencyFormatter.format(widget.eurosForAmount(widget.amount))}',
        ),
        onChanged: (text) {
          final value = double.tryParse(text.replaceAll(',', '.'));
          final valid = value != null && value.isFinite && value > 0;
          widget.onChanged(
            valid ? (_euros ? widget.amountForEuros(value) : value) : 0,
            null,
            _euros && valid ? value : null,
          );
        },
      ),
      const SizedBox(height: 12),
      Text(widget.fractionLabel, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final fraction in [.25, .5, .75, 1.0])
            OutlinedButton(
              onPressed: !widget.enabled
                  ? null
                  : () {
                      final amount = widget.amountForFraction(fraction);
                      _controller.text = _text(
                        _euros ? widget.eurosForAmount(amount) : amount,
                      );
                      widget.onChanged(amount, fraction, null);
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 48),
                backgroundColor: widget.fraction == fraction
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .15)
                    : null,
              ),
              child: Text('${(fraction * 100).round()}%'),
            ),
        ],
      ),
    ],
  );
}
