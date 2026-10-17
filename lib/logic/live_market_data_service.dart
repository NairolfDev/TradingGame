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
  final DateTime? sourceTimestamp;
  final String source;
  final String? nativeCurrency;
  final bool usesSnapshotFx;

  const LiveQuoteResult({
    required this.currentPrice,
    required this.previousClose,
    this.high,
    this.low,
    this.series,
    this.sourceTimestamp,
    this.source = 'Marktdatenanbieter',
    this.nativeCurrency,
    this.usesSnapshotFx = false,
  });
}

class LiveMarketDataService {
  static final LiveMarketDataService _instance =
      LiveMarketDataService._internal();
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
    const etfs = {
      'EUNL': 'EUNL.DE',
      'VUSA': 'VUSA.AS',
      'EXS1': 'EXS1.DE',
      'IS3N': 'IS3N.DE',
    };
    final symbol = asset.yahooSymbol ?? etfs[asset.symbol] ?? asset.symbol;
    if (asset.type == AssetType.stock || asset.type == AssetType.etf) {
      return symbol;
    }
    if (['.VI', '.DE', '.AS'].any(symbol.endsWith)) return symbol;
    return null;
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
      debugPrint(
        'LiveMarketDataService: Fehler bei Quote für ${asset.symbol}: $e',
      );
    }
    return null;
  }

  /// Batch-Update für mehrere Assets (z.B. Watchlist oder alle Depotwerte)
  Future<Map<String, LiveQuoteResult>> refreshQuotesForAssets(
    List<Asset> assets,
  ) async {
    final Map<String, LiveQuoteResult> updated = {};

    final supported = assets
        .where((a) => euroYahooSymbolFor(a) != null)
        .toList();
    for (var i = 0; i < supported.length; i += 6) {
      await Future.wait(
        supported.skip(i).take(6).map((asset) async {
          try {
            final quote = asset.type == AssetType.crypto
                ? await _fetchCryptoQuote(asset)
                : await _fetchYahooQuote(euroYahooSymbolFor(asset)!);
            if (quote != null) updated[asset.symbol] = quote;
          } catch (_) {}
        }),
      );
    }
    if (updated.isNotEmpty) _lastSyncTime = DateTime.now();
    return updated;
  }

  /// Holt historische Zeitreihen für die verschiedenen Timeframes (1D, 1W, 1M, 1Y, 3Y, ALL)
  Future<List<double>?> fetchHistoricalSeries(
    Asset asset,
    String timeframe,
  ) async {
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
          _historicalSeriesCache.putIfAbsent(assetKey, () => {})[timeframe] =
              series;
          return series;
        }
      }
    } catch (e) {
      debugPrint(
        'LiveMarketDataService: Fehler bei Historie für ${asset.symbol} ($timeframe): $e',
      );
    }

    return null;
  }

  /// All platforms use the proxy, which validates currency before EUR display.
  Future<LiveQuoteResult?> _fetchYahooQuote(String yahooSymbol) async {
    try {
      final uri = Uri.parse(
        '$_cloudApiBase/quote',
      ).replace(queryParameters: {'symbol': yahooSymbol});
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['currency'] != 'EUR' || data['timestamp'] is! num) {
        return null;
      }
      final price = (data['currentPrice'] as num?)?.toDouble();
      final previous = (data['previousClose'] as num?)?.toDouble();
      if (price == null ||
          !price.isFinite ||
          price <= 0 ||
          previous == null ||
          !previous.isFinite ||
          previous <= 0) {
        return null;
      }
      final result = LiveQuoteResult(
        currentPrice: price,
        previousClose: previous,
        high: (data['high'] as num?)?.toDouble(),
        low: (data['low'] as num?)?.toDouble(),
        series: (data['series'] as List<dynamic>?)
            ?.whereType<num>()
            .map((value) => value.toDouble())
            .where((v) => v.isFinite && v > 0)
            .toList(),
        sourceTimestamp: DateTime.fromMillisecondsSinceEpoch(
          (data['timestamp'] as num).toInt(),
        ),
        source: data['source'] as String? ?? 'Yahoo Finance',
        nativeCurrency: data['nativeCurrency'] as String?,
        usesSnapshotFx: data['conversionMethod'] == 'current-fx-snapshot',
      );
      _quoteCache[yahooSymbol] = result;
      return result;
    } catch (error) {
      debugPrint('Kurs nicht verfügbar ($yahooSymbol): $error');
      return null;
    }
  }

  Future<List<double>?> _fetchYahooHistory(
    String yahooSymbol,
    String timeframe,
  ) async {
    try {
      final uri = Uri.parse('$_cloudApiBase/history').replace(
        queryParameters: {'symbol': yahooSymbol, 'timeframe': timeframe},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final series = (data['series'] as List<dynamic>?)
          ?.whereType<num>()
          .map((v) => v.toDouble())
          .where((v) => v.isFinite && v > 0)
          .toList();
      return series == null || series.isEmpty ? null : series;
    } catch (_) {
      return null;
    }
  }

  /// Realtime Live-Quote für Krypto (Binance 24hr API, Fallback auf CoinGecko)
  Future<LiveQuoteResult?> _fetchCryptoQuote(Asset asset) async {
    // 1. Ultra-schnelle Binance 24hr API (CORS-unterstützt auf Web & Mobil)
    try {
      final binanceSymbol = '${asset.symbol.toUpperCase()}EUR';
      final uri = Uri.parse(
        'https://api.binance.com/api/v3/ticker/24hr?symbol=$binanceSymbol',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final price =
            double.tryParse(data['lastPrice']?.toString() ?? '') ?? 0.0;
        final prevClose =
            double.tryParse(data['prevClosePrice']?.toString() ?? '') ?? price;
        final high = double.tryParse(data['highPrice']?.toString() ?? '');
        final low = double.tryParse(data['lowPrice']?.toString() ?? '');

        if (price > 0) {
          final result = LiveQuoteResult(
            currentPrice: price,
            previousClose: prevClose,
            high: high,
            low: low,
            source: 'Binance',
            sourceTimestamp: DateTime.fromMillisecondsSinceEpoch(
              (data['closeTime'] as num).toInt(),
            ),
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

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final coin = list.first as Map<String, dynamic>;
          final double price =
              (coin['current_price'] as num?)?.toDouble() ?? 0.0;
          if (!price.isFinite || price <= 0) return null;
          final double change24h =
              (coin['price_change_24h'] as num?)?.toDouble() ?? 0.0;
          final double prevClose = price - change24h;
          final double? high = (coin['high_24h'] as num?)?.toDouble();
          final double? low = (coin['low_24h'] as num?)?.toDouble();

          final sparklineList =
              coin['sparkline_in_7d']?['price'] as List<dynamic>?;
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
            source: 'CoinGecko',
            sourceTimestamp: DateTime.tryParse(
              coin['last_updated'] as String? ?? '',
            ),
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
