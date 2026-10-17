import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// OAuth "Desktop app" client from Google Cloud Console, passed at build time:
/// flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
/// Google treats desktop client secrets as non-confidential; PKCE protects the code.
const desktopGoogleClientId = String.fromEnvironment(
  'GOOGLE_DESKTOP_CLIENT_ID',
);
const _desktopGoogleClientSecret = String.fromEnvironment(
  'GOOGLE_DESKTOP_CLIENT_SECRET',
);

/// Google's loopback-redirect flow for desktop apps (RFC 8252):
/// opens the system browser and returns the Google ID token, or null if cancelled.
Future<String?> desktopGoogleIdToken({
  Duration timeout = const Duration(minutes: 3),
}) async {
  if (desktopGoogleClientId.isEmpty) {
    throw StateError('GOOGLE_DESKTOP_CLIENT_ID fehlt');
  }
  final rnd = Random.secure();
  String randomString(int n) => base64UrlEncode(
    List.generate(n, (_) => rnd.nextInt(256)),
  ).replaceAll('=', '');
  final verifier = randomString(48);
  final challenge = base64UrlEncode(
    sha256.convert(ascii.encode(verifier)).bytes,
  ).replaceAll('=', '');
  final state = randomString(16);

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirectUri = 'http://127.0.0.1:${server.port}';
  try {
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': desktopGoogleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw StateError('Browser konnte nicht geöffnet werden');
    }

    final request = await server.first.timeout(timeout);
    final params = request.uri.queryParameters;
    final ok = params['state'] == state && params['code'] != null;
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(
        '<html><body style="font-family:sans-serif;text-align:center;padding:48px">'
        '<h2>${ok ? 'Anmeldung erfolgreich' : 'Anmeldung abgebrochen'}</h2>'
        '<p>Du kannst dieses Fenster schließen und zum Trading Game zurückkehren.</p>'
        '</body></html>',
      );
    await request.response.close();
    if (!ok) return null;

    final res = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'client_id': desktopGoogleClientId,
        'client_secret': _desktopGoogleClientSecret,
        'code': params['code']!,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (res.statusCode != 200) {
      throw StateError('Token-Austausch fehlgeschlagen (${res.statusCode})');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['id_token']
        as String?;
  } finally {
    await server.close(force: true);
  }
}
