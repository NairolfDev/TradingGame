import 'asset.dart';

enum MarketRegion {
  crypto24_7,
  viennaEurope,
  usWallStreet,
  asiaTokyoHongKong;

  String get displayName {
    switch (this) {
      case MarketRegion.crypto24_7:
        return 'Krypto (24/7 Weltweit)';
      case MarketRegion.viennaEurope:
        return 'Europa / Wien & DAX (Mo-Fr 09:00 - 17:30)';
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
    MarketRegion.usWallStreet => 'Wall Street',
    MarketRegion.asiaTokyoHongKong => 'Tokio / Hongkong',
  };
}

class MarketSchedule {
  final MarketRegion region;

  const MarketSchedule(this.region);

  static MarketSchedule forAsset(Asset asset) {
    if (asset.type == AssetType.crypto) {
      return const MarketSchedule(MarketRegion.crypto24_7);
    }
    // Asien (Japan .T, China .HK, TSMC, etc.)
    if (asset.symbol.contains('.T') ||
        asset.symbol.contains('.HK') ||
        asset.symbol == 'TSM' ||
        asset.symbol == 'BABA' ||
        asset.symbol.contains('JGB')) {
      return const MarketSchedule(MarketRegion.asiaTokyoHongKong);
    }
    // Europa (Wien .VI, DAX .DE, EU ETFs, Bundesanleihen)
    if (asset.symbol.contains('.VI') ||
        asset.symbol.contains('.DE') ||
        asset.symbol.endsWith('.AS') ||
        asset.symbol == 'EUNL' ||
        asset.symbol == 'VUSA' ||
        asset.symbol == 'IS3N' ||
        asset.symbol == 'ATX.ETF' ||
        asset.symbol == 'EXS1' ||
        asset.symbol.startsWith('RAGB') ||
        asset.symbol.startsWith('BUND') ||
        asset.symbol.startsWith('SIEM') ||
        asset.symbol.contains('DAX-') ||
        asset.symbol.contains('ATX-')) {
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
        // 09:00 bis 17:30 MEZ
        const openMinutes = 9 * 60; // 540
        const closeMinutes = 17 * 60 + 30; // 1050
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;

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

  String getNextOpenTimeString([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    if (region == MarketRegion.crypto24_7) {
      return 'Immer geöffnet';
    }

    if (isMarketOpen(now)) {
      switch (region) {
        case MarketRegion.viennaEurope:
          return 'Schließt um 17:30 Uhr';
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
        if (isWeekend ||
            (now.weekday == DateTime.friday &&
                currentMinutes >= 17 * 60 + 30)) {
          return 'Öffnet Montag um 09:00 Uhr';
        }
        if (currentMinutes < 9 * 60) return 'Öffnet heute um 09:00 Uhr';
        return 'Öffnet morgen um 09:00 Uhr';

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
