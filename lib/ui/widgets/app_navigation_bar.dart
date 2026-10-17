import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppNavigationBar extends StatelessWidget {
  static const destinations = <({String label, IconData icon})>[
    (label: 'Übersicht', icon: Icons.space_dashboard_outlined),
    (label: 'Märkte', icon: Icons.trending_up),
    (label: 'Portfolio', icon: Icons.account_balance_wallet_outlined),
    (label: 'Aktivität', icon: Icons.receipt_long_outlined),
    (label: 'Mehr', icon: Icons.grid_view_outlined),
  ];

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int pendingCount;
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(destinations.length, (index) {
          final destination = destinations[index];
          final selected = index == selectedIndex;
          final color = selected ? AppColors.primary : AppColors.textSecondary;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                key: ValueKey('destination-$index'),
                onTap: () => onSelected(index),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: index == 3 && pendingCount > 0,
                          label: Text('$pendingCount'),
                          child: Icon(destination.icon, color: color, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          destination.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}
