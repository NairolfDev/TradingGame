import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import 'app_build.dart';
import 'platform_reload/reload_helper.dart';
import 'version_gate.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class AppUpdateService {
  static const String githubRepoOwner = 'NairolfDev';
  static const String githubRepoName = 'TradingGame';
  static const String androidPackageName = 'com.nairolfdev.tradinggame';
  static const String defaultReleaseUrl =
      'https://github.com/$githubRepoOwner/$githubRepoName/releases/latest';

  /// Prüft, ob auf GitHub / im Backend eine neuere Version verfügbar ist
  static Future<AppUpdateInfo> checkForUpdate() async {
    String currentVersion = '1.18.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version;
    } catch (_) {
      currentVersion = '1.18.0';
    }

    // The database decides first: every app compares its build with
    // `config/app.minBuild` and must update when it is older.
    final config = await fetchVersionConfig();
    if (config != null) {
      final build = await currentAppBuild();
      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: config.version ?? 'Build ${config.minBuild}',
        hasUpdate: config.blocks(build),
        releaseNotes:
            config.notes ?? 'Wichtige Verbesserungen und Fehlerbehebungen.',
        downloadUrl: defaultReleaseUrl,
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$githubRepoOwner/$githubRepoName/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? 'v1.2.0')
            .replaceAll('v', '')
            .trim();
        final body =
            data['body'] as String? ??
            'Wichtige Sicherheits-, Kurs- und Stabilitätsupdates.';
        final htmlUrl = data['html_url'] as String? ?? defaultReleaseUrl;

        final hasUpdate = _isVersionHigher(tagName, currentVersion);

        return AppUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: tagName,
          hasUpdate: hasUpdate,
          releaseNotes: body,
          downloadUrl: htmlUrl,
        );
      }
    } catch (_) {
      // Offline oder GitHub Repo noch nicht öffentlich
    }

    // Fallback: Keine Aktualisierung erforderlich
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      hasUpdate: false,
      releaseNotes: 'Du nutzt bereits die aktuellste Version.',
      downloadUrl: defaultReleaseUrl,
    );
  }

  static bool _isVersionHigher(String remote, String local) {
    try {
      final rParts = remote.split('.').map(int.parse).toList();
      final lParts = local.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Zeigt den ZWANGS-Update-Dialog an (Blockiert das Weiterspielen, bis aktualisiert wurde)
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false, // Nicht wegklickbar!
      builder: (ctx) => PopScope(
        canPop: false, // Android Back-Button blockiert!
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.warning, width: 2.0),
          ),
          title: Row(
            children: [
              Icon(Icons.system_update, color: AppColors.warning, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update erforderlich',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Um weiterzuspielen, installiere die neueste Version. Ältere Versionen können nicht mehr speichern.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installiert: v${info.currentVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.loss,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    Text(
                      'Pflicht: v${info.latestVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Was ist neu:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    // Sofortiger Hard-Reload im Webbrowser
                    reloadWebApp();
                  } else if (defaultTargetPlatform == TargetPlatform.android) {
                    // Google Play Store öffnen
                    final marketUri = Uri.parse(
                      'market://details?id=$androidPackageName',
                    );
                    final webPlayStoreUri = Uri.parse(
                      'https://play.google.com/store/apps/details?id=$androidPackageName',
                    );
                    if (await canLaunchUrl(marketUri)) {
                      await launchUrl(
                        marketUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else if (await canLaunchUrl(webPlayStoreUri)) {
                      await launchUrl(
                        webPlayStoreUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      final githubUri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(githubUri)) {
                        await launchUrl(
                          githubUri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  } else {
                    // Windows Desktop: GitHub Release / Installer öffnen
                    final uri = Uri.parse(info.downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                icon: Icon(
                  kIsWeb
                      ? Icons.refresh
                      : (defaultTargetPlatform == TargetPlatform.android
                            ? Icons.play_arrow
                            : Icons.download),
                  size: 20,
                ),
                label: Text(
                  kIsWeb
                      ? 'Jetzt neu laden'
                      : (defaultTargetPlatform == TargetPlatform.android
                            ? 'Jetzt im Google Play Store updaten'
                            : 'Jetzt Setup.exe herunterladen & updaten'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
