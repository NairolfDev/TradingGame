import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/models/asset.dart';
import '../data/models/market_schedule.dart';

class LiveQuoteResult {
  final double currentPrice;
  final double previousClose;
  final double? high;
  final double? low;
  final List<double>? series;

  const LiveQuoteResult({
    required this.currentPrice,
    required this.previousClose,
    this.high,
    this.low,
    this.series,
  });
}

class LiveMarketDataService {
  static final LiveMarketDataService _instance = LiveMarketDataService._internal();
  factory LiveMarketDataService() => _instance;
  LiveMarketDataService._internal();

  final Map<String, LiveQuoteResult> _quoteCache = {};
  final Map<String, Map<String, List<double>>> _historicalSeriesCache = {};

  /// Holt aktuelle Kursdaten für ein Asset (via Yahoo Finance oder CoinGecko)
  Future<LiveQuoteResult?> fetchLiveQuote(Asset asset) async {
    try {
      if (asset.type == AssetType.crypto) {
        return await _fetchCryptoQuote(asset);
      } else if (asset.yahooSymbol != null && asset.yahooSymbol!.isNotEmpty) {
        return await _fetchYahooQuote(asset.yahooSymbol!);
      }
    } catch (e) {
      debugPrint('LiveMarketDataService: Fehler bei Quote für ${asset.symbol}: $e');
    }
    return _quoteCache[asset.symbol];
  }

  /// Holt historische Zeitreihen für die verschiedenen Timeframes (1D, 1W, 1M, 1Y, 3Y, ALL)
  Future<List<double>?> fetchHistoricalSeries(Asset asset, String timeframe) async {
    final assetKey = asset.symbol;
    if (_historicalSeriesCache.containsKey(assetKey) &&
        _historicalSeriesCache[assetKey]!.containsKey(timeframe)) {
      return _historicalSeriesCache[assetKey]![timeframe];
    }

    try {
      if (asset.yahooSymbol != null && asset.yahooSymbol!.isNotEmpty) {
        final series = await _fetchYahooHistory(asset.yahooSymbol!, timeframe);
        if (series != null && series.isNotEmpty) {
          _historicalSeriesCache.putIfAbsent(assetKey, () => {})[timeframe] = series;
          return series;
        }
      }
    } catch (e) {
      debugPrint('LiveMarketDataService: Fehler bei Historie für ${asset.symbol} ($timeframe): $e');
    }

    return null;
  }

  /// Yahoo Finance Quote Abfrage
  Future<LiveQuoteResult?> _fetchYahooQuote(String yahooSymbol) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=5m&range=1d',
    );

    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart']?['result']?[0];
      if (chart == null) return null;

      final meta = chart['meta'];
      final double price = (meta['regularMarketPrice'] as num?)?.toDouble() ??
          (meta['chartPreviousClose'] as num?)?.toDouble() ??
          0.0;
      final double prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
          (meta['previousClose'] as num?)?.toDouble() ??
          price;
      final double? high = (meta['regularMarketDayHigh'] as num?)?.toDouble();
      final double? low = (meta['regularMarketDayLow'] as num?)?.toDouble();

      final indicators = chart['indicators']?['quote']?[0];
      final rawCloses = indicators?['close'] as List<dynamic>?;
      List<double>? series;
      if (rawCloses != null) {
        series = rawCloses
            .where((v) => v != null)
            .map((v) => (v as num).toDouble())
            .toList();
      }

      if (price > 0) {
        final result = LiveQuoteResult(
          currentPrice: price,
          previousClose: prevClose,
          high: high,
          low: low,
          series: series,
        );
        _quoteCache[yahooSymbol] = result;
        return result;
      }
    }
    return null;
  }

  /// Yahoo Finance Timeframe History Abfrage
  Future<List<double>?> _fetchYahooHistory(String yahooSymbol, String timeframe) async {
    String range;
    String interval;

    switch (timeframe) {
      case '1D':
        range = '1d';
        interval = '5m';
        break;
      case '1W':
        range = '5d';
        interval = '15m';
        break;
      case '1M':
        range = '1mo';
        interval = '1d';
        break;
      case '1Y':
        range = '1y';
        interval = '1wk';
        break;
      case '3Y':
        range = '3y';
        interval = '1wk';
        break;
      case 'ALL':
      default:
        range = 'max';
        interval = '1mo';
        break;
    }

    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=$interval&range=$range',
    );

    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart']?['result']?[0];
      if (chart == null) return null;

      final indicators = chart['indicators']?['quote']?[0];
      final rawCloses = indicators?['close'] as List<dynamic>?;
      if (rawCloses != null) {
        final filtered = rawCloses
            .where((v) => v != null)
            .map((v) => (v as num).toDouble())
            .toList();
        if (filtered.isNotEmpty) return filtered;
      }
    }
    return null;
  }

  /// CoinGecko Live-Quote für Kryptowährungen
  Future<LiveQuoteResult?> _fetchCryptoQuote(Asset asset) async {
    final coinId = asset.coingeckoId ?? _mapSymbolToCoinGeckoId(asset.symbol);
    final uri = Uri.parse(
      'https://api.coingecko.com/api/v3/coins/markets?vs_currency=eur&ids=$coinId&sparkline=true',
    );

    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isNotEmpty) {
        final coin = list.first as Map<String, dynamic>;
        final double price = (coin['current_price'] as num?)?.toDouble() ?? asset.currentPrice;
        final double change24h = (coin['price_change_24h'] as num?)?.toDouble() ?? 0.0;
        final double prevClose = price - change24h;
        final double? high = (coin['high_24h'] as num?)?.toDouble();
        final double? low = (coin['low_24h'] as num?)?.toDouble();

        final sparklineList = coin['sparkline_in_7d']?['price'] as List<dynamic>?;
        List<double>? series;
        if (sparklineList != null) {
          series = sparklineList.map((v) => (v as num).toDouble()).toList();
        }

        final result = LiveQuoteResult(
          currentPrice: price,
          previousClose: prevClose > 0 ? prevClose : price,
          high: high,
          low: low,
          series: series,
        );
        _quoteCache[asset.symbol] = result;
        return result;
      }
    }
    return null;
  }

  String _mapSymbolToCoinGeckoId(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'BTC':
        return 'bitcoin';
      case 'ETH':
        return 'ethereum';
      case 'SOL':
        return 'solana';
      case 'XRP':
        return 'ripple';
      case 'BNB':
        return 'binancecoin';
      case 'DOGE':
        return 'dogecoin';
      case 'ADA':
        return 'cardano';
      case 'AVAX':
        return 'avalanche-2';
      case 'LINK':
        return 'chainlink';
      case 'DOT':
        return 'polkadot';
      case 'NEAR':
        return 'near';
      case 'RENDER':
        return 'render-token';
      default:
        return symbol.toLowerCase();
    }
  }

  /// Prüft gemäß Benutzer-Entscheidung, ob ein Asset bewegt werden darf
  /// (Aktien verharren bei Marktschluss strikt am echten Schlusskurs, Krypto ist 24/7 aktiv)
  bool canAssetBeUpdated(Asset asset) {
    if (asset.type == AssetType.crypto) return true;
    final schedule = MarketSchedule.forAsset(asset);
    return schedule.isMarketOpen();
  }
}
