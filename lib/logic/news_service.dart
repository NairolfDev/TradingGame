import 'dart:async';
import 'dart:math';
import '../data/mock_data/initial_news.dart';
import '../data/models/asset.dart';
import '../data/models/news_event.dart';

class NewsService {
  final List<NewsEvent> _newsHistory = [];
  Timer? _newsTimer;
  final Random _random = Random();
  void Function(NewsEvent)? onNewsDropped;

  List<NewsEvent> get newsHistory => List.unmodifiable(_newsHistory);

  NewsEvent? get latestNews =>
      _newsHistory.isNotEmpty ? _newsHistory.first : null;

  void initialize(List<Asset> assets) {
    _newsHistory.clear();
    _newsHistory.addAll(InitialNews.getNews());
    _startDynamicNewsCycle(assets);
  }

  /// Generates data-driven market bulletins from real asset price movements
  /// without ever altering asset prices.
  List<NewsEvent> buildMarketFeedReports(List<Asset> assets) {
    final reports = <NewsEvent>[];
    final valid = assets
        .where(
          (a) =>
              a.currentPrice.isFinite &&
              a.currentPrice > 0 &&
              a.previousClose.isFinite &&
              a.previousClose > 0 &&
              a.change24hPercent.abs() >= 0.002,
        )
        .toList();
    if (valid.isEmpty) return reports;

    valid.sort(
      (a, b) => b.change24hPercent.abs().compareTo(a.change24hPercent.abs()),
    );

    final now = DateTime.now();
    for (final asset in valid.take(8)) {
      final pct = asset.change24hPercent * 100;
      final isBull = pct >= 0;
      final sign = isBull ? '+' : '';
      final headline = isBull
          ? '${asset.name} (${asset.symbol}) legt $sign${pct.toStringAsFixed(2)} % zu'
          : '${asset.name} (${asset.symbol}) gibt ${pct.toStringAsFixed(2)} % nach';
      final rangeNote = (asset.dailyHigh > 0 && asset.dailyLow > 0)
          ? 'Tagesspanne: ${asset.dailyLow.toStringAsFixed(2)} € – ${asset.dailyHigh.toStringAsFixed(2)} €.'
          : '';
      final description =
          'Aktueller Kurs: ${asset.currentPrice.toStringAsFixed(2)} € '
          '(Vortagesschluss: ${asset.previousClose.toStringAsFixed(2)} €). $rangeNote';

      reports.add(
        NewsEvent(
          id: 'market_${asset.symbol}_${now.year}_${now.month}_${now.day}_${now.hour}',
          headline: headline,
          description: description.trim(),
          affectedSymbol: asset.symbol,
          priceImpact: asset.change24hPercent,
          timestamp: now,
          category: asset.type.displayName,
          isBreaking: pct.abs() >= 3.0,
        ),
      );
    }
    return reports;
  }

  void _startDynamicNewsCycle(List<Asset> assets) {
    _newsTimer?.cancel();
    _newsTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      triggerRandomBreakingNews(assets);
    });
  }

  NewsEvent triggerRandomBreakingNews([List<Asset>? assets]) {
    final pool = InitialNews.getNews();
    final template = pool[_random.nextInt(pool.length)];

    final sign = _random.nextBool() ? 1.0 : -1.0;
    final variation = (0.04 + _random.nextDouble() * 0.08) * sign;

    final newEvent = NewsEvent(
      id: 'news_${DateTime.now().millisecondsSinceEpoch}',
      headline: template.headline,
      description: template.description,
      affectedSymbol: template.affectedSymbol,
      priceImpact: variation,
      timestamp: DateTime.now(),
      category: template.category,
      isBreaking: true,
    );

    _newsHistory.insert(0, newEvent);
    if (_newsHistory.length > 30) {
      _newsHistory.removeLast();
    }

    onNewsDropped?.call(newEvent);
    return newEvent;
  }

  void dispose() {
    _newsTimer?.cancel();
  }
}
