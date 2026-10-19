# 📈 Trading Game – Open-Source Multi-Asset Trading Simulator

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.0-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting%20%7C%20Firestore-FFCA28?logo=firebase)](https://tradinggame-live.web.app)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-brightgreen)](#)
[![Release Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)](.github/workflows/ci_cd.yml)

Ein realistisches, persistentes, kompetitives und plattformübergreifendes Finanz- & Börsenspiel entwickelt mit **Flutter**, **Firebase** und **Inno Setup**.

Tritt an weltweiten Märkten an, meistere Hebelzertifikate bis 50x, manage Kredite und Bonitätsratings, überlebe drohende Insolvenzen und steige im ewigen **Endlos-Leaderboard** an die Spitze auf!

🌐 **Live Web-App spielen:** [https://tradinggame-live.web.app](https://tradinggame-live.web.app)  
💻 **Windows Desktop Installer:** Verfügbar unter [GitHub Releases](../../releases) (`TradingGame-Setup.exe` / `.zip`)  
🐧 **Linux Desktop:** Verfügbar unter [GitHub Releases](../../releases) (`TradingGame-Linux-x64.tar.gz`)  
🍎 **macOS Desktop:** Verfügbar unter [GitHub Releases](../../releases) (`TradingGame-macOS.zip`)  
📱 **Android App Bundle & APK:** Verfügbar in der Google Play Console und den [GitHub Releases](../../releases) (`trading_game.aab` / `trading_game.apk`)

---

## ⚖️ Open-Source & Copyleft-Lizenz (GNU GPLv3)

Dieses Projekt ist unter der **GNU General Public License v3.0 (GPLv3)** lizenziert.
- ✅ **Jeder darf dieses Repository forken, klonen, modifizieren und weiterentwickeln.**
- 🔄 **Copyleft-Bedingung:** Sämtliche abgeleiteten Werke, Änderungen und Forks **müssen zwingend unter derselben freien GPLv3-Lizenz als Open-Source** veröffentlicht werden.
- 📜 Vollständiger Lizenztext: Siehe [LICENSE](LICENSE).

---

## 🔒 Wichtiger Sicherheits- & Secrets-Hinweis (Security Rules)

> [!CAUTION]
> **KEINE GEHEIMNISSE ODER KEYS INS REPO EINCHECKEn!**  
> Zugangsdaten, API-Schlüssel und Zertifikate gehören niemals in die Git-Historie.

Folgende Dateien und sensible Muster sind bereits in der [.gitignore](.gitignore) geschützt und dürfen **niemals** committed werden:
- `android/key.properties` (Android Signing Keystore Passwörter)
- `android/app/*.jks` oder `android/app/*.keystore` (Release Signaturschlüssel)
- `android/app/google-services.json` (Produktions-Schlüssel)
- `service-account-key.json` / Service-Account-Tokens
- `.env`, `.env.local`, `.env.production`

Wenn du dein eigenes Deployment aufsetzt, nutze **GitHub Secrets** (z. B. `FIREBASE_SERVICE_ACCOUNT_TRADINGGAME_AUSTRIA_PROD`) in den GitHub Actions Pipelines.

---

## 🌟 Hauptfeatures

### 1. 📊 Interaktive Pro Broker-Charts
Wie in professionellen Trading- und Broker-Apps (TradingView, Bloomberg, Trade Republic):
- **Zeitachsen-Umschaltung**: `1D` (Intraday), `1W` (1 Woche), `1M` (1 Monat), `1Y` (1 Jahr), `ALL` (Gesamtverlauf).
- **Chart-Typen**:
  - 🕯️ **Japanische Candlesticks (Kerzenchart)** mit realen Open, High, Low, Close (OHLC) Kursen und Dochten/Wicks.
  - 📈 **Glow Line Chart** mit dynamischen Farbverläufen (Emerald-Grün bei Bullenmarkt, Cyber-Rot bei Bärenmarkt).
- **Indikatoren**: Zu- und abschaltbarer gleitender Durchschnitt (**SMA 5 Trendlinie**).
- **Live-Scrubber & Crosshair**: Berühre oder fahre mit der Maus über den Chart, um exakte historische Kurse und Zeitstempel abzulesen.

---

### 2. 🌍 Gigantisches Multi-Asset-Universum
- 🥇 **Edelmetalle & Industrielle Rohstoffe**:
  - **Gold** (`XAU/EUR`) – Krisenwährung Nummer 1.
  - **Silber** (`XAG/EUR`) – Hohe industrielle und monetäre Nachfrage.
  - **Platin** (`XPT/EUR`) & **Palladium** (`XPD/EUR`) – Seltene Katalysator-Edelmetalle.
  - **Brent Rohöl** (`BRENT`) – Globaler Energiemarkt.
  - **Kupfer** (`COPPER`) – Das Barometer der Weltwirtschaft.
  - **Lithium** (`LITHIUM`) & **Uran** (`URANIUM`) – Batterierohstoffe und Atomenergie.
  - **Kaffee Arabica** (`COFFEE`) – Weichrohstoff mit hoher Volatilität.
- 🏛️ **Staats- und Unternehmensanleihen (Bonds)**:
  - Republik Österreich 10J Bundesanleihe (`BUND10Y-AT`, 2.90 % Kupon).
  - US-Treasury 10J (`US10Y`, 4.25 % Kupon).
  - Schweizer Eidgenossenschaft 10J (`CONFED10Y`, 0.85 % Kupon – Höchste Stabilität).
  - UK Gilt 10J (`UK10Y`, 4.10 % Kupon).
  - Apple Corporate Bond (`AAPL-CORP`, 3.85 % Kupon).
  - Siemens Green Bond (`GREEN-BOND`, 3.20 % Kupon).
  - Emerging Markets High Yield Bond (`EM-HIGH-YIELD`, 7.80 % Kupon).
- 📈 **Internationale & Lokale Aktien**: OMV Wien, Erste Group Bank, Rheinmetall, Apple, Nvidia, Tesla u. v. m.
- 🪙 **Kryptowährungen (24/7)**: Bitcoin (BTC), Ethereum (ETH), Solana (SOL), Dogecoin (DOGE).
- 🧺 **Index-ETFs**: iShares Core MSCI World, Vanguard S&P 500, ATX Prime ETF.
- ⚡ **CFDs & Hebelprodukte bis 50x**: Handele Long & Short mit Hebelwirkung, Echtzeit-Liquidationspreisen und automatischem Margin-Closeout.

---

### 3. 🏦 Kredite, Bonitätsstufen (Schufa/Rating) & Echte Privatinsolvenz
- **25.000 € Startkredit**: Verfügbar zu Beginn mit 60 Tagen Tilgungsfrist.
- **Bonitätssystem (Rating AAA bis D)**: Dein Zinssatz passt sich dynamisch deiner Trading-Performance an.
- **Anti-Spam Cooldown**: Nach jeder Kreditaufnahme greift eine **24-stündige Abklingzeit**, bevor eine weitere Kreditanfrage gestellt werden kann.
- 🚨 **Privatinsolvenz-Sperre (120 Stunden / 5 echte Tage)**:
  - Fällt dein Portfolio ins Minus (`NetWorth < -10.000 €` und `Cash <= 0`), musst du den Insolvenzantrag stellen.
  - Das Insolvenzgericht verhängt eine **strikte 5-tägige Kreditsperre (Echtzeit-Kalendertage)**.
  - Ein Live-Countdown zeigt die verbleibende Sperrzeit sekundengenau an.
  - Erst nach Ablauf der 120 Stunden erhältst du Zugang zu einem Sanierungskredit (Rating D mit Risikoaufschlag).

---

### 4. 💻 Windows Installer & Auto-Update
- **Inno Setup Installer Script**: In `windows/installer.iss` definiert.
- Erstellt eine offizielle `TradingGame-Setup.exe`:
  - Startmenü- und Desktop-Icons.
  - Clean Uninstaller in den Windows-Einstellungen.
  - Silent-Update-Fähigkeit.
- **GitHub Releases Auto-Update-Checker**: Die App prüft beim Start über die GitHub API auf neue Releases (`vX.Y.Z`) und informiert den Nutzer über neue Versionen und Patchnotes.

---

### 5. ☁️ Kein eigenes Backend (Firebase Free Tier)
Es gibt keine Cloud Functions. Die App spricht direkt mit Firestore (abgesichert über `firestore.rules`)
und holt Kurse direkt bei Binance/CoinGecko (Krypto) und Yahoo Finance (Aktien/ETFs; nur Android/Desktop,
der Browser blockiert Yahoo per CORS und nutzt dort simulierte Kurse). Kursalarme prüft die App selbst,
solange sie läuft.

---

## 🛠️ Lokale Entwicklung & Setup-Anleitung

### Voraussetzungen
1. **Flutter SDK** (Version 3.24.x oder höher, empfohlen: Flutter 3.41.0 / Dart 3.11.0).
2. **Git** installiert.
3. Für Windows Desktop: Visual Studio C++ Desktop Development Tools & **Inno Setup 6** (für den `.exe` Installer).
4. Für Android: Android Studio / Android SDK (API Level 23 bis 34).
5. Für Firebase & Backend: **Node.js 20+** und **Firebase CLI** (`npm install -g firebase-tools`).

### 1. Repository klonen
```bash
git clone https://github.com/NairolfDev/TradingGame.git
cd TradingGame
```

### 2. Flutter Dependencies installieren
```bash
flutter pub get
```

### 3. Tests ausführen & Code-Qualität prüfen
```bash
flutter test
flutter analyze
```

### 4. App lokal starten
```bash
# Auf Windows Desktop starten
flutter run -d windows

# Im Chrome Web-Browser starten
flutter run -d chrome

# Auf einem Android-Gerät oder Emulator starten
flutter run -d android
```

---

## 📦 Build & Deployment

### Web Release bauen & deployen
```bash
flutter build web --release
firebase deploy --only hosting --project tradinggame-austria-prod
```

### Windows Desktop & Inno Setup Installer bauen
```bash
# 1. Windows Release kompilieren
flutter build windows --release

# 2. Inno Setup Compiler ausführen (erzeugt windows/Output/TradingGame-Setup.exe)
iscc windows/installer.iss
```

### Android App Bundle (`.aab`) & APK bauen
```bash
# Android App Bundle für die Google Play Console
flutter build appbundle --release

# Standalone APK für Direktdownload
flutter build apk --release
```

---

## 🚀 CI/CD Pipeline (GitHub Actions)

Das Repository enthält eine vollautomatisierte Pipeline in `.github/workflows/ci_cd.yml`:
- **Bei Push auf `main`/`dev` oder Pull Requests:**
  - Automatische Validierung mit `flutter analyze` und `flutter test`.
  - Paralleler Build von:
    - 📦 `android-aab` (Google Play App Bundle)
    - 📱 `android-apk` (Universal Release APK)
    - 🌐 `web-build` (Web Release)
    - 💻 `windows-release` (Windows Binary + Inno Setup `TradingGame-Setup.exe`)
- **Bei Git-Tagging (z.B. `git tag v1.1.0 && git push origin v1.1.0`):**
  - Automatisches Erstellen eines **GitHub Releases** mit beigefügtem Windows-Installer (`TradingGame-Setup.exe`), Android APK und vollständigen Release-Notes.
  - Automatisches Deployment der Web-App auf Firebase Hosting (`tradinggame-live`).

---

## 🧑‍💻 Beitragen (Contributing)

Contributions sind herzlich willkommen!
1. Forke das Repository (`git fork`).
2. Erstelle einen Feature-Branch (`git checkout -b feature/mein-neues-feature`).
3. Schreibe Tests und stelle sicher, dass `flutter test` und `flutter analyze` fehlerfrei durchlaufen.
4. Committe deine Änderungen (`git commit -m "feat: mein neues feature"`).
5. Erstelle einen Pull Request auf den Branch `dev`.

---

## 📜 Lizenz

Copyright (C) 2026 Florian Oberhauser & Contributoren.  
Lizenziert unter der **GNU General Public License v3.0**.

## Datenqualität und aktueller Prüfbericht

Erfundene Marktdaten wurden aus der Anzeige entfernt. Unterstützte EUR-Werte nutzen die Kursfeeds; nicht aktualisierte Werte sind als Katalogkurse gekennzeichnet. Copy-Trading und Markttiefe zeigen ohne echten Feed einen Leerzustand. Historische Charts zeigen verfügbare Schlusskurse statt künstlicher OHLC-Kerzen. Details, Korrekturen und Grenzen: [Qualitätsprüfung 16.10.2026](docs/quality-review-2026-10-16.md).

Ein Push auf `dev` deployt nach erfolgreichen Tests den Web-Build auf die bestehende Firebase-Live-Site. Android-/Desktop-Releases werden nur von `main` erstellt.
