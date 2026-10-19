import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/logic/app_build.dart';
import 'package:trading_game/logic/app_update_service.dart';
import 'package:trading_game/logic/version_gate.dart';

void main() {
  test('only older builds are blocked', () {
    const config = VersionConfig(minBuild: 14);
    expect(config.blocks(13), isTrue);
    expect(config.blocks(14), isFalse);
    expect(config.blocks(15), isFalse);
  });

  test('config parsing ignores missing or invalid values', () {
    expect(VersionConfig.fromJson(null), isNull);
    expect(VersionConfig.fromJson({'minBuild': 'x'}), isNull);
    expect(VersionConfig.fromJson({'minBuild': 0}), isNull);
    final c = VersionConfig.fromJson({
      'minBuild': 14,
      'version': '1.10.0',
      'notes': 'Neu',
    });
    expect(c?.minBuild, 14);
    expect(c?.version, '1.10.0');
  });

  group('update prompt', () {
    late Future<VersionConfig?> Function() savedFetch;
    late Future<int> Function() savedBuild;
    setUp(() {
      savedFetch = fetchVersionConfig;
      savedBuild = currentAppBuild;
    });
    tearDown(() {
      fetchVersionConfig = savedFetch;
      currentAppBuild = savedBuild;
    });

    test('an outdated build gets the update prompt', () async {
      fetchVersionConfig = () async =>
          const VersionConfig(minBuild: 14, version: '1.10.0');
      currentAppBuild = () async => 13;
      final info = await AppUpdateService.checkForUpdate();
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '1.10.0');
    });

    test('the required build plays on without a prompt', () async {
      fetchVersionConfig = () async => const VersionConfig(minBuild: 14);
      currentAppBuild = () async => 14;
      expect((await AppUpdateService.checkForUpdate()).hasUpdate, isFalse);
    });
  });
}
