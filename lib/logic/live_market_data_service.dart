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

  static const String _cloudApiBase =
      'https://europe-west3-tradinggame-austria-prod.cloudfunctions.net/api';

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  static String? euroYahooSymbolFor(Asset asset) {
    if (asset.type == AssetType.crypto) return '${asset.symbol}-EUR';
    final symbol = asset.yahooSymbol ?? asset.symbol;
    if (['.VI', '.DE', '.AS'].any(symbol.endsWith)) return symbol;
    const etfs = {'EUNL': 'EUNL.DE', 'VUSA': 'VUSA.AS', 'EXS1': 'EXS1.DE', 'IS3N': 'IS3N.DE'};
    // USD futures and foreign-currency securities need conversion before EUR display.
    return etfs[symbol];
  }

  /// Holt aktuelle Kursdaten für ein Asset (via Binance, Yahoo Finance oder CoinGecko)
  Future<LiveQuoteResult?> fetchLiveQuote(Asset asset) async {
    try {
      if (asset.type == AssetType.crypto) {
        final res = await _fetchCryptoQuote(asset);
        if (res != null) return res;
      } else if (euroYahooSymbolFor(asset) != null) {
        final res = await _fetchYahooQuote(euroYahooSymbolFor(asset)!);
        if (res != null) return res;
      }
    } catch (e) {
      debugPrint('LiveMarketDataService: Fehler bei Quote für ${asset.symbol}: $e');
    }
    return _quoteCache[asset.symbol];
  }

  /// Batch-Update für mehrere Assets (z.B. Watchlist oder alle Depotwerte)
  Future<Map<String, LiveQuoteResult>> refreshQuotesForAssets(List<Asset> assets) async {
    final Map<String, LiveQuoteResult> updated = {};

    final supported = assets.where((a) => euroYahooSymbolFor(a) != null).toList();
    for (var i = 0; i < supported.length; i += 6) {
      await Future.wait(supported.skip(i).take(6).map((asset) async {
        try {
          final quote = asset.type == AssetType.crypto
              ? await _fetchCryptoQuote(asset)
              : await _fetchYahooQuote(euroYahooSymbolFor(asset)!);
          if (quote != null) updated[asset.symbol] = quote;
        } catch (_) {}
      }));
    }
    if (updated.isNotEmpty) _lastSyncTime = DateTime.now();
    return updated;
  }

  /// Holt historische Zeitreihen für die verschiedenen Timeframes (1D, 1W, 1M, 1Y, 3Y, ALL)
  Future<List<double>?> fetchHistoricalSeries(Asset asset, String timeframe) async {
    final symbol = euroYahooSymbolFor(asset);
    if (symbol == null) return null;
    final assetKey = asset.symbol;
    if (_historicalSeriesCache.containsKey(assetKey) &&
        _historicalSeriesCache[assetKey]!.containsKey(timeframe)) {
      return _historicalSeriesCache[assetKey]![timeframe];
    }

    try {
      if (symbol.isNotEmpty) {
        final series = await _fetchYahooHistory(symbol, timeframe);
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

  /// Yahoo Finance Quote Abfrage (mit Cloud Function Proxy für Flutter Web)
  Future<LiveQuoteResult?> _fetchYahooQuote(String yahooSymbol) async {
    // 1. Bei Flutter Web: Nutze Firebase Cloud Function Proxy (keine CORS-Blockade)
    if (kIsWeb) {
      try {
        final uri = Uri.parse('$_cloudApiBase/quote?symbol=$yahooSymbol');
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final double price = (json['currentPrice'] as num?)?.toDouble() ?? 0.0;
          final double prevClose = (json['previousClose'] as num?)?.toDouble() ?? price;
          final double? high = (json['high'] as num?)?.toDouble();
          final double? low = (json['low'] as num?)?.toDouble();
          final seriesRaw = json['series'] as List<dynamic>?;
          final series = seriesRaw?.where((v) => v != null).map((v) => (v as num).toDouble()).toList();

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
      } catch (webErr) {
        debugPrint('Web Cloud Proxy notice for $yahooSymbol: $webErr');
      }
    }

    // 2. Direktabfrage an Yahoo Finance (Desktop / Mobile oder Web-Fallback)
    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=5m&range=1d',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
    } catch (_) {
      try {
        final uri = Uri.parse('$_cloudApiBase/quote?symbol=$yahooSymbol');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final double price = (json['currentPrice'] as num?)?.toDouble() ?? 0.0;
          final double prevClose = (json['previousClose'] as num?)?.toDouble() ?? price;
          final double? high = (json['high'] as num?)?.toDouble();
          final double? low = (json['low'] as num?)?.toDouble();
          final seriesRaw = json['series'] as List<dynamic>?;
          final series = seriesRaw?.where((v) => v != null).map((v) => (v as num).toDouble()).toList();

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
      } catch (_) {}
    }

    return null;
  }

  /// Yahoo Finance Timeframe History Abfrage (mit Cloud Function Proxy für Flutter Web)
  Future<List<double>?> _fetchYahooHistory(String yahooSymbol, String timeframe) async {
    // 1. Bei Flutter Web: Nutze Firebase Cloud Function Proxy
    if (kIsWeb) {
      try {
        final uri = Uri.parse('$_cloudApiBase/history?symbol=$yahooSymbol&timeframe=$timeframe');
        final response = await http.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final seriesRaw = json['series'] as List<dynamic>?;
          if (seriesRaw != null && seriesRaw.isNotEmpty) {
            return seriesRaw.map((v) => (v as num).toDouble()).toList();
          }
        }
      } catch (webErr) {
        debugPrint('Web Cloud Proxy history notice for $yahooSymbol: $webErr');
      }
    }

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

    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=$interval&range=$range',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
    } catch (_) {
      try {
        final uri = Uri.parse('$_cloudApiBase/history?symbol=$yahooSymbol&timeframe=$timeframe');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final seriesRaw = json['series'] as List<dynamic>?;
          if (seriesRaw != null && seriesRaw.isNotEmpty) {
            return seriesRaw.map((v) => (v as num).toDouble()).toList();
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Realtime Live-Quote für Krypto (Binance 24hr API, Fallback auf CoinGecko)
  Future<LiveQuoteResult?> _fetchCryptoQuote(Asset asset) async {
    // 1. Ultra-schnelle Binance 24hr API (CORS-unterstützt auf Web & Mobil)
    try {
      final binanceSymbol = '${asset.symbol.toUpperCase()}EUR';
      final uri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$binanceSymbol');
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final price = double.tryParse(data['lastPrice']?.toString() ?? '') ?? 0.0;
        final prevClose = double.tryParse(data['prevClosePrice']?.toString() ?? '') ?? price;
        final high = double.tryParse(data['highPrice']?.toString() ?? '');
        final low = double.tryParse(data['lowPrice']?.toString() ?? '');

        if (price > 0) {
          final result = LiveQuoteResult(
            currentPrice: price,
            previousClose: prevClose,
            high: high,
            low: low,
          );
          _quoteCache[asset.symbol] = result;
          return result;
        }
      }
    } catch (_) {}

    // 2. Fallback CoinGecko
    try {
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
    } catch (_) {}
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
