import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import 'platform_reload/reload_helper.dart';

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
    String currentVersion = '1.4.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version;
    } catch (_) {
      currentVersion = '1.4.0';
    }

    try {
      final response = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/$githubRepoOwner/$githubRepoName/releases/latest'),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? 'v1.2.0')
            .replaceAll('v', '')
            .trim();
        final body = data['body'] as String? ?? 'Wichtige Sicherheits-, Kurs- und Stabilitätsupdates.';
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
            side: const BorderSide(color: Colors.redAccent, width: 2.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🚨 Pflicht-Update erforderlich!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                  color: Colors.redAccent.withAlpha(25),
                  border: Border.all(color: Colors.redAccent.withAlpha(80)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Um weiterspielen zu können, musst du die neueste Version installieren. Ältere Versionen werden gesperrt.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                    Text(
                      'Pflicht: v${info.latestVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Was ist neu in diesem Pflicht-Update:',
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
                    kIsWeb
                        ? '✨ Neue Features & Synchronisation:\n• Neue Pro-Broker-Charts (Candlesticks & SMA)\n• Edelmetalle & Rohstoffe (Gold, Silber, Platin, Öl)\n• 5-Tage-Privatinsolvenzsperre & Kredit-Cooldown\n• Cyberpunk Neon Bull Branding'
                        : info.releaseNotes,
                    style: const TextStyle(
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
                    final marketUri = Uri.parse('market://details?id=$androidPackageName');
                    final webPlayStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=$androidPackageName');
                    if (await canLaunchUrl(marketUri)) {
                      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
                    } else if (await canLaunchUrl(webPlayStoreUri)) {
                      await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
                    } else {
                      final githubUri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(githubUri)) {
                        await launchUrl(githubUri, mode: LaunchMode.externalApplication);
                      }
                    }
                  } else {
                    // Windows Desktop: GitHub Release / Installer öffnen
                    final uri = Uri.parse(info.downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                      ? 'Jetzt neu laden (Strg + Shift + R)'
                      : (defaultTargetPlatform == TargetPlatform.android
                          ? 'Jetzt im Google Play Store updaten'
                          : 'Jetzt Setup.exe herunterladen & updaten'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
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
