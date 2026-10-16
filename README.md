# 📈 Trading Game – Österreich Börsenspiel

Ein realistisches, persistentes und plattformübergreifendes Finanz- und Börsenspiel entwickelt mit Flutter. 

Tritt mit **50.000 € Startkapital** an, trade an weltweiten Märkten, meistere Hebelprodukte, sammle Reichtum an und steige im ewigen **Endlos-Leaderboard** an die Spitze auf, während du dir Luxusgüter wie Rolex-Uhren, Sportwagen, Wiener Penthouses und Superyachten gönnst, um im **Prestige-System** cooler zu werden!

---

## 🌟 Hauptfeatures

### 1. 🌍 Vollständiger Multi-Asset-Handel
- **Aktien**: Apple, Nvidia, Tesla, Erste Group Bank, OMV Wien, Rheinmetall.
- **Kryptowährungen (24/7)**: Bitcoin, Ethereum, Solana, Dogecoin.
- **ETFs**: iShares Core MSCI World, Vanguard S&P 500, ATX Prime ETF.
- **CFDs & Hebelprodukte**: Bis zu **50x Hebel** Long & Short mit Live-Berechnung des Liquidationspreises und Margin-Calls.
- **Anleihen (Bonds)**: Republik Österreich 10J Bundesanleihe, US-Treasuries und Siemens Green Bonds mit laufender **Zinskupon-Ausschüttung**.

### 2. ⏰ Echte Börsenöffnungszeiten & Vorab-Kaufoptionen (Pre-Market Orders)
- **Wiener Börse / Europa**: Montag – Freitag von **09:00 bis 17:30 Uhr MEZ**.
- **US Wall Street**: Montag – Freitag von **15:30 bis 22:00 Uhr MEZ**.
- **Kryptomärkte**: **24/7 rund um die Uhr** geöffnet.
- **Vorab-Orders**: Bei geschlossener Börse kannst du Kauforders im Voraus platzieren. Das Geld wird reserviert und die Order wird **automatisch bei Marktöffnung zum Eröffnungskurs ausgeführt**!
- **Simulator-Umschalter**: Ein Test-Modus ermöglicht auf Wunsch 24/7-Simulation zu jeder Uhrzeit.

### 3. 💎 "Cooler werden" – Status-Shop & Prestige-Karriere
- **7 Trader-Ränge**: 
  1. ☕ *Börsen-Praktikant* (< 50.000 €)
  2. 📈 *Junior Retail Trader* (50.000 €)
  3. 💼 *Floor Broker* (80.000 €)
  4. 🏆 *Senior Portfolio Manager* (200.000 €)
  5. 👑 *Hedgefonds-Direktor* (500.000 €)
  6. 💎 *Wall Street Legende* (1.500.000 €)
  7. 🔱 *Finanz-Oligarch* (5.000.000 €+)
- **Prestige-Shop**: Kaufe Luxusgüter von deinen Börsengewinnen:
  - ⌚ **Uhren**: Rolex Submariner, Audemars Piguet, Patek Philippe, Richard Mille.
  - 🏎️ **Sportwagen**: Porsche 911 GT3 RS, Ferrari SF90, Bugatti Chiron.
  - 🏛️ **Immobilien**: Dachterrassen-Penthouse Wien 1. Bezirk, Wörthersee-Villa, Central Park Penthouse.
  - 🛥️ **Exklusiv**: Gulfstream G650ER Privatjet, 95m Superyacht "The Bull of Wall Street".

### 4. 🏆 Ewiges Leaderboard (Börsenspiel Österreich)
- Läuft ununterbrochen durch – **kein saisonaler Reset**!
- Konkurriere gegen Top-Trader und simulierte Kontrahenten aus Wien, Graz, Salzburg und ganz Österreich.
- Podium-Ansicht (Gold, Silber, Bronze) mit Net-Worth, ROI-% und Statussymbolen.

### 5. 📱 Plattformübergreifend (Windows, macOS, Linux, Web, Android, iOS)
- Responsive Layout mit Desktop-Sidebar (Navigation Rail) für Widescreens und moderner Bottom Navigation für Mobilgeräte.
- Dark Financial Terminal Design (TradingView / Bloomberg Style).

---

## 🛠️ Zukünftige Firebase Backend-Integration (JavaScript / Node.js)
Die Architektur ist modular über das `TradingRepository`-Pattern entkoppelt:
- Aktuell: `LocalTradingRepository` speichert alle Daten lokal & offline (SharedPreferences).
- Zukünftig: `FirebaseTradingRepository` mit Cloud Firestore, Firebase Authentication und Cloud Functions in JavaScript für server-seitige Order-Validierung und globales Multiplayer-Leaderboard.
- Details siehe: [`docs/ARCHITECTURE_AND_FIREBASE.md`](file:///c:/Users/oberh/WenziComp/TradingGame/docs/ARCHITECTURE_AND_FIREBASE.md).

---

## 🚀 App starten

### Voraussetzungen
- Flutter SDK (>= 3.41.0)
- Dart SDK (>= 3.11.0)

### Starten auf verschiedenen Plattformen
```bash
# Auf Windows Desktop starten
flutter run -d windows

# Im Chrome Web-Browser starten
flutter run -d chrome

# Auf Android / iOS Emulator oder Gerät starten
flutter run
```

### Tests & Analyse
```bash
flutter test
flutter analyze
```
