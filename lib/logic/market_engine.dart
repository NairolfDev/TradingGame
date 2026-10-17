import 'dart:async';
import '../data/models/asset.dart';
import '../data/models/news_event.dart';

typedef OnPriceUpdate = void Function(List<Asset> updatedAssets);
typedef OnNewsGenerated = void Function(NewsEvent news);
typedef OnMarketOpenNotification = void Function(String message);

class MarketEngine {
  Timer? _tickTimer;
  List<Asset> _assets = [];

  bool get isRunning => _tickTimer?.isActive ?? false;

  void start({
    required List<Asset> initialAssets,
    required OnPriceUpdate priceCallback,
    required OnNewsGenerated newsCallback,
  }) {
    stop();
    _assets = initialAssets;
    // Keep order scheduling alive without inventing quotes or market news.
    _tickTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      priceCallback(_assets);
    });
  }

  void stop() => _tickTimer?.cancel();

  void updateAssetsReference(List<Asset> assets) => _assets = assets;
}
