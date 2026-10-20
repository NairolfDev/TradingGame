import 'asset.dart';

enum MarketRegion {
  crypto24_7,
  viennaEurope,
  londonLse,
  futures24x5,
  usWallStreet,
  asiaTokyoHongKong;

  String get displayName {
    switch (this) {
      case MarketRegion.crypto24_7:
        return 'Krypto (24/7 Weltweit)';
      case MarketRegion.viennaEurope:
        return 'Europa / Wien & DAX (Mo-Fr 09:00 - 17:30)';
      case MarketRegion.londonLse:
        return 'London Stock Exchange (Mo-Fr 09:00 - 17:30 MEZ)';
      case MarketRegion.futures24x5:
        return 'Rohstoffe & CFDs (Mo 00:00 - Fr 22:00, rund um die Uhr)';
      case MarketRegion.usWallStreet:
        return 'US / Wall Street (Mo-Fr 15:30 - 22:00)';
      case MarketRegion.asiaTokyoHongKong:
        return 'Asien / Tokio & Hongkong (Mo-Fr 02:00 - 08:30)';
    }
  }
}

extension MarketRegionShortName on MarketRegion {
  String get shortName => switch (this) {
    MarketRegion.crypto24_7 => 'Krypto',
    MarketRegion.viennaEurope => 'Wiener Börse / Xetra',
    MarketRegion.londonLse => 'London Stock Exchange',
    MarketRegion.futures24x5 => 'Rohstoffe / CFDs',
    MarketRegion.usWallStreet => 'Wall Street',
    MarketRegion.asiaTokyoHongKong => 'Tokio / Hongkong',
  };
}

class MarketSchedule {
  final MarketRegion region;

  const MarketSchedule(this.region);

  static MarketSchedule forAsset(Asset asset) =>
      forSymbol(asset.symbol, asset.type);

  /// Same rules as [forAsset] for callers that only have symbol and type,
  /// e.g. a pending order.
  static MarketSchedule forSymbol(String symbol, AssetType type) {
    if (type == AssetType.crypto) {
      return const MarketSchedule(MarketRegion.crypto24_7);
    }
    // Asien (Japan .T, China .HK, TSMC, etc.)
    if (symbol.contains('.T') ||
        symbol.contains('.HK') ||
        symbol == 'TSM' ||
        symbol == 'BABA' ||
        symbol.contains('JGB')) {
      return const MarketSchedule(MarketRegion.asiaTokyoHongKong);
    }
    // Rohstoff-Futures und CFDs laufen fast rund um die Uhr (Mo-Fr);
    // CFDs auf Krypto sogar 24/7.
    if (type == AssetType.cfd) {
      const crypto = ['BTC-', 'ETH-', 'SOL-', 'XRP-'];
      return crypto.any(symbol.startsWith)
          ? const MarketSchedule(MarketRegion.crypto24_7)
          : const MarketSchedule(MarketRegion.futures24x5);
    }
    if (type == AssetType.commodity) {
      return const MarketSchedule(MarketRegion.futures24x5);
    }
    // London (LSE, FTSE 100)
    if (symbol.endsWith('.L') || symbol.startsWith('FTSE')) {
      return const MarketSchedule(MarketRegion.londonLse);
    }
    // Europa (Wien .VI, DAX .DE, EU ETFs, Bundesanleihen)
    if (symbol.contains('.VI') ||
        symbol.contains('.DE') ||
        symbol.endsWith('.AS') ||
        symbol == 'EUNL' ||
        symbol == 'VUSA' ||
        symbol == 'IS3N' ||
        symbol == 'ATX.ETF' ||
        symbol == 'EXS1' ||
        symbol.startsWith('RAGB') ||
        symbol.startsWith('BUND') ||
        symbol.startsWith('SIEM') ||
        symbol.contains('DAX-') ||
        symbol.contains('ATX-')) {
      return const MarketSchedule(MarketRegion.viennaEurope);
    }
    // US Wall Street (NYSE, NASDAQ, S&P 500)
    return const MarketSchedule(MarketRegion.usWallStreet);
  }

  /// Handelszeiten in Minuten seit Mitternacht (wie in [isMarketOpen]);
  /// null für Krypto, das nie schließt.
  ({int open, int close})? get tradingMinutes => switch (region) {
    MarketRegion.crypto24_7 => null,
    MarketRegion.viennaEurope => (open: 9 * 60, close: 17 * 60 + 30),
    // 08:00-16:30 Londoner Zeit = 09:00-17:30 MEZ (London ist immer 1 h zurück)
    MarketRegion.londonLse => (open: 9 * 60, close: 17 * 60 + 30),
    MarketRegion.futures24x5 => (open: 0, close: 22 * 60),
    MarketRegion.usWallStreet => (open: 15 * 60 + 30, close: 22 * 60),
    MarketRegion.asiaTokyoHongKong => (open: 2 * 60, close: 8 * 60 + 30),
  };

  /// Prüft, ob der Markt zum angegebenen Zeitpunkt geöffnet ist
  bool isMarketOpen([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();

    if (region == MarketRegion.crypto24_7) {
      return true; // Krypto schläft nie
    }

    // Wochenende geschlossen (Samstag = 6, Sonntag = 7)
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    final currentMinutes = now.hour * 60 + now.minute;

    switch (region) {
      case MarketRegion.crypto24_7:
        return true;

      case MarketRegion.viennaEurope:
      case MarketRegion.londonLse:
        // 09:00 bis 17:30 MEZ
        const openMinutes = 9 * 60; // 540
        const closeMinutes = 17 * 60 + 30; // 1050
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;

      case MarketRegion.futures24x5:
        // Mo-Do ganztägig, Fr bis 22:00 MEZ
        return now.weekday != DateTime.friday || currentMinutes < 22 * 60;

      case MarketRegion.usWallStreet:
        // 15:30 bis 22:00 MEZ
        const openMinutes = 15 * 60 + 30; // 930
        const closeMinutes = 22 * 60; // 1320
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;

      case MarketRegion.asiaTokyoHongKong:
        // 02:00 bis 08:30 MEZ
        const openMinutes = 2 * 60; // 120
        const closeMinutes = 8 * 60 + 30; // 510
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    }
  }

  /// e.g. "Wall Street · Öffnet Montag um 15:30 Uhr"
  String nextOpeningLine([DateTime? dateTime]) =>
      '${region.shortName} · ${getNextOpenTimeString(dateTime)}';

  String getNextOpenTimeString([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    if (region == MarketRegion.crypto24_7) {
      return 'Immer geöffnet';
    }

    if (isMarketOpen(now)) {
      switch (region) {
        case MarketRegion.viennaEurope:
        case MarketRegion.londonLse:
          return 'Schließt um 17:30 Uhr';
        case MarketRegion.futures24x5:
          return now.weekday == DateTime.friday
              ? 'Schließt um 22:00 Uhr'
              : 'Handel rund um die Uhr';
        case MarketRegion.usWallStreet:
          return 'Schließt um 22:00 Uhr';
        case MarketRegion.asiaTokyoHongKong:
          return 'Schließt um 08:30 Uhr';
        default:
          return 'Geöffnet';
      }
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    switch (region) {
      case MarketRegion.viennaEurope:
      case MarketRegion.londonLse:
        if (isWeekend ||
            (now.weekday == DateTime.friday &&
                currentMinutes >= 17 * 60 + 30)) {
          return 'Öffnet Montag um 09:00 Uhr';
        }
        if (currentMinutes < 9 * 60) return 'Öffnet heute um 09:00 Uhr';
        return 'Öffnet morgen um 09:00 Uhr';

      case MarketRegion.futures24x5:
        return 'Öffnet Montag um 00:00 Uhr';

      case MarketRegion.usWallStreet:
        if (isWeekend ||
            (now.weekday == DateTime.friday && currentMinutes >= 22 * 60)) {
          return 'Öffnet Montag um 15:30 Uhr';
        }
        if (currentMinutes < 15 * 60 + 30) return 'Öffnet heute um 15:30 Uhr';
        return 'Öffnet morgen um 15:30 Uhr';

      case MarketRegion.asiaTokyoHongKong:
        if (isWeekend ||
            (now.weekday == DateTime.friday && currentMinutes >= 8 * 60 + 30)) {
          return 'Öffnet Montag um 02:00 Uhr';
        }
        if (currentMinutes < 2 * 60) return 'Öffnet heute um 02:00 Uhr';
        return 'Öffnet morgen um 02:00 Uhr';

      default:
        return 'Geschlossen';
    }
  }
}
