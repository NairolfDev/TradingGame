import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/price_alert.dart';
import '../../logic/auth_provider.dart';
import '../../logic/notification_planner.dart';
import '../../logic/notification_service.dart';
import '../../logic/price_alerts_controller.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final alerts = context.watch<PriceAlertsController>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_desktop)
            _Banner(
              icon: Icons.desktop_windows_outlined,
              text:
                  'Auf dem Desktop erscheinen Hinweise nur innerhalb der App. '
                  'Push-Nachrichten gibt es in der Handy- und Web-Version.',
            )
          else if (!service.permissionGranted)
            _Banner(
              icon: Icons.notifications_off_outlined,
              text: 'Benachrichtigungen sind noch nicht erlaubt.',
              action: FilledButton(
                onPressed: service.requestPermission,
                child: const Text('Erlauben'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Wann soll die App sich melden?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final c in const [
            NotificationCategory.orders,
            NotificationCategory.markets,
            NotificationCategory.loans,
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.label),
              subtitle: Text(switch (c) {
                NotificationCategory.orders =>
                  'Orders und Bot-Orders, die im Hintergrund ausgeführt wurden',
                NotificationCategory.markets =>
                  'Wenn eine Börse öffnet oder schließt, in der du Positionen oder offene Orders hast',
                NotificationCategory.loans =>
                  'Kredit fällig (einen Tag vorher und zur Fälligkeit) sowie neue Erfolge',
                _ => '',
              }),
              value: service.isEnabled(c),
              onChanged: (v) => service.setEnabled(c, v),
            ),
          const Divider(height: 32),
          Text('Kursalarme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Neue Alarme legst du bei einem Instrument mit der Glocke oben an.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (!auth.isAuthenticated)
            const Text('Melde dich an, um Kursalarme zu nutzen.')
          else if (alerts.error != null)
            Text(alerts.error!, style: TextStyle(color: AppColors.loss))
          else if (alerts.alerts.isEmpty)
            const Text('Noch keine Alarme.')
          else
            for (final a in alerts.alerts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  a.direction == AlertDirection.above
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: a.active ? AppColors.accent : AppColors.textMuted,
                ),
                title: Text(
                  '${a.symbol} ${a.direction == AlertDirection.above ? 'über' : 'unter'} '
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
                  onPressed: () => alerts.remove(a.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Banner({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.warning),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    ),
  );
}
