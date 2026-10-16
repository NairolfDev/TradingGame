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

  NewsEvent? get latestNews => _newsHistory.isNotEmpty ? _newsHistory.first : null;

  void initialize(List<Asset> assets) {
    _newsHistory.clear();
    _newsHistory.addAll(InitialNews.getNews());
    _startDynamicNewsCycle(assets);
  }

  void _startDynamicNewsCycle(List<Asset> assets) {
    _newsTimer?.cancel();
    // Alle 90 Sekunden kann eine neue Breaking News eintreffen
    _newsTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      triggerRandomBreakingNews(assets);
    });
  }

  NewsEvent triggerRandomBreakingNews([List<Asset>? assets]) {
    final pool = InitialNews.getNews();
    final template = pool[_random.nextInt(pool.length)];

    // Variation des Preisausschlags (-15% bis +15%)
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
