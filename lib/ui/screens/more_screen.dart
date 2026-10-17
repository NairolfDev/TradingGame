import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/appearance_picker.dart';
import 'achievements_screen.dart';
import 'bank_loan_screen.dart';
import 'dividends_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import 'prestige_shop_screen.dart';
import 'quests_screen.dart';
import 'settings_screen.dart';
import 'social_trading_screen.dart';

class MoreScreen extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onCheckUpdates;
  const MoreScreen({
    super.key,
    required this.onProfile,
    required this.onCheckUpdates,
  });

  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final auth = context.watch<AuthProvider>();
    final links =
        <({String title, String subtitle, IconData icon, Widget screen})>[
          (
            title: 'Bank & Kredite',
            subtitle: 'Restschuld, Rückzahlung und Finanzierung',
            icon: Icons.account_balance_outlined,
            screen: const BankLoanScreen(),
          ),
          (
            title: 'Prestige',
            subtitle: 'Ränge und Statusobjekte',
            icon: Icons.workspace_premium_outlined,
            screen: const PrestigeShopScreen(),
          ),
          (
            title: 'Rangliste',
            subtitle: 'Gesamtrendite im Vergleich',
            icon: Icons.leaderboard_outlined,
            screen: const LeaderboardScreen(),
          ),
          (
            title: 'Aufgaben & Belohnungen',
            subtitle: 'Tägliche Aufgaben und Fortschritt',
            icon: Icons.task_alt,
            screen: const QuestsScreen(),
          ),
          (
            title: 'Erfolge',
            subtitle: 'Deine erreichten Meilensteine',
            icon: Icons.emoji_events_outlined,
            screen: const AchievementsScreen(),
          ),
          (
            title: 'Dividenden',
            subtitle: 'Ausschüttungen und passives Einkommen',
            icon: Icons.payments_outlined,
            screen: const DividendsScreen(),
          ),
          (
            title: 'Social Trading',
            subtitle: 'Öffentliche Portfolios entdecken',
            icon: Icons.people_outline,
            screen: const SocialTradingScreen(),
          ),
          (
            title: 'Benachrichtigungen',
            subtitle: 'Kursalarme, Orders, Börsenzeiten',
            icon: Icons.notifications_outlined,
            screen: const NotificationsScreen(),
          ),
          (
            title: 'Einstellungen',
            subtitle: 'Anzeige und Spieloptionen',
            icon: Icons.settings_outlined,
            screen: const SettingsScreen(),
          ),
        ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(
              auth.isAuthenticated
                  ? auth.currentUser!.displayName
                  : 'Anmelden / Profil',
            ),
            subtitle: Text(
              auth.isAuthenticated
                  ? 'Konto und Anmeldung'
                  : 'Portfolio mit deinem Konto speichern',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onProfile,
          ),
          const Divider(),
          for (final link in links)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              leading: Icon(link.icon),
              title: Text(link.title),
              subtitle: Text(link.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, link.screen),
            ),
          const Divider(),
          const AppearancePicker(),
          const Divider(),
          SwitchListTile.adaptive(
            title: const Text('Einfacher Überblick'),
            subtitle: const Text(
              'Reduzierte Übersicht mit denselben fünf Navigationsbereichen',
            ),
            value: portfolio.isSimplisticMode,
            onChanged: portfolio.setSimplisticMode,
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Nach Updates suchen'),
            onTap: onCheckUpdates,
          ),
        ],
      ),
    );
  }
}
