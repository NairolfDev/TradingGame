import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/core/constants/app_colors.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final palettes = {
    'gameDark': AppPalette.gameDark,
    'gameLight': AppPalette.gameLight,
    'simpleDark': AppPalette.simpleDark,
    'simpleLight': AppPalette.simpleLight,
  };

  // cardBorder is decorative and intentionally excluded.
  test('every palette keeps text and symbols at 4.5:1', () {
    final failures = <String>[];
    void check(String palette, String fg, Color a, String bg, Color b) {
      final c = contrast(a, b);
      if (c < 4.5) {
        failures.add('$palette: $fg on $bg = ${c.toStringAsFixed(2)}');
      }
    }

    palettes.forEach((name, p) {
      final grounds = {
        'background': p.background,
        'surface': p.surface,
        'surfaceElevated': p.surfaceElevated,
      };
      final texts = {
        'textPrimary': p.textPrimary,
        'textSecondary': p.textSecondary,
        'textMuted': p.textMuted,
      };
      final signals = {
        'primary': p.primary,
        'profit': p.profit,
        'loss': p.loss,
        'gold': p.gold,
        'accent': p.accent,
        'warning': p.warning,
      };
      texts.forEach(
        (fg, a) => grounds.forEach((bg, b) => check(name, fg, a, bg, b)),
      );
      signals.forEach(
        (fg, a) => grounds.forEach((bg, b) => check(name, fg, a, bg, b)),
      );
      check(name, 'onPrimary', p.onPrimary, 'primary', p.primary);
    });
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
