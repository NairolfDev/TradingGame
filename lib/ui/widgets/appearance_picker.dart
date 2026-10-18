import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../logic/theme_controller.dart';

/// Stil (Gamer/Schlicht) und Helligkeit (Dunkel/Hell) wählen.
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Darstellung',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            theme.isGamer
                ? 'Gamer: bunte Farben, Animationen und Belohnungseffekte'
                : 'Schlicht: ruhiger Broker-Look ohne Effekte',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppStyle>(
              segments: const [
                ButtonSegment(
                  value: AppStyle.gamer,
                  icon: Icon(Icons.sports_esports_outlined),
                  label: Text('Gamer'),
                ),
                ButtonSegment(
                  value: AppStyle.schlicht,
                  icon: Icon(Icons.business_center_outlined),
                  label: Text('Schlicht'),
                ),
              ],
              selected: {theme.style},
              onSelectionChanged: (s) => theme.setStyle(s.first),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppAppearance>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AppAppearance.system, label: Text('Auto')),
                ButtonSegment(value: AppAppearance.dark, label: Text('Dunkel')),
                ButtonSegment(value: AppAppearance.light, label: Text('Hell')),
              ],
              selected: {theme.appearance},
              onSelectionChanged: (s) => theme.setAppearance(s.first),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Auto folgt der Helligkeit deines Geräts.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
