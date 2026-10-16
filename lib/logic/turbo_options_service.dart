import 'dart:async';
import '../data/models/turbo_option.dart';

class TurboOptionsService {
  final List<TurboOption> _activeOptions = [];
  final List<TurboOption> _settledOptions = [];
  Timer? _tickerTimer;
  void Function(TurboOption)? onOptionSettled;

  List<TurboOption> get activeOptions => List.unmodifiable(_activeOptions);
  List<TurboOption> get settledOptions => List.unmodifiable(_settledOptions);

  void startTicker(double Function(String symbol) getCurrentPrice) {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final toRemove = <TurboOption>[];

      for (final option in _activeOptions) {
        if (now.isAfter(option.endsAt)) {
          final currentPrice = getCurrentPrice(option.assetSymbol);
          option.finalPrice = currentPrice;
          option.isSettled = true;

          if (option.direction == TurboDirection.call) {
            option.isWon = currentPrice > option.entryPrice;
          } else {
            option.isWon = currentPrice < option.entryPrice;
          }

          toRemove.add(option);
          _settledOptions.insert(0, option);
          onOptionSettled?.call(option);
        }
      }

      _activeOptions.removeWhere(toRemove.contains);
    });
  }

  TurboOption placeOption({
    required String assetSymbol,
    required String assetName,
    required double entryPrice,
    required TurboDirection direction,
    required double stake,
    required int durationSeconds,
  }) {
    final now = DateTime.now();
    final option = TurboOption(
      id: 'turbo_${now.millisecondsSinceEpoch}',
      assetSymbol: assetSymbol,
      assetName: assetName,
      entryPrice: entryPrice,
      direction: direction,
      stake: stake,
      durationSeconds: durationSeconds,
      startedAt: now,
      endsAt: now.add(Duration(seconds: durationSeconds)),
      payoutMultiplier: 1.85,
    );

    _activeOptions.add(option);
    return option;
  }

  void dispose() {
    _tickerTimer?.cancel();
  }
}
