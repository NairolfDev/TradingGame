# 📈 Trading Game – Open-Source Multi-Asset Trading Simulator

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v1.18.0%2B26-orange.svg)](#)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.0-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting%20%7C%20Firestore-FFCA28?logo=firebase)](https://tradinggame-live.web.app)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-brightgreen)](#)
[![Release Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)](.github/workflows/ci_cd.yml)

Ein realistisches, persistentes, kompetitives und plattformübergreifendes Finanz- & Börsenspiel entwickelt mit **Flutter**, **Firebase** und **Inno Setup** (Version **v1.18.0+26**).

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

## 🌟 Hauptfeatures (v1.18.0+26)

### 1. 📊 Interaktive Pro Broker-Charts, Technische Indikatoren & Orderbuch
Wie in professionellen Trading- und Broker-Apps (TradingView, Bloomberg, Trade Republic):
- **Zeitachsen-Umschaltung**: `1D` (Intraday), `1W` (1 Woche), `1M` (1 Monat), `1Y` (1 Jahr), `ALL` (Gesamtverlauf).
- **Chart-Typen & Kerzen**:
  - 🕯️ **Reale japanische Candlesticks (OHLC)**: Echte Open-, High-, Low- und Close-Kurse mit Dochten/Wicks für präzise historische Kursanalysen.
  - 📈 **Glow Line Chart**: Dynamische Farbverläufe (Emerald-Grün bei Bullenmarkt, Cyber-Rot bei Bärenmarkt).
- **Technische Indikatoren**:
  - **EMA & SMA**: Exponential Moving Average und Simple Moving Average Trendlinien zur automatisierten Trenderkennung.
  - **Bollinger Bands**: Dynamische Volatilitätsbänder (oberes, mittleres und unteres Band) zur Erkennung von Überkauft-/Überverkauft-Phasen.
- **Binance Level-2 Live Order Book**:
  - Reales Echtzeit-Orderbuch mit **Bid/Ask-Spreads** und visueller Markttiefe (Order Book Depth) für Kryptowährungsmärkte.
- **Live-Scrubber & Crosshair**: Interaktives Abtasten mit Finger oder Maus für sekundengenaue historische Notierungen und Zeitstempel.

---

### 2. 🎯 Direktes Stop-Loss/Take-Profit & Trailing-Stop Bots
- **Direktes SL / TP beim Kauf**: Bereits bei der Ordererteilung im Kaufdialog können Stop-Loss- und Take-Profit-Marken direkt gesetzt werden – der Broker wickelt Verkäufe bei Limit-Erreichen vollautomatisch ab.
- **🤖 Trailing-Stop Bots**: Dynamisch nachziehender Stop-Loss, der mit steigenden Kursen automatisch nach oben wandert und bei Marktumkehr Gewinne absichert.
- **Limit- und Stop-Orders**: Präzise Einstiegs- und Ausstiegsregeln für diszipliniertes Risikomanagement.

---

### 3. 🌍 Gigantisches Multi-Asset-Universum
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

### 4. 📰 Datengetriebene Marktnachrichten (Market News)
- **Echtzeit-Nachrichtenfeed**: Datenbasierte Wirtschaftsnachrichten, Zinsentscheide und geopolitische News.
- **Marktreaktionen**: Nachrichtenereignisse beeinflussen Marktstimmung und Volatilität für ein dynamisches, lebendiges Marktumfeld.

---

### 5. 🇦🇹 Optionale 27,5 % KESt-Steuersimulation & Verlustverrechnung
- **Österreichische Kapitalertragsteuer (KESt)**: Auf Wunsch zuschaltbare 27,5 % Versteuerung auf realisierte Gewinne und Zinserträge.
- **Automatischer Verlustverrechnungstopf (Loss Carryforward)**: Realisierte Kursverluste werden fortlaufend gutgeschrieben und mit künftigen Gewinnen steuermindernd verrechnet.

---

### 6. 🏦 Sofortige Planinsolvenz & Progressives Bonitätsrating-System
- **25.000 € Startkredit**: Verfügbar zu Beginn mit 60 Tagen Tilgungsfrist.
- **Progressives Bonitätsrating (Rating AAA bis D)**: Dein Zinssatz und Kreditrahmen passen sich dynamisch deiner Trading-Performance, deinem Eigenkapital und deinem Risiko an.
- **Anti-Spam Cooldown**: Nach jeder Kreditaufnahme greift eine **24-stündige Abklingzeit**, bevor eine weitere Kreditanfrage gestellt werden kann.
- 🚨 **Sofortige Planinsolvenz & Kreditsperre (120 Stunden / 5 echte Tage)**:
  - Fällt dein Portfolio ins Minus (`NetWorth < -10.000 €` und `Cash <= 0`), tritt sofort die gerichtliche Planinsolvenz ein.
  - Das Insolvenzgericht verhängt eine **strikte 5-tägige Kreditsperre (Echtzeit-Kalendertage)** mit sekundengenauem Live-Countdown.
  - Erst nach Ablauf der 120 Stunden erhältst du Zugang zu einem Sanierungs-Notkredit (Rating D mit Risikoaufschlag).

---

### 7. 🏆 Saisonale Bestenlisten (Leaderboard) & Copy-Trading
- **Saisonale Bestenlisten**: Ranglisten filtern nach **All-Time**, **Weekly (Wöchentlich)** und **Monthly (Monatlich)** mit Live-Synchronisation.
- **Öffentliche Portfolios & Copy-Trading**: Verfolge die Portfolios und Erfolgsstrategien führender Trader weltweit.

---

### 8. 💻 Windows Installer & Auto-Update
- **Inno Setup Installer Script**: In `windows/installer.iss` definiert (Version **1.18.0**).
- Erstellt eine offizielle `TradingGame-Setup.exe`:
  - Startmenü- und Desktop-Icons.
  - Clean Uninstaller in den Windows-Einstellungen.
  - Silent-Update-Fähigkeit.
- **GitHub Releases Auto-Update-Checker**: Die App prüft beim Start über die GitHub API auf neue Releases (`vX.Y.Z`) und informiert den Nutzer über neue Versionen und Patchnotes.

---

### 9. 🔒 Version-Gating & Backend-Sicherheit (Build 26+)
- **Hard Version-Floor**: Clients müssen mindestens Build `26` aufweisen. Firestore Security Rules erzwingen serverseitig Schema-Validierung und schließen veraltete Builds vom Schreibzugriff auf das Leaderboard und die Portfolios aus.
- **Schlankes Serverless-Backend**: Direkte Kommunikation mit Firestore, gesichert durch strenge Regeln (`firestore.rules`). Kursfeeds über Binance/CoinGecko und Yahoo Finance.

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
