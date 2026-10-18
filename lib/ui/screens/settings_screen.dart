import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/appearance_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/savings_plan.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Einstellungen & Spielmodus',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. UI MODUS AUSWAHL
          _buildSectionHeader('BENUTZEROBERFLÄCHE & DARSTELLUNG'),
          const SizedBox(height: 10),
          _buildCard(child: const AppearancePicker()),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.primary,
                  title: Text(
                    'Simplistic Modus (Minimalistisch)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Reduziert die Benutzeroberfläche auf die reinen Kernfunktionen: Depot, Märkte, Kaufen/Verkaufen und offene Orders. Schaltet alle bunten Popups, Quests und Prestige-Statussymbole stumm.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: provider.isSimplisticMode,
                  onChanged: (val) => provider.setSimplisticMode(val),
                ),
                Divider(color: AppColors.cardBorder, height: 20),
                Row(
                  children: [
                    Icon(
                      provider.isSimplisticMode
                          ? Icons.check_circle
                          : Icons.dashboard_customize,
                      size: 16,
                      color: provider.isSimplisticMode
                          ? AppColors.primary
                          : AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.isSimplisticMode
                          ? 'Aktiver Modus: Simplistic / Minimalist UI'
                          : 'Aktiver Modus: Profi-Broker (Vollansicht)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.isSimplisticMode
                            ? AppColors.primary
                            : AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. REALISTISCHE ORDERAUSFÜHRUNG
          _buildSectionHeader('BÖRSEN-ORDERAUSFÜHRUNG & REALISMUS'),
          const SizedBox(height: 10),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.primary,
                  title: Text(
                    'Realistische Orderlaufzeit (5–15 Min.)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Orders werden bei geöffneter Börse mit einer realistischen Routing- und Matching-Verzögerung von 5 bis 15 Minuten im Orderbuch abgewickelt, statt sofort gebucht zu werden.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: provider.isRealisticOrderDelay,
                  onChanged: (val) => provider.setRealisticOrderDelay(val),
                ),
                Divider(color: AppColors.cardBorder, height: 20),
                Row(
                  children: [
                    Icon(
                      provider.isRealisticOrderDelay
                          ? Icons.hourglass_top
                          : Icons.bolt,
                      size: 16,
                      color: provider.isRealisticOrderDelay
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.isRealisticOrderDelay
                          ? 'Status: 5–15 Min. Ausführungszeit bei offener Börse'
                          : 'Status: Sofort-Ausführung (Simulator-Modus)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.isRealisticOrderDelay
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. SPARPLÄNE (DCA)
          _buildSectionHeader('🏦 AUTOMATISIERTE SPARPLÄNE (DCA)'),
          const SizedBox(height: 10),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Regelmäßige Sparpläne',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showCreateSavingsPlanDialog(context, provider),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Neuer Sparplan',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (provider.savingsPlans.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Noch keine Sparpläne eingerichtet. Richte z.B. einen täglichen 50 € Sparplan auf Bitcoin oder Erste Group ein!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  ...provider.savingsPlans.map(
                    (plan) => _buildSavingsPlanTile(context, provider, plan),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. KONTOAUSZUG & STEUERBERICHT
          _buildSectionHeader('📄 DEPOTAUSZUG & REPORTING'),
          const SizedBox(height: 10),
          _buildCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: AppColors.primary),
              ),
              title: Text(
                'Offiziellen Depotauszug anzeigen',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Erstellt eine strukturierte Abrechnung aller Depotwerte, Positionen, Transaktionen und Zinserträge.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => _showStatementDialog(context, provider),
            ),
          ),

          const SizedBox(height: 24),

          // 5. ACCOUNT & APP INFO
          _buildSectionHeader('👤 BENUTZERKONTO & VERSION'),
          const SizedBox(height: 10),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.person, color: AppColors.textPrimary),
                  ),
                  title: Text(
                    auth.currentUser?.displayName ?? 'Gast-Trader',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    auth.currentUser?.email ?? 'Nicht angemeldet',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      if (auth.isAuthenticated && !auth.currentUser!.isGuest) {
                        auth.signOut();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      }
                    },
                    child: Text(
                      auth.isAuthenticated && !auth.currentUser!.isGuest
                          ? 'Abmelden'
                          : 'Anmelden',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Divider(color: AppColors.cardBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cloud Backend & DB',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          size: 14,
                          color: AppColors.profit,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Firestore & Functions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.profit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Börsen-Feed',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.sensors, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Binance & Yahoo Live',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Version',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'v1.5.0 (Build 7)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.fetchLiveMarketQuotes();
                      await provider.reloadLeaderboard();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Echte Live-Kurse & Cloud-Daten erfolgreich synchronisiert!',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.sync, size: 16, color: AppColors.primary),
                    label: Text(
                      'Jetzt Live-Kurse & Cloud synchronisieren',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildSavingsPlanTile(
    BuildContext context,
    PortfolioProvider provider,
    SavingsPlan plan,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.assetSymbol} (${plan.assetName})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${CurrencyFormatter.format(plan.amountEur)} • ${plan.frequency.displayName} • Investiert: ${CurrencyFormatter.format(plan.totalInvested)}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          Row(
            children: [
              Switch(
                value: plan.isActive,
                activeTrackColor: AppColors.primary,
                onChanged: (_) =>
                    provider.savingsPlanService.togglePlan(plan.id),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.loss,
                ),
                onPressed: () =>
                    provider.savingsPlanService.deletePlan(plan.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateSavingsPlanDialog(
    BuildContext context,
    PortfolioProvider provider,
  ) {
    String selectedSymbol = provider.assets.first.symbol;
    double amount = 50.0;
    SavingsPlanFrequency frequency = SavingsPlanFrequency.daily;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final asset = provider.assets.firstWhere(
            (a) => a.symbol == selectedSymbol,
          );

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Neuen Sparplan anlegen',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wertpapier / Krypto:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: selectedSymbol,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  items: provider.assets.take(15).map((a) {
                    return DropdownMenuItem(
                      value: a.symbol,
                      child: Text(
                        '${a.symbol} (${a.name})',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedSymbol = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Sparbetrag (EUR):',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Slider(
                  value: amount,
                  min: 10,
                  max: 1000,
                  divisions: 99,
                  activeColor: AppColors.primary,
                  label: '${amount.toInt()} €',
                  onChanged: (val) => setDialogState(() => amount = val),
                ),
                Center(
                  child: Text(
                    '${amount.toInt()} € pro Ausführung',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ausführungsintervall:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                DropdownButton<SavingsPlanFrequency>(
                  value: frequency,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  items: SavingsPlanFrequency.values.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(
                        f.displayName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => frequency = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Abbrechen',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await provider.savingsPlanService.createPlan(
                    assetSymbol: asset.symbol,
                    assetName: asset.name,
                    amountEur: amount,
                    frequency: frequency,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Sparplan starten'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStatementDialog(BuildContext context, PortfolioProvider provider) {
    final statement = provider.generateDepotStatement();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.description, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Offizieller Depotauszug',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: SingleChildScrollView(
            child: SelectableText(
              statement,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: statement));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Depotauszug in die Zwischenablage kopiert!'),
                ),
              );
            },
            icon: Icon(Icons.copy, size: 16, color: AppColors.primary),
            label: Text('Kopieren', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
            ),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
