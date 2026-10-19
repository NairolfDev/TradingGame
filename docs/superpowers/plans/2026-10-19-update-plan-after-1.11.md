# Update Plan nach 1.11.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offene Punkte nach dem Wechsel auf Firebase Free (kein Backend) abschließen und das Spiel an den spürbarsten Stellen verbessern.

**Architecture:** Alles bleibt im Client plus Firestore-Regeln. Marktdaten kommen direkt von Binance/CoinGecko/Yahoo, im Browser über ein CORS-Relay. Schutz der Datenbank läuft über Regeln (Versions-Gate, Build-Stempel, Prüfsumme).

**Tech Stack:** Flutter 3.41, Provider, Firestore (Spark), Firebase Hosting, GitHub Actions, optional Cloudflare Worker (Free).

**Spec:** Chat vom 2026-10-19 (Free-Tier-Umstellung, Versions-Gate, USD, Marktdaten, Ranglisten-Bereinigung). Kein separates Design-Dokument.

## Global Constraints

- Firebase Spark: keine Cloud Functions, kein Cloud Run, Firestore ≤ 50 000 Reads und 20 000 Writes pro Tag.
- Farben nur über `AppColors`; Gold nur für Rang/Prestige/Belohnung (`test/gold_usage_test.dart`); Mindestschrift 12.
- Kontrast ≥ 4,5:1 (`test/palette_contrast_test.dart`).
- Nach jedem Task: `flutter analyze` ohne Meldung und `flutter test` grün.
- Release nur über Pipeline: Feature-Branch → `dev` → `main`; danach `tools/set_min_build.sh <build>`.

## Review Focus

- Kein Kurs (Yahoo kennt das Symbol nicht, Relay-Limit erreicht): Kauf bleibt gesperrt, aber mit Grund im Text statt nur „Kein Kurs“.
- Spieler mit altem App-Stand (Build < `minBuild`): sieht Update-Dialog, Schreibzugriffe schlagen leise fehl.
- Anzeige-Währung USD ohne EUR/USD-Kurs (Browser, offline): Anzeige bleibt EUR statt falscher Zahlen.
- Gäste und unbenannte Konten: nie auf der Rangliste, auch nicht aus alten Dokumenten.
- Vorab-Order, deren Börse öffnet, während die App zu ist: wird beim nächsten Start zur normalen Order, nicht sofort gefüllt.

---

### Task 1: Rollout abschließen (Regeln und Mindestversion)

**Files:**
- Modify: `firestore.rules` (bereits im Repo), Firestore-Dokument `config/app`
- Doc: `docs/version-gate.md`

**Interfaces:**
- Produces: Regeln mit `currentBuild()`, Dokument `config/app.minBuild = 16`.

- [ ] **Step 1:** Regeln deployen: `firebase deploy --only firestore:rules --project tradinggame-austria-prod` (Erwartung: „Deploy complete“).
- [ ] **Step 2:** Erst wenn 1.11.0 im Play-Test ankommt: `tools/set_min_build.sh 16 1.11.0`.
- [ ] **Step 3:** Prüfen: App mit Build 15 zeigt den Update-Dialog; App mit Build 16 spielt normal und `sessions/{uid}.build == 16` existiert.
- [ ] **Step 4:** Alte Rangliste bereinigen: Dokumente in `leaderboard` ohne `verified: true` in der Firebase Console löschen (die App blendet sie bereits aus).

### Task 2: Anzeige-Währung EUR/USD

**Files:**
- Create: `lib/logic/currency_controller.dart`, `test/currency_controller_test.dart`
- Modify: `lib/core/utils/currency_formatter.dart`, `lib/ui/screens/settings_screen.dart`, `lib/main.dart`

**Interfaces:**
- Produces: `class CurrencyController extends ChangeNotifier { DisplayCurrency get currency; double get eurToUsd; Future<void> setCurrency(DisplayCurrency c); Future<void> refreshRate(); }` und `CurrencyFormatter.format(num eur)` rechnet bei USD um.

- [ ] **Step 1:** Test: `format(100)` ergibt „100,00 €“ bei EUR und „$ 108,00“ bei Kurs 1,08; ohne Kurs bleibt die Anzeige EUR.
- [ ] **Step 2:** Controller mit Kurs aus `EURUSD=X` (Cache 5 Min., vorhandene `_fxMeta`-Logik wiederverwenden), Auswahl in SharedPreferences.
- [ ] **Step 3:** Schalter „Währung“ in den Einstellungen; Handelslogik rechnet weiter in EUR (nur Anzeige und Eingabefelder wandeln um).
- [ ] **Step 4:** `flutter test`, Commit.

### Task 3: Prüfsumme für Schreibzugriffe

**Files:**
- Modify: `lib/logic/version_gate.dart` (`SessionStamp`), `firestore.rules`
- Test: `test/version_gate_test.dart`

**Interfaces:**
- Consumes: `sessions/{uid}` aus dem Versions-Gate.
- Produces: `sessions/{uid}.sig` = SHA-256 aus `uid:build:salt`, Regel prüft `hashing.sha256`.

- [ ] **Step 1:** Test: gleiche Eingabe ergibt gleiche Summe, andere UID eine andere.
- [ ] **Step 2:** `SessionStamp.write` schreibt `sig`; Regel `create, update` verlangt passende Summe.
- [ ] **Step 3:** Ehrlich dokumentieren: der Salt steckt in der App, die Prüfsumme hält nur veraltete und handgebaute Anfragen ab (`docs/version-gate.md`).

### Task 4: Aktienkurse im Browser ohne Drittanbieter-Relay

**Files:**
- Create: `tools/quote_worker.js` (Cloudflare Worker, leitet `?url=` an Yahoo weiter, Cache 15 s, nur `query1.finance.yahoo.com`)
- Modify: `.github/workflows/ci_cd.yml` (`--dart-define=QUOTE_PROXY=...`), `docs/`

**Interfaces:**
- Consumes: `LiveMarketDataService._quoteProxy` (besteht bereits).

- [ ] **Step 1:** Worker mit Host-Whitelist schreiben und lokal prüfen (`curl` liefert JSON mit `access-control-allow-origin`).
- [ ] **Step 2:** Du legst das kostenlose Cloudflare-Konto an und deployst den Worker; die URL kommt als Repo-Variable `QUOTE_PROXY`.
- [ ] **Step 3:** Web-Build mit Define bauen und im Browser prüfen: Aktie hat Kurs, kein Aufruf von `r.jina.ai` mehr.

### Task 5: „Kein Kurs“ erklären statt nur anzeigen

**Files:**
- Modify: `lib/ui/screens/trade_detail_screen.dart`, `lib/ui/widgets/asset_card.dart`, `lib/ui/widgets/watchlist_marquee_ticker.dart`
- Test: `test/no_quote_reason_test.dart`

- [ ] **Step 1:** Test: ohne Kurs zeigt die Handelsseite „Kurs wird geladen“ solange ein Abruf läuft, danach „Für dieses Instrument liefert der Anbieter keinen Kurs“.
- [ ] **Step 2:** Zustand je Asset (`loading`, `unavailable`) im Provider; Kauf-Button zeigt den Grund.
- [ ] **Step 3:** Ticker blendet Einträge ohne Kurs aus, solange andere Kurse da sind.

### Task 6: Dashboard-Feinschliff

**Files:**
- Modify: `lib/ui/screens/simplistic_dashboard_screen.dart`, `lib/ui/widgets/net_worth_chart.dart`
- Test: `test/net_worth_history_test.dart`

- [ ] **Step 1:** Vermögensverlauf und Aufteilung auch im schlichten Dashboard.
- [ ] **Step 2:** Verlauf zusätzlich in Firestore sichern (ein Dokument pro Tag, höchstens ein Schreibzugriff pro Tag), damit er Gerätewechsel überlebt.

## Weitere Vorschläge (noch nicht eingeplant)

- Push bei geschlossener App ohne Server: nur über Wochen-Erinnerungen lokal (Android) möglich; Alarm-Genauigkeit bleibt „solange die App läuft“.
- Ranglisten-Zeiträume (Tag, Woche) über tägliche Verlaufspunkte aus Task 6.
- Order-Verlauf als eigener Tab mit Filter (Vorab, Normal, Ausgeführt, Storniert).
- Hebel-Positionen: Liquidationswarnung ab 10 % Abstand.
- Onboarding in drei Karten statt langem Text.
- Spieler-Profil mit Statistik (Trefferquote, bester Trade).
