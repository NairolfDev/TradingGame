import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/app_update_service.dart';
import '../widgets/rank_badge.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/watchlist_marquee_ticker.dart';
import 'dashboard_screen.dart';
import 'simplistic_dashboard_screen.dart';
import 'markets_screen.dart';
import 'portfolio_screen.dart';
import 'history_news_screen.dart';
import 'more_screen.dart';
import 'bank_loan_screen.dart';
import 'auth_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};
  bool _hasCheckedForUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersionUpdate();
    });
  }

  Future<void> _checkVersionUpdate({bool isManual = false}) async {
    if (_hasCheckedForUpdate && !isManual) return;
    _hasCheckedForUpdate = true;

    final updateInfo = await AppUpdateService.checkForUpdate();
    if (!mounted) return;

    if (updateInfo.hasUpdate) {
      AppUpdateService.showUpdateDialog(context, updateInfo);
    } else if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'Du nutzt bereits die aktuellste Version (v${updateInfo.currentVersion})!',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      );
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  void _openProfileDialog(BuildContext context, AuthProvider auth) {
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
            Icon(Icons.account_circle, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                auth.currentUser?.displayName ?? 'Profil & Account',
                style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth.isAuthenticated) ...[
              Text(
                'E-Mail: ${auth.currentUser!.email}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Login-Typ: ',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      auth.currentUser!.isGuest
                          ? 'Gast-Modus'
                          : auth.currentUser!.authProvider.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Du bist aktuell nicht angemeldet. Melde dich mit Passwort oder Google an, um dein Portfolio in Firebase zu sichern.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: AppColors.cardBorder),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.system_update_alt,
                color: AppColors.accent,
                size: 20,
              ),
              title: const Text(
                'Nach Updates suchen',
                style: TextStyle(fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _checkVersionUpdate(isManual: true);
              },
            ),
          ],
        ),
        actions: [
          if (auth.isAuthenticated) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await auth.signOut();
              },
              child: Text(
                'Abmelden',
                style: TextStyle(
                  color: AppColors.loss,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                'Anmelden / Registrieren',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _onDashboardNavigate(int index) {
    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const BankLoanScreen()));
    } else {
      _onTabTapped(index == 1 ? 1 : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final auth = context.watch<AuthProvider>();
    final destinations = AppNavigationBar.destinations;
    final pages = <Widget>[
      portfolio.isSimplisticMode
          ? SimplisticDashboardScreen(onNavigateTab: _onDashboardNavigate)
          : DashboardScreen(onNavigateTab: _onDashboardNavigate),
      const MarketsScreen(),
      PortfolioScreen(onOpenMarkets: () => _onTabTapped(1)),
      HistoryNewsScreen(onOpenMarkets: () => _onTabTapped(1)),
      MoreScreen(
        onProfile: () => _openProfileDialog(context, auth),
        onCheckUpdates: () => _checkVersionUpdate(isManual: true),
      ),
    ];
    final content = IndexedStack(
      index: _currentIndex,
      children: List.generate(
        pages.length,
        (index) => _visited.contains(index)
            ? TickerMode(enabled: index == _currentIndex, child: pages[index])
            : const SizedBox.shrink(),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        if (!desktop) {
          return Scaffold(
            body: SafeArea(bottom: false, child: content),
            bottomNavigationBar: AppNavigationBar(
              selectedIndex: _currentIndex,
              onSelected: _onTabTapped,
              pendingCount: portfolio.pendingOrders.length,
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 248,
                child: Material(
                  color: AppColors.surface,
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'TRADING GAME',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              key: ValueKey('desktop-destination-$index'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: _currentIndex == index,
                              selectedColor: AppColors.primary,
                              selectedTileColor: AppColors.primaryGlow,
                              leading: Icon(destinations[index].icon),
                              title: Text(destinations[index].label),
                              trailing:
                                  index == 3 &&
                                      portfolio.pendingOrders.isNotEmpty
                                  ? Badge(
                                      label: Text(
                                        '${portfolio.pendingOrders.length}',
                                      ),
                                    )
                                  : null,
                              onTap: () => _onTabTapped(index),
                            ),
                          ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.account_circle_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            auth.isAuthenticated
                                ? auth.currentUser!.displayName
                                : 'Anmelden / Profil',
                          ),
                          onTap: () => _openProfileDialog(context, auth),
                        ),
                        const SizedBox(height: 8),
                        RankBadge(rank: portfolio.currentRank),
                        const SizedBox(height: 12),
                        Text(
                          'Verfügbar: ${CurrencyFormatter.format(portfolio.cash)}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Start: 50.000 € Cash, davon 25.000 € Kredit',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.cardBorder,
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: content),
                    const WatchlistMarqueeTicker(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
