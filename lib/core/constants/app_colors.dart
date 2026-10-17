import 'package:flutter/material.dart';

/// One complete set of colour roles. Four palettes exist:
/// Gamer/Schlicht × Dunkel/Hell, chosen by the player in the settings.
class AppPalette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color cardBorder;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color gold;
  final Color goldDark;
  final Color purple;
  final Color profit;
  final Color loss;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Background gradient for hero cards; flat in the broker style.
  final List<Color> heroGradient;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.cardBorder,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.gold,
    required this.goldDark,
    required this.purple,
    required this.profit,
    required this.loss,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.heroGradient,
  });

  // Text/background pairs below keep ≥4.5:1 contrast for body text.
  static const gameDark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B0820),
    surface: Color(0xFF16112F),
    surfaceElevated: Color(0xFF221A45),
    cardBorder: Color(0xFF34295F),
    primary: Color(0xFF2CF58C),
    onPrimary: Color(0xFF07130D),
    accent: Color(0xFF36D6FF),
    gold: Color(0xFFFFC94A),
    goldDark: Color(0xFFC98A00),
    purple: Color(0xFFB57BFF),
    profit: Color(0xFF2CF58C),
    loss: Color(0xFFFF6B8B),
    warning: Color(0xFFFFA53D),
    textPrimary: Color(0xFFF5F2FF),
    textSecondary: Color(0xFFB9B0DA),
    textMuted: Color(0xFFA197C9),
    heroGradient: [Color(0xFF3A1D8F), Color(0xFF0E5D73)],
  );

  static const gameLight = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F1FF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDE8FF),
    cardBorder: Color(0xFFD8CFFA),
    primary: Color(0xFF0A9A57),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF0A7DB8),
    gold: Color(0xFFA86A00),
    goldDark: Color(0xFF7A4D00),
    purple: Color(0xFF7339D9),
    profit: Color(0xFF0A8A4E),
    loss: Color(0xFFD2234A),
    warning: Color(0xFFB85C00),
    textPrimary: Color(0xFF1A1438),
    textSecondary: Color(0xFF4F4775),
    textMuted: Color(0xFF5E567F),
    heroGradient: [Color(0xFF7B4DFF), Color(0xFF1FB6D9)],
  );

  static const simpleDark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0E1116),
    surface: Color(0xFF161A21),
    surfaceElevated: Color(0xFF1E232C),
    cardBorder: Color(0xFF2A303B),
    primary: Color(0xFF3DD68C),
    onPrimary: Color(0xFF0B1410),
    accent: Color(0xFF6CB4FF),
    gold: Color(0xFFE2B85C),
    goldDark: Color(0xFFA9832F),
    purple: Color(0xFFA78BFA),
    profit: Color(0xFF3DD68C),
    loss: Color(0xFFFF7A70),
    warning: Color(0xFFF2A33A),
    textPrimary: Color(0xFFE9EDF2),
    textSecondary: Color(0xFFA4ADBA),
    textMuted: Color(0xFF98A2B0),
    heroGradient: [Color(0xFF161A21), Color(0xFF161A21)],
  );

  static const simpleLight = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F2F5),
    cardBorder: Color(0xFFDDE1E7),
    primary: Color(0xFF0B8A4C),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF1A66C2),
    gold: Color(0xFF946200),
    goldDark: Color(0xFF6B4700),
    purple: Color(0xFF6D4AC9),
    profit: Color(0xFF0B7D45),
    loss: Color(0xFFC7362B),
    warning: Color(0xFFA85A00),
    textPrimary: Color(0xFF14181F),
    textSecondary: Color(0xFF4A5361),
    textMuted: Color(0xFF5A6372),
    heroGradient: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
}

/// Colour roles of the active palette. Getters (not consts) so the whole app
/// follows a theme switch; [ThemeController] rebuilds every element on change.
class AppColors {
  static AppPalette palette = AppPalette.gameDark;

  /// Gamer style: gradients, glow and celebration effects are allowed.
  static bool get isGamer =>
      identical(palette, AppPalette.gameDark) ||
      identical(palette, AppPalette.gameLight);

  // Backgrounds
  static Color get background => palette.background;
  static Color get surface => palette.surface;
  static Color get surfaceElevated => palette.surfaceElevated;
  static Color get cardBorder => palette.cardBorder;
  static Color get surfaceLight => palette.surfaceElevated;

  // Brand & Accents
  static Color get primary => palette.primary;
  static Color get onPrimary => palette.onPrimary;
  static Color get primaryGlow => palette.primary.withValues(alpha: 0.2);
  static Color get accent => palette.accent;
  static Color get gold => palette.gold;
  static Color get goldDark => palette.goldDark;
  static Color get purple => palette.purple;

  // Trading status
  static Color get profit => palette.profit;
  static Color get loss => palette.loss;
  static Color get bullish => palette.profit;
  static Color get bearish => palette.loss;
  static Color get warning => palette.warning;
  static Color get accentGold => palette.gold;
  static Color get profitGreen => palette.profit;
  static Color get lossRed => palette.loss;

  // Text
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;

  // Asset Categories
  static const Color crypto = Color(0xFFF7931A); // Bitcoin Orange
  static const Color stock = Color(0xFF2979FF); // Blue
  static const Color etf = Color(0xFF00C853); // Forest Green
  static const Color cfd = Color(0xFFFF3D00); // Fire / Leverage Red-Orange
  static const Color bond = Color(0xFFAB47BC); // Purple
}
