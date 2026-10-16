import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/app_update_service.dart';
import '../widgets/rank_badge.dart';
import 'dashboard_screen.dart';
import 'markets_screen.dart';
import 'bank_loan_screen.dart';
import 'prestige_shop_screen.dart';
import 'leaderboard_screen.dart';
import 'history_news_screen.dart';
import 'auth_screen.dart';
import 'quests_screen.dart';

import 'social_trading_screen.dart';
import 'dividends_screen.dart';
import 'achievements_screen.dart';
import 'simplistic_dashboard_screen.dart';
import 'settings_screen.dart';
import '../widgets/watchlist_marquee_ticker.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
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
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
      );
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openProfileDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(
              auth.currentUser?.displayName ?? 'Profil & Account',
              style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth.currentUser != null) ...[
              Text(
                'E-Mail: ${auth.currentUser!.email}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Login-Typ: ',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      auth.currentUser!.isGuest
                          ? 'Gast-Modus'
                          : auth.currentUser!.authProvider.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Du bist aktuell nicht angemeldet. Melde dich mit Passwort oder Google an, um dein Portfolio in Firebase zu sichern.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(color: AppColors.cardBorder),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.system_update_alt, color: AppColors.accent, size: 20),
              title: const Text('Nach Updates suchen', style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                _checkVersionUpdate(isManual: true);
              },
            ),
          ],
        ),
        actions: [
          if (auth.currentUser != null) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await auth.signOut();
              },
              child: const Text('Abmelden',
                  style: TextStyle(color: AppColors.loss, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(onAuthenticated: () => Navigator.pop(context)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Anmelden / Registrieren',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final auth = context.watch<AuthProvider>();
    final pendingCount = provider.pendingOrders.length;

    final screens = provider.isSimplisticMode
        ? [
            SimplisticDashboardScreen(onNavigateTab: _onTabTapped),
            const MarketsScreen(),
            const HistoryNewsScreen(),
            const SettingsScreen(),
          ]
        : [
            DashboardScreen(onNavigateTab: _onTabTapped),
            const MarketsScreen(),
            const BankLoanScreen(),
            const PrestigeShopScreen(),
            const LeaderboardScreen(),
            const HistoryNewsScreen(),
          ];

    final activeIndex = _currentIndex.clamp(0, screens.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 900;

        if (isWideScreen) {
          // --- DESKTOP / WEB NAVIGATION RAIL (WINDOWS, MAC, LINUX, BROWSER) ---
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 250,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      right: BorderSide(color: AppColors.cardBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.candlestick_chart,
                                    color: AppColors.primary, size: 26),
                                SizedBox(width: 8),
                                Text(
                                  'TRADING GAME',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Österreich Börsenspiel',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Profile & Login Tile
                            InkWell(
                              onTap: () => _openProfileDialog(context, auth),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        auth.currentUser?.displayName ??
                                            'Anmelden / Profil',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        size: 14, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Profile Mini Card
                            RankBadge(rank: provider.currentRank),
                            const SizedBox(height: 10),
                            Text(
                              'Cash: ${CurrencyFormatter.format(provider.cash)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.cardBorder, height: 1),

                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 10),
                          children: provider.isSimplisticMode
                              ? [
                                  _buildNavTile(0, Icons.pie_chart, 'Depot & Positionen'),
                                  _buildNavTile(1, Icons.trending_up, 'Märkte & Suche'),
                                  _buildNavTile(
                                    2,
                                    Icons.history_edu,
                                    'Orders & Historie',
                                    badgeText: pendingCount > 0 ? '$pendingCount' : null,
                                  ),
                                  _buildNavTile(3, Icons.settings, 'Einstellungen'),
                                  const Divider(color: AppColors.cardBorder, height: 20),
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.tune, color: AppColors.primary, size: 20),
                                    title: const Text(
                                      'Profi-Modus aktivieren',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () => provider.setSimplisticMode(false),
                                  ),
                                ]
                              : [
                                  _buildNavTile(0, Icons.pie_chart, 'Depot & Übersicht'),
                                  _buildNavTile(1, Icons.trending_up, 'Märkte & Trade'),
                                  _buildNavTile(
                                    2,
                                    Icons.account_balance,
                                    'Bank & Kredite',
                                    badgeText: provider.totalDebt > 0 ? '${provider.activeLoans.length}' : null,
                                  ),
                                  _buildNavTile(3, Icons.workspace_premium, 'Prestige-Shop'),
                                  _buildNavTile(4, Icons.leaderboard, 'Leaderboard'),
                                  _buildNavTile(
                                    5,
                                    Icons.history_edu,
                                    'News & Historie',
                                    badgeText: pendingCount > 0 ? '$pendingCount' : null,
                                  ),
                                  const Divider(color: AppColors.cardBorder, height: 20),
                                  _buildActionTile(
                                    Icons.settings,
                                    'Einstellungen',
                                    AppColors.primary,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                                  ),
                                  const Divider(color: AppColors.cardBorder, height: 20),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Text(
                                      'SPECIALS & GAMING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  _buildActionTile(
                                    Icons.military_tech,
                                    'Trophäen & Erfolge',
                                    AppColors.accentGold,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                                    badgeText: '${provider.achievementService.unlockedCount}/${provider.achievementService.totalCount}',
                                  ),
                                  _buildActionTile(
                                    Icons.emoji_events,
                                    'Wall Street Pass',
                                    Colors.amber,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestsScreen())),
                                    badgeText: provider.dailyQuests.where((q) => q.isCompleted && !q.isClaimed).isNotEmpty ? '🎁' : null,
                                  ),
                                  _buildActionTile(
                                    Icons.people_alt,
                                    'Social Trading',
                                    Colors.lightBlueAccent,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialTradingScreen())),
                                  ),
                                  _buildActionTile(
                                    Icons.payments,
                                    'Dividenden',
                                    Colors.greenAccent,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DividendsScreen())),
                                  ),
                                ],
                        ),
                      ),

                      // Footer with Update Checker
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _checkVersionUpdate(isManual: true),
                              child: const Row(
                                children: [
                                  Icon(Icons.system_update_alt,
                                      size: 14, color: AppColors.accent),
                                  SizedBox(width: 6),
                                  Text(
                                    'Nach Updates suchen',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Endlos-Modus • Start: 50.000 €',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content mit unterem Bloomberg-Laufband
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: screens[activeIndex]),
                      const WatchlistMarqueeTicker(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // --- MOBILE / NARROW LAYOUT (ANDROID, IOS, NARROW DESKTOP) ---
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 46,
            title: const Text(
              'TRADING GAME',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  provider.isSimplisticMode ? Icons.auto_awesome : Icons.tune,
                  size: 20,
                  color: provider.isSimplisticMode ? AppColors.accent : AppColors.textSecondary,
                ),
                tooltip: provider.isSimplisticMode ? 'Profi-Modus (Voll)' : 'Simplistic Modus (Clean)',
                onPressed: () {
                  provider.setSimplisticMode(!provider.isSimplisticMode);
                },
              ),
              if (!provider.isSimplisticMode)
                IconButton(
                  icon: const Icon(Icons.military_tech, size: 22, color: Colors.amber),
                  tooltip: 'Erfolge & Trophäen',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: 'Einstellungen',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.system_update_alt, size: 20),
                tooltip: 'Updates prüfen',
                onPressed: () => _checkVersionUpdate(isManual: true),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle, size: 22),
                tooltip: 'Profil & Login',
                onPressed: () => _openProfileDialog(context, auth),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: activeIndex,
                  children: screens,
                ),
              ),
              const WatchlistMarqueeTicker(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: activeIndex,
            onTap: _onTabTapped,
            items: provider.isSimplisticMode
                ? [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.pie_chart_outline),
                      activeIcon: Icon(Icons.pie_chart),
                      label: 'Depot',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.trending_up_outlined),
                      activeIcon: Icon(Icons.trending_up),
                      label: 'Märkte',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        children: [
                          const Icon(Icons.history_edu_outlined),
                          if (pendingCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: const Icon(Icons.history_edu),
                      label: 'Orders',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.settings_outlined),
                      activeIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ]
                : [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.pie_chart_outline),
                      activeIcon: Icon(Icons.pie_chart),
                      label: 'Depot',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.trending_up_outlined),
                      activeIcon: Icon(Icons.trending_up),
                      label: 'Märkte',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        children: [
                          const Icon(Icons.account_balance_outlined),
                          if (provider.totalDebt > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.loss,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${provider.activeLoans.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: const Icon(Icons.account_balance),
                      label: 'Bank',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.workspace_premium_outlined),
                      activeIcon: Icon(Icons.workspace_premium),
                      label: 'Prestige',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.leaderboard_outlined),
                      activeIcon: Icon(Icons.leaderboard),
                      label: 'Ranking',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        children: [
                          const Icon(Icons.history_edu_outlined),
                          if (pendingCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      activeIcon: const Icon(Icons.history_edu),
                      label: 'Historie',
                    ),
                  ],
          ),
        );
      },
    );
  }

  Widget _buildNavTile(int index, IconData icon, String title,
      {String? badgeText}) {
    final isSelected = _currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        trailing: badgeText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => _onTabTapped(index),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: badgeText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
