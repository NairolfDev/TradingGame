# 🚀 Trading Game – Vollständige Deployment- & Pipeline-Anleitung

Dieses Handbuch führt dich **Schritt für Schritt** durch alle manuellen Schritte, die nur du in deinen persönlichen Accounts (Google Play Console, Firebase Console, GitHub) durchführen kannst.

---

## 📑 Inhaltsverzeichnis
1. [GitHub Repository & CI/CD Secrets Setup](#1-github-repository--cicd-secrets-setup)
2. [Firebase Console Setup (Auth, Firestore & Hosting)](#2-firebase-console-setup-auth-firestore--hosting)
3. [Google Play Console Setup (Android AAB Release)](#3-google-play-console-setup-android-aab-release)
4. [In-App Auto-Update System](#4-in-app-auto-update-system)
5. [Game Balancing & Fehlerbehebungs-Report](#5-game-balancing--fehlerbehebungs-report)

---

## 1. GitHub Repository & CI/CD Setup – ✅ BEREITS ERLEDIGT!

- **GitHub Repository**: [github.com/NairolfDev/TradingGame](https://github.com/NairolfDev/TradingGame) ist live und auf **Public** gesetzt.
- **Branches**: `dev` und `main` sind synchronisiert und aktuell.
- **GitHub Secret**: Das Secret `FIREBASE_SERVICE_ACCOUNT` wurde bereits vollautomatisch per CLI hinterlegt.
- **CI/CD Pipeline**: `.github/workflows/ci_cd.yml` baut bei jedem Push auf `main` oder bei neuen Tags:
  - 🌐 **Web-Build** & automatischer Deploy auf Firebase Hosting
  - 🤖 **Android APK** (`trading_game.apk`)
  - 📦 **Android App Bundle** (`trading_game.aab` für den Google Play Store)
  - 🪟 **Windows Release** (`TradingGame-Windows-x64.zip`)

---

## 2. Firebase Setup (Was erledigt ist & Was du noch brauchst)

### Bereits erledigt:
- ✅ **Firebase Projekt**: `tradinggame-austria-prod` erstellt und konfiguriert.
- ✅ **Firebase Security Rules (`firestore.rules`)**: Vollständig implementiert und live auf Firebase deployt!
- ✅ **Firebase Hosting**: Live unter [https://tradinggame-austria-prod.web.app](https://tradinggame-austria-prod.web.app).

### Deine einzigen 2 Klicks in Firebase:
1. Öffne die [Firebase Authentication Konsole](https://console.firebase.google.com/project/tradinggame-austria-prod/authentication/providers).
2. Klicke auf **Get Started** (falls noch nicht geschehen).
3. Unter **Sign-in method**:
   - **E-Mail/Passwort**: Anklicken -> **Aktivieren** -> **Speichern**.
   - *(Optional)* **Google**: Anklicken -> **Aktivieren** -> Support-E-Mail wählen -> **Speichern**.

---

## 3. Google Play Console Setup (Android AAB Release)

### Schritt 3.1: App in der Play Console anlegen
1. Öffne die [Google Play Console](https://play.google.com/console/).
2. Klicke oben rechts auf **App erstellen**.
3. **App-Details**:
   - App-Name: `Trading Game – Börsenspiel Österreich`
   - Standardsprache: `Deutsch (Deutschland) - de-DE`
   - App oder Spiel: `Spiel`
   - Kostenlos oder kostenpflichtig: `Kostenlos`
4. Bestätige die Erklärungen und klicke auf **App erstellen**.

### Schritt 3.2: App-Integrität & Play App Signing
1. Gehe im linken Menü zu **Release** -> **Einrichtung** -> **App-Integrität**.
2. Google Play verwendet standardmäßig **Play App Signing** (Google verwaltet deinen Signierschlüssel). Das bedeutet, du kannst dein gebautes App Bundle direkt hochladen!

### Schritt 3.3: Release erstellen & AAB hochladen
1. Klicke links auf **Testen** -> **Interner Test** (oder **Geschlossener Test**).
2. Klicke oben rechts auf **Neuen Release erstellen**.
3. Lade die Datei **`trading_game.aab`** hoch.
   - Diese findest du nach dem lokalen Build unter: `build\app\outputs\bundle\release\app-release.aab`
   - Oder lade sie direkt aus den Artifacts deines GitHub Actions Runs herunter!
4. Release-Name: `1.0.0`
5. Klicke auf **Speichern** und **Release überprüfen**.
6. Füge deine eigene E-Mail-Adresse als Tester hinzu – schon kannst du das Spiel über den Play Store Link auf deinem Android-Handy installieren!

---

## 4. In-App Auto-Update System

Das Spiel verfügt über einen automatischen Update-Prüfer (`AppUpdateService`), der beim Start und manuell per Klick auf **"Nach Updates suchen"** aktiv wird:
1. Er prüft die GitHub API: `https://api.github.com/repos/<USER>/TradingGame/releases/latest`.
2. Findet er eine neuere Version (z. B. du erstellst Tag `v1.0.1`), öffnet das Spiel automatisch einen Dialog:
   - **"🚀 Neues Update verfügbar!"**
   - Zeigt die Release Notes und Changelogs an.
   - Auf Android: Bietet direkten APK-Download oder Weiterleitung zum Play Store.
   - Auf Windows: Bietet Download der neuen ZIP/Installer-Datei.
   - Auf Web: Lädt die neue Version durch Neuladen im Browser.

### Wie du ein Update veröffentlichst:
Um ein weltweites Update für alle Plattformen gleichzeitig auszurollen, erstellst du einfach einen Git-Tag:
```powershell
git tag v1.0.1
git push origin v1.0.1
```
GitHub Actions baut daraufhin automatisch Web, Android und Windows und veröffentlicht das Release!

---

## 5. Game Balancing & Fehlerbehebungs-Report

Nach intensiver mathematischer Analyse wurden folgende Kernprobleme aufgedeckt und gelöst:

| Problem / Bug | Warum es aufgetreten ist | Wie wir es gelöst haben |
| :--- | :--- | :--- |
| **Start-Net-Worth war negativ (-369 €)** | Der Startkredit von 50.000 € wurde sofort mit allen Zinsen der 60 Tage als Schuld gerechnet, obwohl noch kein Tag vergangen war. | `remainingDebt` startet exakt bei 50.000,00 €. Zinsen laufen erst tageweise auf. Vorzeitige Tilgung spart Zinsen! Start-Net-Worth ist exakt **0,00 €**. |
| **ROI-Anzeige zeigte -100% am Start** | In `totalRoiPercent` wurde `(netWorth - startingCapital) / startingCapital` gerechnet. Da `netWorth` schon `Assets - Debt` (= 0) war, zog die Formel die 50k doppelt ab! | Formel korrigiert zu `netWorth / 50000.0`. Start-ROI ist exakt **0.0%**. Bei 5.000 € Gewinn: **+10.0%**. |
| **Start-Bonität war fälschlicherweise CCC (Hochrisiko)** | `CreditRatingService` zog bei `netWorth <= 0` 35 Punkte und bei `debt >= 50k` 10 Punkte ab. Ein Neuling hatte sofort Score 35 und Kredithai-Zinsen! | Bewertung neu kalibriert: Jeder Neuling startet mit **AA Solid (Score 80, 5,5% p.a.)**. Schlechtere Zinsen gibt es nur bei Liquidations, hohen Verlusten oder Überschuldung. |
| **50x CFDs wurden in Sekunden zufällig liquidiert** | Die Tick-Volatilität war mit Faktor `0.40` skaliert. Bei 50x reicht 1,8% Kursschwankung für eine Zwangsliquidation. | Tick-Volatilität auf **`0.08`** ausbalanciert. Trades brauchen nun echte Markttrends und Strategie, statt nach 5 Sekunden im Zufall zu sterben. |
| **Broker-Transaktionskosten wurden doppelt verrechnet** | In `executeBuy` wurde `collateral: totalCost` (inkl. 19,90 € Spesen) statt der reinen Margin gesetzt. | Margin und Transaktionsgebühren sauber getrennt. |
| **Leaderboard-Diskrepanz** | Konkurrenten hatten Net Worth basierend auf 50k Startvermögen (z.B. Anna 62.400 €). | Konkurrenten neu kalibriert auf ihren Reingewinn über den Startkredit (Anna: 12.400 €). Der Spieler startet auf Rang 8 bei 0 € und überholt Anna bei 10.000 € Gewinn! |

---

### Schneller lokaler Test:
- **Im Browser spielen**: Starte einfach die Datei [`serve_web_local.bat`](file:///c:/Users/oberh/WenziComp/TradingGame/serve_web_local.bat) – sie öffnet `http://localhost:8088` sofort in Chrome!
- **Windows Desktop testen**: Führe [`start_game_windows.bat`](file:///c:/Users/oberh/WenziComp/TradingGame/start_game_windows.bat) aus.
