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

## 1. GitHub Repository & CI/CD Secrets Setup

Deine CI/CD-Pipeline in `.github/workflows/ci_cd.yml` ist bereits vollständig programmiert. Sobald du deinen Code auf GitHub pushst, baut GitHub Actions automatisch:
- Den **Web-Build** und deployt ihn auf Firebase Hosting.
- Die **Android APK** (zum direkten Installieren am Smartphone).
- Das **Android App Bundle (.aab)** für die Google Play Console.
- Die **Windows Desktop Version** (.zip).
- Und bei jedem Git-Tag (z. B. `v1.0.0`) ein **GitHub Release**, das die Auto-Update-Prüfung im Spiel füttert!

### Schritt 1.1: Repository auf GitHub anlegen & Public schalten
1. Öffne [github.com/new](https://github.com/new).
2. Vergib den Repository-Namen: `TradingGame` (oder `trading_game`).
3. Wähle **Public** (damit GitHub Releases öffentlich heruntergeladen werden können und dein Auto-Update-Check für alle Spieler ohne API-Token funktioniert).
4. Klicke auf **Create repository** (ohne README / .gitignore anzuhaken, da wir diese schon lokal haben).

### Schritt 1.2: Code von deinem PC auf GitHub hochladen
Öffne PowerShell im Projektordner `C:\Users\oberh\WenziComp\TradingGame` und führe aus:
```powershell
git init
git add .
git commit -m "feat: complete trading game with loans, credit rating, real-time hours, luxury shop and multi-platform CI/CD"
git branch -M main
git remote add origin https://github.com/<DEIN-GITHUB-USERNAME>/TradingGame.git
git push -u origin main
```

### Schritt 1.3: GitHub Actions Secret für Firebase Hosting hinterlegen
Damit GitHub Actions die Web-Version automatisch auf Firebase veröffentlichen darf:
1. Gehe in deinem GitHub-Repository auf **Settings** -> **Secrets and variables** -> **Actions**.
2. Klicke auf **New repository secret**.
3. **Name**: `FIREBASE_SERVICE_ACCOUNT`
4. **Secret**: Füge hier den JSON-Schlüssel aus Firebase ein (wie du diesen Schlüssel erstellst, siehst du in Abschnitt 2.3).
5. Klicke auf **Add secret**.

---

## 2. Firebase Console Setup (Auth, Firestore & Hosting)

Dein Firebase-Projekt wurde bereits mit der Project-ID **`tradinggame-austria-prod`** erstellt und im Flutter-Code konfiguriert. Du musst nun noch die Authentifizierungsmethoden und die Datenbank in der Web-Konsole aktivieren.

### Schritt 2.1: Login-Methoden (Auth) aktivieren
1. Öffne die [Firebase Console](https://console.firebase.google.com/).
2. Wähle dein Projekt **`tradinggame-austria-prod`** aus.
3. Klicke links im Menü auf **Build** -> **Authentication** (bzw. Authentifizierung) -> **Get started**.
4. Wähle im Reiter **Sign-in method**:
   - **E-Mail/Passwort**:
     - Klicke darauf -> Schalter auf **Aktivieren** stellen -> **Speichern**.
   - **Google**:
     - Klicke auf **Google** -> Schalter auf **Aktivieren** stellen.
     - Wähle deine Support-E-Mail aus dem Dropdown.
     - Klicke auf **Speichern**.

### Schritt 2.2: Cloud Firestore Datenbank aktivieren
1. Klicke links im Menü auf **Build** -> **Firestore Database** -> **Create database**.
2. Wähle als Standort **`europe-west3 (Frankfurt)`** oder `europe-west1 (Belgien)`.
3. Wähle **Start in test mode** (Testmodus) und klicke auf **Enable**.
4. **Firestore Sicherheitsregeln (Rules)**:
   Gehe auf den Reiter **Rules** (Regeln) und füge folgendes ein:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Leaderboard darf jeder lesen, aber nur angemeldete Nutzer aktualisieren
       match /leaderboard/{docId} {
         allow read: if true;
         allow write: if request.auth != null;
       }
       // Portfolio & Kredite: Jeder Nutzer darf nur sein eigenes Dokument lesen und schreiben
       match /portfolios/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
5. Klicke auf **Publish** (Veröffentlichen).

### Schritt 2.3: Firebase Service Account Schlüssel für GitHub generieren
1. Klicke oben links auf das **Zahnrad-Symbol** (Projekteinstellungen).
2. Gehe auf den Reiter **Dienstkonten** (Service accounts).
3. Klicke unten auf **Neuen privaten Schlüssel generieren** (Generate new private key).
4. Eine `.json`-Datei wird heruntergeladen.
5. Öffne diese `.json`-Datei mit einem Text-Editor, kopiere den **gesamten Inhalt** und füge ihn in GitHub unter `FIREBASE_SERVICE_ACCOUNT` ein (siehe Schritt 1.3).

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
