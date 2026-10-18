import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/core/constants/app_colors.dart';
import 'package:trading_game/logic/theme_controller.dart';
import 'package:trading_game/ui/widgets/appearance_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeController> make({
    Map<String, Object> prefs = const {},
    Brightness Function()? brightness,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = ThemeController(
      platformBrightness: brightness ?? () => Brightness.light,
    );
    await pumpEventQueue();
    addTearDown(c.dispose);
    return c;
  }

  test('default follows the device', () async {
    final light = await make(brightness: () => Brightness.light);
    expect(light.appearance, AppAppearance.system);
    expect(light.isDark, isFalse);
    expect(AppColors.palette, same(AppPalette.gameLight));
    final dark = await make(brightness: () => Brightness.dark);
    expect(dark.isDark, isTrue);
    expect(AppColors.palette, same(AppPalette.gameDark));
  });

  test(
    'a device brightness change is followed only in automatic mode',
    () async {
      var device = Brightness.light;
      final c = await make(brightness: () => device);
      var notified = 0;
      c.addListener(() => notified++);
      device = Brightness.dark;
      c.didChangePlatformBrightness();
      expect(AppColors.palette, same(AppPalette.gameDark));
      expect(notified, 1);

      await c.setAppearance(AppAppearance.light);
      expect(AppColors.palette, same(AppPalette.gameLight));
      notified = 0;
      device = Brightness.dark;
      c.didChangePlatformBrightness();
      expect(AppColors.palette, same(AppPalette.gameLight));
      expect(notified, 0);
    },
  );

  test('earlier explicit dark/light choices survive the migration', () async {
    final dark = await make(prefs: {'tg_theme_dark': true});
    expect(dark.appearance, AppAppearance.dark);
    final light = await make(prefs: {'tg_theme_dark': false});
    expect(light.appearance, AppAppearance.light);
    final none = await make();
    expect(none.appearance, AppAppearance.system);
  });

  test('the choice and the style are stored', () async {
    final c = await make();
    await c.setAppearance(AppAppearance.dark);
    await c.setStyle(AppStyle.schlicht);
    expect(AppColors.palette, same(AppPalette.simpleDark));
    final restored = ThemeController(
      platformBrightness: () => Brightness.light,
    );
    await pumpEventQueue();
    addTearDown(restored.dispose);
    expect(restored.appearance, AppAppearance.dark);
    expect(restored.style, AppStyle.schlicht);
  });

  testWidgets('the picker offers Auto, Dunkel and Hell at 200% text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = ThemeController(platformBrightness: () => Brightness.light);
    await tester.runAsync(pumpEventQueue);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearancePicker()),
          ),
        ),
      ),
    );
    for (final label in ['Auto', 'Dunkel', 'Hell']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Dunkel'));
    await tester.pump();
    expect(c.appearance, AppAppearance.dark);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
