import '../models/copy_trader.dart';

class InitialCopyTraders {
  static List<CopyTrader> getTraders() {
    return const [
      CopyTrader(
        id: 'trader_rothschild',
        name: 'Maximilian Rothschild',
        title: 'Finanz-Oligarch & Stiftungsgründer',
        avatarEmoji: '👑',
        netWorth: 4850000.0,
        roiPercent: 184.5,
        winRatePercent: 78.2,
        bio: 'Fokus auf Werterhalt, physisches Gold, Schweizer Staatsanleihen und krisenfeste Dividenden-Könige. Maximale Stabilität.',
        riskStyle: 'Konservativ & Solide',
        portfolioAllocation: {
          'XAU/EUR': 0.40, // 40% Gold
          'CONFED10Y': 0.25, // 25% Schweizer Anleihen
          'OMV.VI': 0.20, // 20% OMV Dividende
          'EBS.VI': 0.15, // 15% Erste Group
        },
        followersCount: 1420,
      ),
      CopyTrader(
        id: 'trader_sophia',
        name: 'Sophia von Wall Street',
        title: 'Hedgefonds-Direktorin',
        avatarEmoji: '💎',
        netWorth: 1820000.0,
        roiPercent: 245.8,
        winRatePercent: 69.4,
        bio: 'Aggressives Momentum-Trading in Big-Tech, KI-Infrastruktur und 10x gehebelten CFDs. Hohe Renditen durch striktes Risikomanagement.',
        riskStyle: 'Aggressiv / Momentum',
        portfolioAllocation: {
          'NVDA': 0.35, // 35% Nvidia
          'AAPL': 0.25, // 25% Apple
          'BRENT': 0.20, // 20% Rohöl
          'BTC': 0.20, // 20% Bitcoin
        },
        followersCount: 3890,
      ),
      CopyTrader(
        id: 'trader_lukas',
        name: 'Lukas (Krypto-Whale)',
        title: '24/7 On-Chain Market Maker',
        avatarEmoji: '⚡',
        netWorth: 940000.0,
        roiPercent: 412.0,
        winRatePercent: 61.5,
        bio: 'Schläft nie. Handelt 24/7 Bitcoin, Ethereum und Solana-Rallyes. Reitet jeden Zyklus mit vollem Risiko.',
        riskStyle: 'Hochrisiko / Krypto-Whale',
        portfolioAllocation: {
          'BTC': 0.50, // 50% Bitcoin
          'ETH': 0.30, // 30% Ethereum
          'SOL': 0.20, // 20% Solana
        },
        followersCount: 5210,
      ),
      CopyTrader(
        id: 'trader_elena',
        name: 'Elena Rostova',
        title: 'Rohstoff-Spekulantin & Makro-Expertin',
        avatarEmoji: '🌍',
        netWorth: 1250000.0,
        roiPercent: 168.3,
        winRatePercent: 72.8,
        bio: 'Handelt globale Energie-Trends, Uran, Lithium und Agrarrohstoffe wie Kaffee Arabica. Profitiert von Versorgungsengpässen.',
        riskStyle: 'Ausgewogen / Rohstoffe',
        portfolioAllocation: {
          'BRENT': 0.30, // 30% Rohöl
          'COPPER': 0.25, // 25% Kupfer
          'URANIUM': 0.25, // 25% Uran
          'COFFEE': 0.20, // 20% Kaffee
        },
        followersCount: 2150,
      ),
    ];
  }
}
