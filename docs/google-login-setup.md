# Google-Login einrichten (alle Plattformen)

Stand: 17.10.2026. Firebase-Projekt: `tradinggame-austria-prod`.

## Was im Code repariert wurde

- **Login-Screen blieb nach der Kontoauswahl offen.** Während der Anmeldung hat `main.dart`
  den kompletten App-Inhalt gegen einen Lade-Spinner getauscht. Der Login-Screen wollte sich danach
  mit dem `context` dieses weggeworfenen Screens schließen. Das wirft intern einen Fehler, und es passiert scheinbar „nichts".
  Jetzt zeigt nur der App-Start einen Spinner, und der Login-Screen schließt sich selbst
  (`AuthProvider.isInitializing`, `AuthScreen._success`). Betrifft alle Plattformen inkl. Web.
- **Windows/Linux:** `google_sign_in` unterstützt diese Plattformen nicht. Neu ist ein Browser-Login
  über die System-Loopback-Adresse (`lib/logic/desktop_google_sign_in.dart`), siehe Schritt 3.

## 1. Android (Play Store) – SHA-Fingerprints eintragen

Ohne diese Fingerprints ist `oauth_client` in `android/app/google-services.json` leer.
Google bricht die Anmeldung dann nach der Kontoauswahl mit `DEVELOPER_ERROR (10)` ab.

1. **Play Console** öffnen → App „Trading Game" → *Test und Release* → *Einrichtung* → **App-Integrität**
   → Tab *App-Signatur*.
2. Dort zwei Zertifikate kopieren, jeweils **SHA-1** und **SHA-256**:
   - *Zertifikat des App-Signaturschlüssels* (damit signiert Google die Play-Store-Version)
   - *Zertifikat des Uploadschlüssels*
3. **Firebase Console** → Projekt `tradinggame-austria-prod` → Zahnrad → *Projekteinstellungen*
   → *Allgemein* → unter „Meine Apps" die Android-App `com.nairolfdev.tradinggame`
   → **Fingerabdruck hinzufügen**. Alle vier Werte eintragen, dazu für lokale Debug-Builds:
   - Debug SHA-1: `5F:D3:BF:26:85:9B:54:D0:DC:6E:42:4C:B6:8C:5A:28:5E:A4:FA:C0`
   - Debug SHA-256: `89:1E:F7:9E:3C:66:F9:F7:5E:27:9A:FF:3A:1E:81:73:35:AA:2D:86:27:B2:EE:1D:15:F7:44:24:6F:5D:71:07`
4. Firebase Console → *Authentication* → *Anmeldemethode* → **Google** muss aktiviert sein,
   mit einer Support-E-Mail.
5. In den Projekteinstellungen **`google-services.json` neu herunterladen** und
   `android/app/google-services.json` ersetzen. Prüfen: `oauth_client` darf nicht mehr `[]` sein.
6. Neue Version bauen (`flutter build appbundle`) und hochladen. Die alte Play-Version funktioniert erst
   mit der neuen Datei.

## 2. Web – wichtigste Ursache des Hängers

**Diagnose (17.10.2026, in deinem Chrome nachgestellt):** Das Popup öffnet sich korrekt. Nach der
Kontoauswahl kommt das Ergebnis aber nie in der App an. Der Grund: Das Popup läuft auf
`tradinggame-austria-prod.firebaseapp.com`, die App auf einer anderen Domain. Den Rückkanal
(ein unsichtbarer iframe dieser Domain) partitioniert bzw. blockiert Chrome als Drittanbieter-Speicher.

**Code-Fix:** Auf der gehosteten Seite nutzt die App jetzt die eigene Domain als `authDomain`
(`lib/main.dart`, `_firebaseOptions`). Firebase Hosting liefert `/__/auth/handler` automatisch unter
`https://tradinggame-live.web.app/__/auth/handler` aus, damit ist alles First-Party. Zusätzlich bricht
die Anmeldung nach 2 Minuten mit einer verständlichen Meldung ab, statt ewig „Bitte warten …" zu zeigen.

**Was du in der Console machen musst:**
1. **Google Cloud Console** → Projekt `tradinggame-austria-prod` → *APIs & Dienste* → *Anmeldedaten*
   → OAuth-Client **„Web client (auto created by Google Service)"** öffnen. Wichtig: genau der Client
   `974968386258-im5jt00q3i1mjj9vrarvnaqpdjri0fgu`, den Firebase verwendet (eingetragen am 17.10.2026).
   Prüfen lässt sich das mit `createAuthUri` der Identity-Toolkit-API, dort stehen `client_id` und
   `redirect_uri` in der zurückgegebenen `authUri`.
2. Unter **Autorisierte Weiterleitungs-URIs** hinzufügen:
   - `https://tradinggame-live.web.app/__/auth/handler`
   - `https://tradinggame-live.firebaseapp.com/__/auth/handler`
   - (für jede eigene Domain ebenso `https://DOMAIN/__/auth/handler`)
3. Unter **Autorisierte JavaScript-Quellen**: `https://tradinggame-live.web.app` ergänzen.
4. Firebase Console → *Authentication* → *Einstellungen* → **Autorisierte Domains**: `localhost`,
   `tradinggame-live.web.app` und `tradinggame-live.firebaseapp.com` müssen dort stehen.
5. Neu bauen und deployen: `flutter build web` und danach `firebase deploy --only hosting`.

**Lokal (localhost:8088):** Dort gibt es keinen eigenen `/__/auth`-Handler. Zum Testen in Chrome unter
`chrome://settings/cookies` → *Websites, die Drittanbieter-Cookies verwenden dürfen* →
`http://localhost:8088` hinzufügen. Klappt der Login danach, ist die Diagnose bestätigt.

## 3. Windows (Desktop)

1. **Google Cloud Console** → gleiches Projekt → *APIs & Dienste* → *Anmeldedaten* →
   *Anmeldedaten erstellen* → *OAuth-Client-ID* → Anwendungstyp **Desktop-App** → Name „Trading Game Windows".
2. Client-ID und Client-Secret kopieren. Bei Desktop-Apps gilt das Secret laut Google nicht als geheim,
   der Code nutzt zusätzlich PKCE.
3. Bauen/Starten mit:

   ```bash
   flutter run -d windows --dart-define-from-file=dart_defines.local.json
   ```

   Ohne diese Werte zeigt der Button eine klare Meldung statt still zu scheitern.
4. Die Anmeldung öffnet den Standardbrowser. Nach der Kontoauswahl erscheint „Anmeldung erfolgreich",
   und die App ist angemeldet.

## 4. iOS / macOS

Für iOS gibt es aktuell **keine** Firebase-Konfiguration (`firebase_options.dart` wirft auf iOS einen
Fehler). macOS nutzt fälschlich die Web-Konfiguration.

1. Firebase Console → *Projekt hinzufügen* → **iOS-App** mit Bundle-ID aus Xcode
   (`ios/Runner.xcodeproj`, Target Runner → General) registrieren. Für macOS dasselbe mit der
   macOS-Bundle-ID.
2. Am Mac im Projektordner ausführen:

   ```bash
   flutterfire configure --project=tradinggame-austria-prod --platforms=android,ios,macos,web,windows
   ```

   Das erzeugt `GoogleService-Info.plist` und aktualisiert `lib/firebase_options.dart`.
3. In `ios/Runner/Info.plist` (und `macos/Runner/Info.plist`) das URL-Schema eintragen.
   Den Wert `REVERSED_CLIENT_ID` aus der `GoogleService-Info.plist` verwenden:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>com.googleusercontent.apps.XXXX</string></array>
     </dict>
   </array>
   ```

4. macOS: in `macos/Runner/DebugProfile.entitlements` und `Release.entitlements` muss
   `com.apple.security.network.client` auf `true` stehen, dazu Keychain Sharing aktivieren.
