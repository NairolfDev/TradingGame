import '../models/news_event.dart';

class InitialNews {
  static List<NewsEvent> getNews() {
    final now = DateTime.now();
    return [
      NewsEvent(
        id: 'news_1',
        headline: '🛢️ OPEC+ drosselt Rohöl-Förderung überraschend!',
        description: 'Die Allianz aus Saudi-Arabien und Partnern kürzt das tägliche Angebot um 1,5 Millionen Barrel. Analysten rechnen mit stark steigenden Energiekosten.',
        affectedSymbol: 'BRENT',
        priceImpact: 0.082,
        timestamp: now.subtract(const Duration(minutes: 5)),
        category: 'Rohstoffe',
      ),
      NewsEvent(
        id: 'news_2',
        headline: '🥇 Geopolitische Spannungen treiben Flucht in Gold!',
        description: 'Zentralbanken weltweit erhöhen ihre physischen Goldreserven massiv. Der Preis für eine Feinunze Gold klettert auf ein neues Allzeithoch.',
        affectedSymbol: 'XAU/EUR',
        priceImpact: 0.045,
        timestamp: now.subtract(const Duration(minutes: 18)),
        category: 'Edelmetalle',
      ),
      NewsEvent(
        id: 'news_3',
        headline: '⚡ Gerüchte um Zulassung eines neuen Solana-ETFs!',
        description: 'US-Behörden signalisieren überraschend grünes Licht für institutionelle Solana-Fonds. Krypto-Märkte schießen nach oben.',
        affectedSymbol: 'SOL',
        priceImpact: 0.125,
        timestamp: now.subtract(const Duration(minutes: 35)),
        category: 'Krypto 24/7',
      ),
      NewsEvent(
        id: 'news_4',
        headline: '🔋 Durchbruch bei Feststoffbatterien: Lithium-Nachfrage explodiert!',
        description: 'Ein führender Automobilkonzern stellt serienreife 1.200km-Akkus vor. Lithium-Futures verzeichnen den größten Preissprung des Quartals.',
        affectedSymbol: 'LITHIUM',
        priceImpact: 0.095,
        timestamp: now.subtract(const Duration(hours: 1)),
        category: 'Rohstoffe',
      ),
      NewsEvent(
        id: 'news_5',
        headline: '🏛️ OMV Wien meldet Rekord-Gewinne & Sonderdividende!',
        description: 'Der österreichische Energieriese übertrifft alle Analystenschätzungen bei weitem und kündigt eine Erhöhung der Ausschüttung auf 7,2 % an.',
        affectedSymbol: 'OMV.VI',
        priceImpact: 0.058,
        timestamp: now.subtract(const Duration(hours: 2)),
        category: 'ATX Wien',
      ),
      NewsEvent(
        id: 'news_6',
        headline: '💻 Chip-Exportbeschränkungen belasten Halbleiter-Sektor!',
        description: 'Neue geopolitische Handelsbeschränkungen für Hochleistungs-KI-Chips setzen Tech-Werte kurzfristig unter Verkaufsdruck.',
        affectedSymbol: 'NVDA',
        priceImpact: -0.065,
        timestamp: now.subtract(const Duration(hours: 3)),
        category: 'Tech / US',
      ),
      NewsEvent(
        id: 'news_7',
        headline: '🪙 Bitcoin Halving-Effekt setzt ein: Angebot verknappt!',
        description: 'Mining-Pools verzeichnen Rekord-Abflüsse in Cold-Storage. Börsen-Bestände sinken auf Mehrjahrestief.',
        affectedSymbol: 'BTC',
        priceImpact: 0.068,
        timestamp: now.subtract(const Duration(hours: 4)),
        category: 'Krypto 24/7',
      ),
    ];
  }
}
