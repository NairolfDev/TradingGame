import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';

/// Gamer = bunte Farben, Animationen, Belohnungseffekte.
/// Schlicht = ruhiger Broker-Look ohne Effekte.
enum AppStyle { gamer, schlicht }

class ThemeController extends ChangeNotifier {
  static const _keyStyle = 'tg_theme_style';
  static const _keyDark = 'tg_theme_dark';

  AppStyle _style = AppStyle.gamer;
  bool _dark = true;

  ThemeController() {
    _apply();
    _load();
  }

  AppStyle get style => _style;
  bool get isDark => _dark;
  bool get isGamer => _style == AppStyle.gamer;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final style = prefs.getString(_keyStyle);
      _style = AppStyle.values.firstWhere(
        (s) => s.name == style,
        orElse: () => AppStyle.gamer,
      );
      _dark = prefs.getBool(_keyDark) ?? true;
      _apply();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setStyle(AppStyle style) => _set(style, _dark);
  Future<void> setDark(bool dark) => _set(_style, dark);

  Future<void> _set(AppStyle style, bool dark) async {
    if (style == _style && dark == _dark) return;
    _style = style;
    _dark = dark;
    _apply();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStyle, style.name);
      await prefs.setBool(_keyDark, dark);
    } catch (_) {}
  }

  void _apply() {
    AppColors.palette = switch ((_style, _dark)) {
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
