import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/luxury_item.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/auth_provider.dart';
import '../widgets/rank_badge.dart';
import 'auth_screen.dart';

class PrestigeShopScreen extends StatefulWidget {
  const PrestigeShopScreen({super.key});

  @override
  State<PrestigeShopScreen> createState() => _PrestigeShopScreenState();
}

class _PrestigeShopScreenState extends State<PrestigeShopScreen> {
  LuxuryCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final items = provider.luxuryItems;
    final rank = provider.currentRank;

    final filteredItems = items.where((item) {
      if (_selectedCategory == null) return true;
      return item.category == _selectedCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Prestige & Status-Shop')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Prestige Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF26190B), Color(0xFF141923)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'STATUS & COOLNESS',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.totalPrestigePoints} Prestige',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RankBadge(rank: rank),
                const SizedBox(height: 4),
                Text(
                  'Verwende deine Börsengewinne, um dir Luxusgüter zu gönnen und in der High Society aufzusteigen!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: AppColors.cardBorder),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gesamter Luxuswert:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(provider.totalLuxuryValue),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Verfügbares Cash:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(provider.cash),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildShopChip('Alle', null),
                _buildShopChip('⌚ Uhren', LuxuryCategory.watch),
                _buildShopChip('🏎️ Sportwagen', LuxuryCategory.vehicle),
                _buildShopChip('🏛️ Penthouses', LuxuryCategory.realEstate),
                _buildShopChip('🛥️ Yachten & Jets', LuxuryCategory.exclusive),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Items Grid / List
          ...filteredItems.map((item) => _buildLuxuryItemCard(item, provider)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildShopChip(String label, LuxuryCategory? category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.gold.withValues(alpha: 0.25),
        checkmarkColor: AppColors.gold,
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.cardBorder,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.gold : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLuxuryItemCard(LuxuryItem item, PortfolioProvider provider) {
    final canAfford = provider.cash >= item.price;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isOwned
              ? AppColors.gold.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: item.isOwned ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji Icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.isOwned
                    ? AppColors.gold.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(item.icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (item.isOwned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.ownedCount}x im Besitz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${item.prestigePoints} Prestige',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(item.price),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: canAfford
                        ? () {
                            final auth = context.read<AuthProvider>();
                            if (auth.currentUser == null ||
                                auth.currentUser!.isGuest) {
                              _showLoginRequiredDialog(context);
                            } else {
                              _confirmPurchase(item, provider);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? AppColors.gold
                          : AppColors.surfaceElevated,
                      foregroundColor: AppColors.onPrimary,
                      disabledForegroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      canAfford
                          ? 'KAUFEN (${CurrencyFormatter.format(item.price)})'
                          : 'Zu wenig Bargeld',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.gold, size: 26),
            SizedBox(width: 10),
            Text(
              'Anmelden erforderlich',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Du kannst den Prestige-Shop frei durchstöbern ("Nur Schauen").',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            SizedBox(height: 10),
            Text(
              'Um Luxusgüter wie Uhren, Sportwagen oder Penthouses zu erwerben und dein Ansehen im Leaderboard zu steigern, melde dich bitte kurz an!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Weiter nur zusehen',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Jetzt Anmelden / Registrieren'),
          ),
        ],
      ),
    );
  }

  void _confirmPurchase(LuxuryItem item, PortfolioProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(item.name, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Möchtest du dieses Statussymbol für ${CurrencyFormatter.format(item.price)} kaufen?\n\nDein Prestige steigt um +${item.prestigePoints} Punkte!',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              Navigator.pop(ctx);
              await provider.buyLuxuryItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Kauf bestätigen'),
          ),
        ],
      ),
    );
  }
}
