import 'dart:async';
import 'dart:math';
import '../data/models/asset.dart';
import '../data/models/news_event.dart';
import '../data/models/market_schedule.dart';

typedef OnPriceUpdate = void Function(List<Asset> updatedAssets);
typedef OnNewsGenerated = void Function(NewsEvent news);
typedef OnMarketOpenNotification = void Function(String message);

class MarketEngine {
  final Random _random = Random();
  Timer? _tickTimer;
  Timer? _newsTimer;
  bool _isRunning = false;

  List<Asset> _assets = [];
  OnPriceUpdate? onPriceUpdate;
  OnNewsGenerated? onNewsGenerated;

  bool get isRunning => _isRunning;

  void start({
    required List<Asset> initialAssets,
    required OnPriceUpdate priceCallback,
    required OnNewsGenerated newsCallback,
  }) {
    _assets = initialAssets;
    onPriceUpdate = priceCallback;
    onNewsGenerated = newsCallback;

    _isRunning = true;
    _tickTimer?.cancel();
    _newsTimer?.cancel();

    // Alle 2.5 Sekunden ein Markt-Tick
    _tickTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _executeMarketTick();
    });

    // Alle 45-90 Sekunden eine Eilmeldung
    _scheduleNextNews();
  }

  void stop() {
    _tickTimer?.cancel();
    _newsTimer?.cancel();
    _isRunning = false;
  }

  void _scheduleNextNews() {
    final delaySeconds = 35 + _random.nextInt(45);
    _newsTimer?.cancel();
    _newsTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isRunning) return;
      _generateRandomNews();
      _scheduleNextNews();
    });
  }

  void _executeMarketTick() {
    final now = DateTime.now();
    bool anyChanged = false;

    final updated = _assets.map((asset) {
      final schedule = MarketSchedule.forAsset(asset);
      final isOpen = schedule.isMarketOpen(now);

      // Wenn die Börse geschlossen ist, bewegt sich der Kurs im Haupthandel nicht
      if (!isOpen) {
        return asset;
      }

      anyChanged = true;
      // Realistische stochastische Kursbewegung (Geometric Random Walk)
      final vol = asset.volatility;
      // Ausbalancierte Volatilität: Keine plötzlichen Zufalls-Liquidations innerhalb von Sekunden
      final rawFactor = (_random.nextDouble() - 0.495) * 2;
      final percentChange = rawFactor * vol * 0.08;
      final newPrice = (asset.currentPrice * (1 + percentChange))
          .clamp(0.0001, 1000000.0);

      // Runden je nach Preisklasse
      final roundedPrice = newPrice > 500
          ? double.parse(newPrice.toStringAsFixed(2))
          : (newPrice > 1
              ? double.parse(newPrice.toStringAsFixed(2))
              : double.parse(newPrice.toStringAsFixed(4)));

      return asset.copyWithPrice(roundedPrice);
    }).toList();

    _assets = updated;
    if (anyChanged && onPriceUpdate != null) {
      onPriceUpdate!(_assets);
    }
  }

  void _generateRandomNews() {
    final newsPool = [
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '🚀 Bitcoin durchbricht Widerstand nach ETF-Milliardenzuflüssen!',
        description: 'Institutionelle Investoren treiben den Krypto-Markt weiter an. Hohe Volatilität erwartet.',
        affectedType: AssetType.crypto,
        priceImpact: 0.035,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '📈 KI-Superzyklus: Halbleiter-Riesen melden Rekordnachfrage!',
        description: 'Rechenzentren weltweit rüsten massiv auf. Nvidia und Tech-Aktien profitieren.',
        affectedSymbol: 'NVDA',
        priceImpact: 0.028,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '🏛️ Wiener Börse: ATX legt kräftig zu – Bankentitel stark gesucht!',
        description: 'Erste Group Bank und OMV übertreffen Analystenerwartungen in Wien.',
        affectedType: AssetType.stock,
        priceImpact: 0.019,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '⚠️ US-Notenbank Fed deutet Zinsanpassung an!',
        description: 'Kurzfristige Verunsicherung an den weltweiten Anleihe- und CFD-Märkten.',
        affectedType: AssetType.cfd,
        priceImpact: -0.018,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '🔋 Tesla überrascht mit neuem Durchbruch bei Robotaxi-Software!',
        description: 'Analysten heben Kursziele an, massiver Short-Squeeze an der Wall Street.',
        affectedSymbol: 'TSLA',
        priceImpact: 0.038,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '💶 EZB hält Zinsen stabil: Europäische Staatsanleihen florieren!',
        description: 'Republik Österreich Bundesanleihen und Bundesanleihen bieten verlässliche Renditen.',
        affectedType: AssetType.bond,
        priceImpact: 0.006,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '⚡ SAP übertrifft Cloud-Prognosen: Deutscher Leitindex DAX im Aufwind!',
        description: 'Europas größter Softwarekonzern zieht den gesamten deutschen Tech-Sektor mit.',
        affectedSymbol: 'SAP.DE',
        priceImpact: 0.032,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '🏮 Asien-Börsen im Rally-Modus: Alibaba und TSMC treiben Hang Seng!',
        description: 'Chinesische Konjunkturprogramme stärken das Vertrauen internationaler Großanleger.',
        affectedSymbol: 'BABA',
        priceImpact: 0.042,
      ),
      NewsEvent(
        id: 'news_${DateTime.now().millisecondsSinceEpoch}',
        headline: '🥇 Gold klettert auf neues Allzeithoch: Anleger flüchten in sicheren Hafen!',
        description: 'Geopolitische Spannungen treiben den Gold-CFD-Kurs nach oben.',
        affectedSymbol: 'CFD-GOLD',
        priceImpact: 0.025,
      ),
    ];

    final event = newsPool[_random.nextInt(newsPool.length)];

    // Wende den Impact sofort auf die Assets an
    final updated = _assets.map((asset) {
      bool affects = false;
      if (event.affectedSymbol != null && asset.symbol == event.affectedSymbol) {
        affects = true;
      } else if (event.affectedType != null && asset.type == event.affectedType) {
        affects = true;
      }

      if (affects) {
        final newPrice = (asset.currentPrice * (1 + event.priceImpact))
            .clamp(0.0001, 1000000.0);
        return asset.copyWithPrice(double.parse(newPrice.toStringAsFixed(2)));
      }
      return asset;
    }).toList();

    _assets = updated;
    if (onPriceUpdate != null) {
      onPriceUpdate!(_assets);
    }
    if (onNewsGenerated != null) {
      onNewsGenerated!(event);
    }
  }

  void updateAssetsReference(List<Asset> assets) {
    _assets = assets;
  }
}
