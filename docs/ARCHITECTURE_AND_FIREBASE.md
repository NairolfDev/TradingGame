# Trading Game – Architektur & Firebase Backend Roadmap

## 1. Vision & Spielkonzept
Ein plattformübergreifendes Flutter-Trading-Spiel mit persistentem Endlos-Modus (kein Reset), Startguthaben von 50.000 €, weltweitem Leaderboard und starker Gamification ("cooler werden", Prestige-System, Statussymbole, Ränge).

---

## 2. Asset-Klassen & Trading-Mechanik
Das Spiel unterstützt den Handel verschiedener Anlageklassen:
- **Aktien (Stocks)**: Global & DAX/ATX/US (Apple, Tesla, Microsoft, OMV, Erste Group, etc.)
- **Kryptowährungen (Crypto)**: BTC, ETH, SOL, XRP, etc. mit hoher Volatilität
- **ETFs / Fonds**: MSCI World, S&P 500, Emerging Markets (solide Langzeit-Rendite)
- **CFDs / Hebelprodukte / Derivate**: Long/Short mit Hebel (z. B. 2x, 5x, 10x, 50x) inkl. Margin-Call / Liquidations-Risiko
- **Anleihen (Bonds)**: Staats- und Unternehmensanleihen mit laufenden Zinskupons

---

## 3. "Cooler werden" & Gamification-System
- **Vermögen & Ränge**: 
  - Stufen: z. B. Praktikant -> Junior Trader -> Senior Broker -> Fondsmanager -> Hedgefonds-Legende -> Börsen-Tycoon
- **Prestige & Statussymbole**:
  - Kauf von Luxusgegenständen (Uhren, Sportwagen, Penthouses, Yachten, Inseln) vom erwirtschafteten Gewinn, die das Profil im Leaderboard schmücken
- **Trading Perks & Upgrades**:
  - Terminal-Upgrades (Echtzeit-Orderbuch, Chart-Indikatoren wie RSI/MACD, Research-Reports)
  - Reduzierte Ordergebühren (Kommissionen)
- **Events & News-Ticker**:
  - Dynamische Marktnachrichten (Zinsentscheide, Quartalszahlen, Krypto-Hypes), die Kurse beeinflussen

---

## 4. Leaderboard-System (Inspiriert vom österr. Börsenspiel)
- **Modus**: Persistent / Endless – läuft ununterbrochen durch, kein saisonaler Wipe
- **Metriken**:
  - Gesamtdepotwert (Net Worth = Cash + Depotwert + Luxusgüter-Wert)
  - Absolute Rendite (€ Gewinn seit Start)
  - Prozentuale Rendite (% ROI)
  - Wochen- / Monats-Highscores (optional neben dem Allzeit-Ranking)

---

## 5. Zukünftige Firebase Backend-Architektur (JavaScript / TypeScript)

### Geplante Services:
1. **Firebase Authentication**:
   - E-Mail/Passwort, Google Sign-In, Anonymes Gast-Konto mit Upgrade-Möglichkeit.
2. **Cloud Firestore**:
   - `users/{uid}`: Profil, Level, Titel, freigeschaltete Statussymbole, Einstellungen.
   - `portfolios/{uid}`: Cash-Guthaben (initial 50.000 €), Positionen, durchschnittlicher Einstandskurs.
   - `orders/{orderId}`: Historie aller Kauf-/Verkaufsorders.
   - `market_prices/{symbol}`: Aktuelle Kurse, Kerzen-Charts (OHLCV), 24h-Änderung.
   - `leaderboard`: Denormalisierte Rangliste für ultraschnelle Abfragen & Pagination.
3. **Kein Backend (seit 1.9.0, Free Tier)**: Orders, Kredite, Kursalarme und Rangliste laufen im Client und
   schreiben direkt in Firestore. Die Security Rules begrenzen nur, *wer* schreiben darf (Besitzer), nicht
   *was* (Guthaben ist client-seitig änderbar; für ein Spiel ohne Echtgeld akzeptiert).

---

## 6. Lokale Zwischenarchitektur (Repository Pattern)
Um offline und unabhängig von Firebase sofort loszulegen:
- `TradingRepository` Interface mit lokaler Implementierung (`LocalTradingRepository` mit `shared_preferences` / `Hive` / `In-Memory`)
- Sobald das Firebase-Backend live geht, wird nur die `FirebaseTradingRepository`-Implementierung eingeklinkt – die gesamte Flutter-UI bleibt 100% unverändert.
