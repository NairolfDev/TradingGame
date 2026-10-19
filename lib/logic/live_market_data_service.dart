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
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Map<String, List<double>>> _historicalSeriesCache = {};

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
    // Futures (gold, oil, ...) are quoted in USD and converted to EUR; leverage
    // CFDs follow the quote of their underlying.
    if ((asset.type == AssetType.commodity || asset.type == AssetType.cfd) &&
        asset.yahooSymbol != null) {
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

    // The browser relay allows about 20 requests a minute per visitor: stocks
    // fetched in the last 90 seconds wait for the next round.
    final supported = assets.where((a) {
      final symbol = euroYahooSymbolFor(a);
      if (symbol == null) return false;
      if (!kIsWeb || a.type == AssetType.crypto) return true;
      final at = _fetchedAt[symbol];
      return at == null ||
          DateTime.now().difference(at) > const Duration(seconds: 90);
    }).toList();
    // Crypto: Binance/CoinGecko, a few at a time.
    final crypto = supported.where((a) => a.type == AssetType.crypto).toList();
    for (var i = 0; i < crypto.length; i += 6) {
      await Future.wait(
        crypto.skip(i).take(6).map((asset) async {
          try {
            final quote = await _fetchCryptoQuote(asset);
            if (quote != null) updated[asset.symbol] = quote;
          } catch (_) {}
        }),
      );
    }

    // Everything else: Yahoo spark in chunks of 20, FX rates in the first one.
    final others = supported.where((a) => a.type != AssetType.crypto).toList();
    final symbols = {for (final a in others) euroYahooSymbolFor(a)!}.toList();
    if (symbols.isNotEmpty) {
      final fx = _fxSymbols.values.where((f) {
        final c = _fxCache[f];
        return c == null ||
            DateTime.now().difference(c.at) > const Duration(minutes: 5);
      });
      symbols.insertAll(0, fx);
    }
    final charts = <String, Map<String, dynamic>>{};
    for (var i = 0; i < symbols.length; i += sparkChunk) {
      charts.addAll(await _spark(symbols.skip(i).take(sparkChunk).toList()));
    }
    for (final f in _fxSymbols.values) {
      final meta = charts[f]?['meta'];
      if (meta is Map<String, dynamic>) {
        _fxCache[f] = (at: DateTime.now(), meta: meta);
      }
    }
    for (final asset in others) {
      final symbol = euroYahooSymbolFor(asset)!;
      final chart = charts[symbol];
      if (chart == null) continue;
      try {
        final quote = await _fetchYahooQuote(symbol, chart: chart);
        if (quote != null) updated[asset.symbol] = quote;
      } catch (_) {}
    }
    if (updated.isNotEmpty) _lastSyncTime = DateTime.now();
    return updated;
  }

  /// Instruments quoted in a non-EUR currency (no timestamp-aligned EUR
  /// history): permanent, unlike a network error.
  static final Set<String> _noHistory = {};

  /// True when no EUR price history can ever be shown for [asset]: there is no
  /// live source at all, the browser build cannot reach Yahoo, or the
  /// instrument is not quoted in EUR.
  static bool historyUnavailable(Asset asset) =>
      euroYahooSymbolFor(asset) == null ||
      _noHistory.contains(asset.symbol);

  /// Holt historische Zeitreihen für die verschiedenen Timeframes (1D, 1W, 1M, 1Y, 3Y, ALL)
  final Map<String, List<DateTime>> _historyTimes = {};

  /// Timestamps of the last series loaded for [asset]/[timeframe] (same
  /// length and order as the values), for the chart's date axis.
  List<DateTime>? historyTimes(Asset asset, String timeframe) =>
      _historyTimes['${asset.symbol}|$timeframe'];

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
        final points = await _fetchYahooHistory(symbol, timeframe, assetKey);
        final series = points?.map((p) => p.v).toList();
        if (points != null && series != null && series.isNotEmpty) {
          _historyTimes['$assetKey|$timeframe'] = [
            for (final p in points)
              DateTime.fromMillisecondsSinceEpoch(p.t * 1000),
          ];
          _noHistory.remove(assetKey);
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

  static const _yahooChart =
      'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _fxSymbols = {'USD': 'EURUSD=X', 'JPY': 'EURJPY=X'};
  static const _yahooHeaders = {
    'User-Agent': 'Mozilla/5.0',
    'Accept': 'application/json',
  };

  static bool _positive(Object? v) => v is num && v.isFinite && v > 0;

  /// Optional own CORS relay for the browser build (a tiny Cloudflare worker
  /// that forwards `?url=` and adds CORS headers), set with
  /// `--dart-define=QUOTE_PROXY=https://...`.
  static const _quoteProxy = String.fromEnvironment('QUOTE_PROXY');

  /// Yahoo sends no CORS headers: Android and desktop ask it directly, the
  /// browser goes through a relay. Without an own relay it falls back to the
  /// public reader at r.jina.ai (limited per visitor, no key).
  Future<String?> _yahooGet(
    String symbol,
    String interval,
    String range,
    Duration timeout,
  ) async {
    final target = Uri.parse(
      '$_yahooChart/${Uri.encodeComponent(symbol)}',
    ).replace(queryParameters: {'interval': interval, 'range': range});
    return _yahooBody(target, timeout);
  }

  Future<String?> _yahooBody(Uri target, Duration timeout) async {
    if (!kIsWeb) {
      final r = await http.get(target, headers: _yahooHeaders).timeout(timeout);
      return r.statusCode == 200 ? r.body : null;
    }
    final relay = _quoteProxy.isNotEmpty
        ? Uri.parse('$_quoteProxy?url=${Uri.encodeComponent('$target')}')
        : Uri.parse('https://r.jina.ai/$target');
    final r = await http.get(relay).timeout(timeout);
    if (r.statusCode != 200) return null;
    // The reader wraps the JSON in a short text header.
    final start = r.body.indexOf('{');
    return start < 0 ? null : r.body.substring(start);
  }

  Future<Map<String, dynamic>?> _chart(
    String symbol,
    String interval,
    String range,
    Duration timeout,
  ) async {
    final body = await _yahooGet(symbol, interval, range, timeout);
    if (body == null) return null;
    final result = (jsonDecode(body) as Map?)?['chart']?['result'];
    return result is List && result.isNotEmpty
        ? result.first as Map<String, dynamic>
        : null;
  }

  final Map<String, ({DateTime at, Map<String, dynamic> meta})> _fxCache = {};

  Future<Map<String, dynamic>?> _fxMeta(String fxSymbol) async {
    final cached = _fxCache[fxSymbol];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 5)) {
      return cached.meta;
    }
    final meta =
        (await _chart(fxSymbol, '5m', '1d', const Duration(seconds: 8)))?['meta']
            as Map<String, dynamic>?;
    if (meta != null) _fxCache[fxSymbol] = (at: DateTime.now(), meta: meta);
    return meta;
  }

  /// Quote in EUR: non-EUR prices use the current FX rate (a snapshot).
  /// Up to 20 symbols in one request (Yahoo spark): the same per-symbol data
  /// as a chart, so a whole page of quotes costs one relay call.
  static const sparkChunk = 20;

  Future<Map<String, Map<String, dynamic>>> _spark(List<String> symbols) async {
    final target = Uri.parse(
      'https://query1.finance.yahoo.com/v7/finance/spark',
    ).replace(
      queryParameters: {
        'symbols': symbols.join(','),
        'range': '1d',
        'interval': '5m',
      },
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final body = await _yahooBody(target, const Duration(seconds: 15));
        if (body == null) continue;
        final result = ((jsonDecode(body) as Map?)?['spark'] as Map?)?['result'];
        if (result is! List) continue;
        return {
          for (final e in result)
            if (e is Map &&
                e['symbol'] is String &&
                (e['response'] as List?)?.firstOrNull is Map)
              e['symbol'] as String:
                  ((e['response'] as List).first as Map).cast<String, dynamic>(),
        };
      } catch (_) {
        // Relay hiccup or truncated body: one more try.
      }
    }
    return const {};
  }

  Future<LiveQuoteResult?> _fetchYahooQuote(
    String yahooSymbol, {
    Map<String, dynamic>? chart,
  }) async {
    try {
      chart ??= await _chart(
        yahooSymbol,
        '5m',
        '1d',
        const Duration(seconds: 12),
      );
      final meta = chart?['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;
      final price = meta['regularMarketPrice'];
      final time = meta['regularMarketTime'];
      final previous = meta['chartPreviousClose'] ?? meta['previousClose'];
      final currency = meta['currency'] as String?;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!_positive(price) || !_positive(time) || !_positive(previous)) {
        return null;
      }
      final sourceMs = (time as num).toInt() * 1000;
      if (sourceMs > nowMs + 60000) return null;

      var rate = 1.0;
      if (currency != 'EUR') {
        final fxSymbol = _fxSymbols[currency];
        if (fxSymbol == null) return null;
        final fxMeta = await _fxMeta(fxSymbol);
        final fxRate = fxMeta?['regularMarketPrice'];
        final fxTime = fxMeta?['regularMarketTime'];
        // Weekends are fine, indefinitely stale rates are not.
        if (!_positive(fxRate) ||
            !_positive(fxTime) ||
            fxMeta!['currency'] != currency ||
            nowMs - (fxTime as num).toInt() * 1000 > 4 * 86400000) {
          return null;
        }
        rate = (fxRate as num).toDouble();
      }
      double? eur(Object? v) => _positive(v) ? (v as num) / rate : null;
      final closes =
          (((chart!['indicators'] as Map?)?['quote'] as List?)?.firstOrNull
                  as Map?)?['close']
              as List?;
      final result = LiveQuoteResult(
        currentPrice: (price as num) / rate,
        previousClose: (previous as num) / rate,
        high: eur(meta['regularMarketDayHigh']),
        low: eur(meta['regularMarketDayLow']),
        series: currency == 'EUR'
            ? closes
                  ?.whereType<num>()
                  .map((v) => v.toDouble())
                  .where((v) => v.isFinite && v > 0)
                  .toList()
            : const [],
        sourceTimestamp: DateTime.fromMillisecondsSinceEpoch(sourceMs),
        source: 'Yahoo Finance',
        nativeCurrency: currency,
        usesSnapshotFx: currency != 'EUR',
      );
      _quoteCache[yahooSymbol] = result;
      _fetchedAt[yahooSymbol] = DateTime.now();
      return result;
    } catch (error) {
      debugPrint('Kurs nicht verfügbar ($yahooSymbol): $error');
      return null;
    }
  }

  Future<List<({int t, double v})>?> _fetchYahooHistory(
    String yahooSymbol,
    String timeframe,
    String assetKey,
  ) async {
    final (range, interval) = switch (timeframe) {
      '1D' => ('1d', '5m'),
      '1W' => ('5d', '15m'),
      '1M' => ('1mo', '1d'),
      '1Y' => ('1y', '1wk'),
      '3Y' => ('3y', '1wk'),
      _ => ('max', '1mo'),
    };
    try {
      final chart = await _chart(
        yahooSymbol,
        interval,
        range,
        const Duration(seconds: 10),
      );
      if (chart == null) return null;
      final currency = (chart['meta'] as Map?)?['currency'];
      final points = _closes(chart);
      if (points.isEmpty) return null;
      if (currency == 'EUR') return points;

      // Other currencies are converted point by point with the EUR rate that
      // was valid at that time (the latest rate not after the timestamp), so
      // the curve never mixes today's rate into old prices.
      final fxSymbol = _fxSymbols[currency];
      if (fxSymbol == null) {
        _noHistory.add(assetKey);
        return null;
      }
      final fxChart = await _chart(
        fxSymbol,
        interval,
        range,
        const Duration(seconds: 10),
      );
      final fx = fxChart == null ? <({int t, double v})>[] : _closes(fxChart);
      if (fx.isEmpty) return null;
      final converted = <({int t, double v})>[];
      var j = -1;
      for (final p in points) {
        while (j + 1 < fx.length && fx[j + 1].t <= p.t) {
          j++;
        }
        // Before the first FX bar of the range (e.g. Friday's close seen on
        // Monday morning) the earliest rate is used if it is under 4 days off.
        final rate = j >= 0
            ? fx[j].v
            : (fx.first.t - p.t < 4 * 86400 ? fx.first.v : null);
        if (rate != null) converted.add((t: p.t, v: p.v / rate));
      }
      return converted.length < 2 ? null : converted;
    } catch (_) {
      return null;
    }
  }

  /// Time/close pairs of a Yahoo chart; gaps and invalid values are dropped.
  List<({int t, double v})> _closes(Map<String, dynamic> chart) {
    final stamps = chart['timestamp'] as List?;
    final closes =
        (((chart['indicators'] as Map?)?['quote'] as List?)?.firstOrNull
                as Map?)?['close']
            as List?;
    if (stamps == null || closes == null) return const [];
    final n = stamps.length < closes.length ? stamps.length : closes.length;
    return [
      for (var i = 0; i < n; i++)
        if (stamps[i] is num && _positive(closes[i]))
          (t: (stamps[i] as num).toInt(), v: (closes[i] as num).toDouble()),
    ];
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
