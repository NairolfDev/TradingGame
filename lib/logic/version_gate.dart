import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_build.dart';

/// What `config/app` in Firestore says about the minimum allowed app build.
class VersionConfig {
  final int minBuild;
  final String? version;
  final String? notes;
  const VersionConfig({required this.minBuild, this.version, this.notes});

  static VersionConfig? fromJson(Map<String, dynamic>? json) {
    final min = json?['minBuild'];
    if (min is! num || min <= 0) return null;
    return VersionConfig(
      minBuild: min.toInt(),
      version: json?['version'] as String?,
      notes: json?['notes'] as String?,
    );
  }

  /// Older builds must update; newer ones (a rollout ahead of the database)
  /// are fine.
  bool blocks(int build) => build < minBuild;
}

/// Reads the required version from the database; null when it cannot be read
/// (offline, no Firebase), so callers can fall back instead of locking out.
Future<VersionConfig?> Function() fetchVersionConfig = () async {
  try {
    final doc = await FirebaseFirestore.instance
        .doc('config/app')
        .get()
        .timeout(const Duration(seconds: 6));
    return VersionConfig.fromJson(doc.data());
  } catch (_) {
    return null;
  }
};

/// Records the running build in `sessions/{uid}`. The security rules only let
/// a signed-in player write while this stamp is at least `config/app.minBuild`.
class SessionStamp {
  const SessionStamp();

  Future<void> write(String uid) async {
    try {
      await FirebaseFirestore.instance
          .doc('sessions/$uid')
          .set({'build': await currentAppBuild()})
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline or blocked by the rules: the update prompt explains the latter.
    }
  }
}
