import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';

/// Gamer = bunte Farben, Animationen, Belohnungseffekte.
/// Schlicht = ruhiger Broker-Look ohne Effekte.
enum AppStyle { gamer, schlicht }

/// Automatisch folgt der Helligkeit des Geräts (Apple: keine eigene
/// Hell/Dunkel-Einstellung erzwingen, aber die Wahl bleibt möglich).
enum AppAppearance { system, dark, light }

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const _keyStyle = 'tg_theme_style';
  static const _keyAppearance = 'tg_theme_appearance';
  static const _keyLegacyDark = 'tg_theme_dark'; // bool, before "Automatisch"

  final Brightness Function() _platformBrightness;
  AppStyle _style = AppStyle.gamer;
  AppAppearance _appearance = AppAppearance.system;

  ThemeController({Brightness Function()? platformBrightness})
    : _platformBrightness =
          platformBrightness ??
          (() => PlatformDispatcher.instance.platformBrightness) {
    WidgetsBinding.instance.addObserver(this);
    _apply();
    _load();
  }

  AppStyle get style => _style;
  AppAppearance get appearance => _appearance;
  bool get isGamer => _style == AppStyle.gamer;
  bool get isDark => switch (_appearance) {
    AppAppearance.dark => true,
    AppAppearance.light => false,
    AppAppearance.system => _platformBrightness() == Brightness.dark,
  };

  @override
  void didChangePlatformBrightness() {
    if (_appearance != AppAppearance.system) return;
    _apply();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final style = prefs.getString(_keyStyle);
      _style = AppStyle.values.firstWhere(
        (s) => s.name == style,
        orElse: () => AppStyle.gamer,
      );
      final saved = prefs.getString(_keyAppearance);
      _appearance = AppAppearance.values.firstWhere(
        (a) => a.name == saved,
        orElse: () => switch (prefs.getBool(_keyLegacyDark)) {
          true => AppAppearance.dark,
          false => AppAppearance.light,
          null => AppAppearance.system,
        },
      );
      _apply();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setStyle(AppStyle style) => _set(style, _appearance);
  Future<void> setAppearance(AppAppearance appearance) =>
      _set(_style, appearance);

  /// Kept for callers that only know light/dark.
  Future<void> setDark(bool dark) =>
      setAppearance(dark ? AppAppearance.dark : AppAppearance.light);

  Future<void> _set(AppStyle style, AppAppearance appearance) async {
    if (style == _style && appearance == _appearance) return;
    _style = style;
    _appearance = appearance;
    _apply();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStyle, style.name);
      await prefs.setString(_keyAppearance, appearance.name);
    } catch (_) {}
  }

  void _apply() {
    AppColors.palette = switch ((_style, isDark)) {
      (AppStyle.gamer, true) => AppPalette.gameDark,
      (AppStyle.gamer, false) => AppPalette.gameLight,
      (AppStyle.schlicht, true) => AppPalette.simpleDark,
      (AppStyle.schlicht, false) => AppPalette.simpleLight,
    };
  }
}

/// Rebuilds the whole subtree when the palette changes, because widgets read
/// [AppColors] directly instead of depending on [Theme].
class PaletteRebuilder extends StatefulWidget {
  final ThemeController controller;
  final Widget child;
  const PaletteRebuilder({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<PaletteRebuilder> createState() => _PaletteRebuilderState();
}

class _PaletteRebuilderState extends State<PaletteRebuilder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
