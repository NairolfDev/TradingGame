import 'package:package_info_plus/package_info_plus.dart';

/// Build number of the running app (`+N` in pubspec). Tests override it.
Future<int> Function() currentAppBuild = () async {
  try {
    return int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  } catch (_) {
    return 0;
  }
};
