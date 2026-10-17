import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../data/models/price_alert.dart';
import '../../logic/notification_service.dart';
import '../../logic/price_alerts_controller.dart';

/// Parses "1.234,56", "1234,56" and "1234.56".
double? parseEuroInput(String text) {
  var t = text.trim().replaceAll(' ', '').replaceAll('€', '');
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

Future<void> showPriceAlertSheet(
  BuildContext context, {
  required Asset asset,
  required String yahooSymbol,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PriceAlertSheet(asset: asset, yahooSymbol: yahooSymbol),
    ),
  );
}

class _PriceAlertSheet extends StatefulWidget {
  final Asset asset;
  final String yahooSymbol;
  const _PriceAlertSheet({required this.asset, required this.yahooSymbol});

  @override
  State<_PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends State<_PriceAlertSheet> {
  late final TextEditingController _price;
  AlertDirection _direction = AlertDirection.above;
  bool _recurring = false;
  bool _busy = false;
  String? _error;

  double get _current => widget.asset.currentPrice;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: _suggest(AlertDirection.above));
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  String _suggest(AlertDirection d) {
    final v = _current * (d == AlertDirection.above ? 1.05 : 0.95);
    return v.toStringAsFixed(v >= 100 ? 2 : 4).replaceAll('.', ',');
  }

  Future<void> _save() async {
    final price = parseEuroInput(_price.text);
    if (price == null || price <= 0) {
      setState(() => _error = 'Bitte einen gültigen Kurs in Euro eingeben.');
      return;
    }
    final probe = PriceAlert(
      id: '',
      uid: '',
      assetId: '',
      symbol: '',
      name: '',
      yahooSymbol: '',
      direction: _direction,
      price: price,
      recurring: false,
      active: true,
    );
    if (probe.firesAt(_current)) {
      setState(
        () => _error =
            'Der Kurs liegt schon ${_direction == AlertDirection.above ? 'über' : 'unter'} '
            'dieser Schwelle (aktuell ${CurrencyFormatter.format(_current)}).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final alerts = context.read<PriceAlertsController>();
    final notifications = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!notifications.permissionGranted) {
      await notifications.requestPermission();
    }
    final error = await alerts.add(
      assetId: widget.asset.id,
      symbol: widget.asset.symbol,
      name: widget.asset.name,
      yahooSymbol: widget.yahooSymbol,
      direction: _direction,
      price: price,
      recurring: _recurring,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Alarm gesetzt: ${widget.asset.symbol} '
          '${_direction == AlertDirection.above ? 'über' : 'unter'} '
          '${CurrencyFormatter.format(price)}'
          '${notifications.permissionGranted ? '' : ' (Benachrichtigungen sind noch nicht erlaubt, siehe Mehr → Benachrichtigungen)'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PriceAlertsController>();
    final existing = controller.forAsset(widget.asset.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kursalarm für ${widget.asset.symbol}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktuell ${CurrencyFormatter.format(_current)}. Du bekommst eine '
            'Push-Nachricht, auch wenn die App geschlossen ist.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SegmentedButton<AlertDirection>(
            segments: const [
              ButtonSegment(
                value: AlertDirection.above,
                icon: Icon(Icons.trending_up),
                label: Text('Kurs über'),
              ),
              ButtonSegment(
                value: AlertDirection.below,
                icon: Icon(Icons.trending_down),
                label: Text('Kurs unter'),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() {
              _direction = s.first;
              _price.text = _suggest(_direction);
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Schwelle in Euro',
              prefixIcon: Icon(Icons.euro),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _busy ? null : _save(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wiederkehrend'),
            subtitle: const Text(
              'Meldet sich erneut, sobald der Kurs die Schwelle wieder '
              'verlassen und erneut erreicht hat.',
            ),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: AppColors.loss)),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(_busy ? 'Bitte warten …' : 'Alarm setzen'),
          ),
          if (existing.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Deine Alarme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final a in existing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  a.direction == AlertDirection.above
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: a.active ? AppColors.accent : AppColors.textMuted,
                ),
                title: Text(
                  '${a.direction == AlertDirection.above ? 'Über' : 'Unter'} '
                  '${CurrencyFormatter.format(a.price)}',
                ),
                subtitle: Text(
                  [
                    a.active ? 'aktiv' : 'ausgelöst',
                    if (a.recurring) 'wiederkehrend',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Alarm löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => controller.remove(a.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
