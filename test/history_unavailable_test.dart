import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/logic/live_market_data_service.dart';

void main() {
  final assets = InitialAssets.getAssets();
  final btc = assets.firstWhere((a) => a.symbol == 'BTC');
  final eth = assets.firstWhere((a) => a.symbol == 'ETH');

  Future<List<double>?> fetchWith(int status, dynamic asset) =>
      http.runWithClient(
        () => LiveMarketDataService().fetchHistoricalSeries(asset, '1M'),
        () => MockClient((_) async => http.Response('{}', status)),
      );

  test('HTTP 422 marks the history as permanently unavailable', () async {
    expect(LiveMarketDataService.historyUnavailable(btc), isFalse);
    expect(await fetchWith(422, btc), isNull);
    expect(LiveMarketDataService.historyUnavailable(btc), isTrue);
  });

  test('a temporary failure (503) does not', () async {
    expect(await fetchWith(503, eth), isNull);
    expect(LiveMarketDataService.historyUnavailable(eth), isFalse);
  });

  test('instruments without a live source are unavailable by design', () {
    final bond = assets.firstWhere((a) => a.type.name == 'bond');
    expect(LiveMarketDataService.historyUnavailable(bond), isTrue);
  });
}
