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
  static const String defaultReleaseUrl =
      'https://github.com/$githubRepoOwner/$githubRepoName/releases/latest';

  /// Prüft, ob auf GitHub / im Backend eine neuere Version verfügbar ist
  static Future<AppUpdateInfo> checkForUpdate() async {
    String currentVersion = '1.1.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version;
    } catch (_) {
      currentVersion = '1.1.0';
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
        final tagName = (data['tag_name'] as String? ?? 'v1.1.0')
            .replaceAll('v', '')
            .trim();
        final body = data['body'] as String? ?? 'Fehlerbehebungen und Performance-Verbesserungen.';
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

  /// Zeigt den Update-Dialog in der App an
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(
              kIsWeb ? Icons.bolt : Icons.system_update,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                kIsWeb ? '⚡ Neues Web-Update bereit!' : '🚀 Update verfügbar!',
                style: const TextStyle(
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
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aktuell: v${info.currentVersion}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                  Text(
                    'Neu: v${info.latestVersion}',
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
            Text(
              kIsWeb
                  ? 'Klicke auf "Jetzt neu laden", um die neueste Version sofort per Hard-Reload (Strg + Shift + R) zu laden:'
                  : 'Was ist neu in diesem Update:',
              style: const TextStyle(
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
                      ? '✨ Neue Features & Verbesserungen:\n• Neue Pro-Broker-Charts mit Candlesticks & SMA\n• Edelmetalle & Rohstoffe (Gold, Silber, Platin, Öl)\n• 5-Tage-Privatinsolvenzsperre & Kredit-Cooldown\n• Cyberpunk Neon Bull Branding'
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Später erinnern',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              if (kIsWeb) {
                // Hard-reload the web app immediately without redirecting away!
                reloadWebApp();
              } else {
                final uri = Uri.parse(info.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            icon: Icon(kIsWeb ? Icons.refresh : Icons.download, size: 18),
            label: Text(kIsWeb ? 'Jetzt neu laden (Strg + Shift + R)' : 'Jetzt Updaten'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
