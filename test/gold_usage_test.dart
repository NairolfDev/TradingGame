import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gold means rank, prestige and rewards. Using it for ordinary controls
/// dilutes it (Apple branding: apply the accent color judiciously).
void main() {
  test('gold is only used for rank, prestige and rewards', () {
    const allowed = {
      'app_colors.dart',
      'app_theme.dart',
      'prestige_shop_screen.dart',
      'achievements_screen.dart',
      'quests_screen.dart',
      'leaderboard_screen.dart',
      'dashboard_screen.dart',
      'reward_overlay.dart',
      'game_fx.dart',
      'rank_badge.dart',
    };
    final gold = RegExp(r'AppColors\.(gold|accentGold|goldDark)\b');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final name = file.uri.pathSegments.last;
      if (allowed.contains(name)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (gold.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
